# Architecture Decision Records (ADRs)

## Index of Architectural Decisions
- [ADR-01: Adoption of `AwsEcsExecutor` over `CeleryExecutor` for Elastic Task Compute](#adr-01-adoption-of-awsecsexecutor-over-celeryexecutor-for-elastic-task-compute)
- [ADR-02: DAG Distribution via S3 Sync and VPC Gateway Endpoint vs. Amazon EFS](#adr-02-dag-distribution-via-s3-sync-and-vpc-gateway-endpoint-vs-amazon-efs)
- [ADR-03: Hybrid FinOps Networking: 1 NAT Gateway with S3 Gateway Endpoint vs. PrivateLink Mesh](#adr-03-hybrid-finops-networking-1-nat-gateway-with-s3-gateway-endpoint-vs-privatelink-mesh)
- [ADR-04: Zero-Trust Governance: SSM Session Manager & GitHub Actions OIDC over SSH/Bastions](#adr-04-zero-trust-governance-ssm-session-manager--github-actions-oidc-over-sshbastions)

---

## ADR-01: Adoption of `AwsEcsExecutor` over `CeleryExecutor` for Elastic Task Compute

### Status
Accepted

### Context
Production Apache Airflow deployments traditionally rely on `CeleryExecutor`. While capable, `CeleryExecutor` introduces significant operational friction and infrastructure overhead:
1. **Infrastructure Tax:** Requires maintaining a dedicated, highly available message broker cluster (e.g., Amazon ElastiCache Redis or RabbitMQ) and a persistent pool of worker nodes (EC2 instances or persistent ECS services).
2. **Idle Cost Overhead:** Workers consume compute, memory, and licensing 24/7, even during off-peak hours or inter-DAG scheduling gaps.
3. **Dependency Poisoning:** Shared worker environments create library conflicts between DAGs (e.g., Python packages requiring conflicting pandas or PyTorch versions).
4. **Capacity Planning Risk:** Worker auto-scaling based on queue depth suffers from scale-down churn and container termination mid-task unless complex graceful-drain hooks are engineered.

### Decision
Adopt the official AWS Provider **`AwsEcsExecutor`** (`airflow.providers.amazon.aws.executors.ecs.ecs_executor.AwsEcsExecutor`) running ephemeral worker tasks directly on **AWS Fargate**.

### Consequences & Trade-offs
- **Positive:**
  - **Zero Idle Cost ($0.00 at rest):** ECS Fargate tasks are spawned only when a task transitions to `QUEUED` and are destroyed immediately upon task exit. Broker clusters (Redis/RabbitMQ) are completely eliminated.
  - **Hermetic Isolation:** Each task runs in its own dedicated microVM sandbox, completely eliminating cross-task contamination and dependency collision.
  - **Granular Right-Sizing:** Individual DAG tasks dynamically define their vCPU and memory allocations via `executor_config={"cpu": 1024, "memory": 2048}` instead of sizing for the worst-case shared worker.
- **Negative / Trade-offs:**
  - **Cold Start Overhead:** Spawning an ephemeral Fargate task incurs an initial provisioning delay of approximately ~35 to ~50 seconds per task.
  - **Mitigation:** For batch ETL pipelines that execute for minutes or hours, a ~45-second launch overhead represents an acceptable, negligible fraction (<1%) of the total workflow lifecycle.

---

## ADR-02: DAG Distribution via S3 Sync and VPC Gateway Endpoint vs. Amazon EFS

### Status
Accepted

### Context
Airflow requires continuous access to DAG files across both the control plane (Scheduler/Webserver) and all active workers. Two primary architectures exist for shared file distribution:
1. **Network File System (Amazon EFS):** Mounting a shared NFS volume to `/opt/airflow/dags/`.
2. **Object Storage Synchronization (Amazon S3):** Syncing DAG definitions from S3 to local storage before execution and via background daemon.

### Decision
Utilize **Amazon S3 object storage** combined with local disk synchronization (`aws s3 sync --delete`) accelerated by an **Amazon S3 VPC Gateway Endpoint**, rejecting Amazon EFS.

### Consequences & Trade-offs
- **Positive:**
  - **Elimination of IOPS Starvation:** Airflow's *DagBag parsing loop* continuously scans every Python file in the DAG directory every few seconds. On Amazon EFS (NFS), this causes heavy metadata latency and exhausts general-purpose burstable IOPS credits, frequently leading to Scheduler crashes and high task-scheduling latency.
  - **Near-Zero Latency Local Disk Parsing:** S3 sync pulls files to the local EBS root volume (EC2) or container microVM ephemeral storage (Fargate). DagBag parsing runs at local NVMe/SSD speeds with zero network filesystem contention.
  - **Version Control & Rollbacks:** Amazon S3 natively provides object versioning and lifecycle policies, enabling instant recovery of deleted or corrupted DAG files.
- **Negative / Trade-offs:**
  - **Sync Window (Batch Delay):** A new DAG committed to S3 is not instant; it reflects on EC2 within the 30-second systemd timer cycle and on Fargate upon container launch.
  - **Mitigation:** For production ETL workloads, a 30-second propagation window is standard, and individual worker tasks always fetch the latest commit at entrypoint startup.

---

## ADR-03: Hybrid FinOps Networking: 1 NAT Gateway with S3 Gateway Endpoint vs. PrivateLink Mesh

### Status
Accepted

### Context
Securing private subnets from direct internet exposure requires controlled outbound routing for AWS regional service APIs (Amazon ECR, AWS Secrets Manager, Amazon CloudWatch Logs, AWS SSM). Two primary network design patterns exist:
1. **VPC Interface Endpoints Mesh (AWS PrivateLink):** Deploying individual Interface Endpoints for every required service across multiple AZs.
2. **Hybrid FinOps Architecture:** Deploying 1 NAT Gateway in a public subnet coupled with a free **S3 VPC Gateway Endpoint**.

### Decision
Implement the **Hybrid FinOps Architecture** utilizing **1 NAT Gateway in AZ-a** paired with a **zero-cost Amazon S3 Gateway VPC Endpoint** attached to private route tables.

### Financial & Architectural Analysis
- **PrivateLink Cost Burden:** An enterprise Airflow deployment requires at least 7 distinct AWS service interfaces (`ecr.api`, `ecr.dkr`, `secretsmanager`, `logs`, `ssm`, `ssmmessages`, `ec2messages`). Across 2 Availability Zones, this requires **14 VPC Interface Endpoints**.
  - Cost per endpoint: ~$0.01/hour $\times$ 730 hours $\approx$ $7.30 USD/month.
  - Total fixed PrivateLink cost: $14 \times \$7.30 = \mathbf{\$102.20\text{ USD/month}}$ plus data processing charges.
- **Hybrid Blueprint Cost:**
  - 1 NAT Gateway: ~$0.045/hour $\times$ 730 hours $\approx$ **$32.85 USD/month** + 1 Elastic IP ($3.65 USD).
  - S3 VPC Gateway Endpoint: **$0.00 / month (Free)** with $0.00 data transfer fees.
  - S3 data transfer (DAG syncs and ECR base image pulls) travels completely free across AWS's private backbone.
  - **Monthly Savings:** $\approx \mathbf{\$65.70\text{ USD/month}}$ (over **$788 USD/year** saved per environment) while maintaining full private network isolation.

### Consequences & Trade-offs
- **Positive:**
  - Dramatically lowers infrastructure baseline costs for startups, dev/staging environments, and medium-scale production workloads.
  - Zero charge for multi-gigabyte DAG deployments and base container image layers passing to S3.
- **Negative / Trade-offs:**
  - In the rare event that `AZ-a` suffers an entire data center outage, outbound egress through the NAT Gateway would be interrupted until recovery or secondary NAT failover is provisioned.
  - **Mitigation:** Control plane state and database records remain fully resilient in Multi-AZ RDS and Multi-AZ ALB. Multi-NAT configuration can be toggled via `count` for mission-critical enterprise tiers where high availability overrides cost.

---

## ADR-04: Zero-Trust Governance: SSM Session Manager & GitHub Actions OIDC over SSH/Bastions

### Status
Accepted

### Context
Operational management and CI/CD automation often introduce severe security risks through static administrative credentials:
1. **SSH Key Management:** Managing SSH key pairs (`.pem` files), rotating private keys, and opening TCP port 22 on public or private subnets invites brute-force attacks and key-leakage vulnerabilities.
2. **Bastion Host (Jump Box) Overhead:** Running dedicated bastion EC2 instances incurs ongoing compute costs, patching duties, and audit logging complexities.
3. **Static IAM Access Keys in CI/CD:** Storing long-lived `AWS_ACCESS_KEY_ID` and `AWS_SECRET_ACCESS_KEY` in GitHub repository secrets risks catastrophic credential exposure.

### Decision
Completely eliminate SSH port 22, bastion hosts, and static IAM access keys:
1. Mandate **AWS Systems Manager (SSM Session Manager)** for all administrative access to the Airflow Core EC2 instance.
2. Mandate **IAM OpenID Connect (OIDC)** federation for all GitHub Actions CI/CD workflows.

### Consequences & Trade-offs
- **Positive:**
  - **Zero Open Inbound Ports:** The Airflow EC2 security group contains **0 inbound SSH rules**. The SSM agent initiates secure outbound HTTPS connections to SSM endpoints.
  - **Auditable Shell Access:** All terminal sessions, user identities, and executed commands are logged centrally to AWS CloudTrail and Amazon CloudWatch Logs with IAM policy-based RBAC.
  - **Ephemeral Identity Tokens:** GitHub Actions authenticates using short-lived OpenID Connect JWT tokens via `sts:AssumeRoleWithWebIdentity`, cryptographically pinned to `repo:hilixops/aws-ecs-fargate-production-blueprint:*`.
  - **Reduced Attack Surface:** Eliminates bastion host compute charges and patching overhead.
- **Negative / Trade-offs:**
  - Operators must install the AWS CLI and Session Manager Plugin locally (`aws ssm start-session --target <instance-id>`) instead of using standard native `ssh user@host`.
  - **Mitigation:** The AWS Management Console provides instant, one-click browser-based terminal access to the private instance without any local software installation.
