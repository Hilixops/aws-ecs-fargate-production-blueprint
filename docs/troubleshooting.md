# Operational Troubleshooting Runbook: Apache Airflow on AWS Fargate

This runbook provides incident responders, data platform engineers, and DevOps operators with structured failure modes, root cause analyses (RCA), and concrete diagnostic procedures for the **AWS Apache Airflow Hybrid Blueprint (V5)**.

---

## Runbook Index
1. [Failure Mode 1: Tasks Stuck in `PROVISIONING` or Failing with `CannotPullContainerError`](#1-tasks-stuck-in-provisioning-or-failing-with-cannotpullcontainererror)
2. [Failure Mode 2: Fargate Worker Container Exits with `Exit Code 137` (OOMKilled)](#2-fargate-worker-container-exits-with-exit-code-137-oomkilled)
3. [Failure Mode 3: Zombie Tasks or Database Connection Timeouts to RDS PostgreSQL](#3-zombie-tasks-or-database-connection-timeouts-to-rds-postgresql)
4. [Failure Mode 4: DAG Version Drift / Desynchronization Between Scheduler and Workers](#4-dag-version-drift--desynchronization-between-scheduler-and-workers)
5. [Failure Mode 5: AWS Systems Manager (SSM) Session Manager Connection Failures](#5-aws-systems-manager-ssm-session-manager-connection-failures)

---

## 1. Tasks Stuck in `PROVISIONING` or Failing with `CannotPullContainerError`

### Symptoms
- Airflow tasks transition to `queued` or `running` state in the Web UI, but fail after a few minutes with `AirflowTaskTimeout` or `Task killed by executor`.
- In the AWS ECS Console, the task transitions immediately to `STOPPED` with the stop reason:
  ```text
  CannotPullContainerError: inspect image has been retried 5 time(s): failed to resolve reference: failed to do request: Head "https://<account>.dkr.ecr.<region>.amazonaws.com/v2/airflow-worker/manifests/latest": dial tcp ...: i/o timeout
  ```

### Root Cause Analysis (RCA)
Fargate worker tasks are provisioned inside private subnets without public IPv4 addresses (`assign_public_ip = false`). To pull the container image from Amazon ECR, the container runtime must reach the ECR regional API and S3 (where ECR stores underlying image blobs). If the private subnet route table lacks an active route to the NAT Gateway (`0.0.0.0/0 -> nat-gw`), or if the NAT Gateway has failed, DNS queries and HTTPS handshakes timeout.

### Diagnostic & Remediation Steps

1. **Verify Private Subnet Route Table:**
   Confirm that the private route table routes `0.0.0.0/0` to the active NAT Gateway ID:
   ```bash
   aws ec2 describe-route-tables \
     --filters "Name=association.subnet-id,Values=<PRIVATE_SUBNET_ID>" \
     --query "RouteTables[*].Routes" \
     --output table
   ```
   *Expected output must include a route with `DestinationCidrBlock: 0.0.0.0/0` and `NatGatewayId: nat-...`.*

2. **Verify NAT Gateway Operational State:**
   Ensure the NAT Gateway state is `available`:
   ```bash
   aws ec2 describe-nat-gateways \
     --nat-gateway-ids <NAT_GATEWAY_ID> \
     --query "NatGateways[*].[NatGatewayId,State,FailureMessage]" \
     --output table
   ```

3. **Verify ECR Repository Permissions and Task Execution Role:**
   Confirm that the ECS Task Execution Role (`ecs_task_execution_role_arn`) has the `AmazonECSTaskExecutionRolePolicy` attached:
   ```bash
   aws iam list-attached-role-policies \
     --role-name airflow-blueprint-production-ecs-task-execution-role \
     --output table
   ```

4. **Verify Image Exists in ECR:**
   ```bash
   aws ecr describe-images \
     --repository-name airflow-worker \
     --query "imageDetails[*].[imageTags,imagePushedAt]" \
     --output table
   ```

---

## 2. Fargate Worker Container Exits with `Exit Code 137` (OOMKilled)

### Symptoms
- An Airflow task fails abruptly mid-execution.
- The Airflow task log ends with:
  ```text
  Task failed with return code 137
  ```
- In CloudWatch Logs, the container output ceases abruptly without an unhandled Python traceback.
- In the AWS ECS Console, task stopped reason reports:
  ```text
  OutOfMemoryError: Container killed due to memory usage
  ```

### Root Cause Analysis (RCA)
Exit code `137` indicates that the Linux kernel OOM (Out Of Memory) killer sent a `SIGKILL` (128 + 9 = 137) to the worker process because its memory consumption exceeded the task definition allocation (e.g., attempting to process a 4 GB pandas DataFrame inside a 1024 MiB container).

### Diagnostic & Remediation Steps

1. **Inspect CloudWatch Task Execution Metrics:**
   Query Container Insights or CloudWatch Log Group `/ecs/airflow-blueprint-production-workers` for the container memory consumption trend prior to termination:
   ```bash
   aws logs filter-log-events \
     --log-group-name "/ecs/airflow-blueprint-production-workers" \
     --filter-pattern "MemoryError" \
     --output text
   ```

2. **Remediate via DAG `executor_config` (No Terraform Re-apply Required):**
   `AwsEcsExecutor` allows overriding the task-level compute parameters dynamically inside Python DAG code without modifying the global Terraform infrastructure:
   ```python
   # Increase memory allocation specifically for the heavy task
   process_large_dataset = PythonOperator(
       task_id="transform_heavy_dataset",
       python_callable=run_heavy_etl,
       executor_config={
           "cpu": 1024,      # Scale up to 1 vCPU
           "memory": 4096,   # Scale up to 4096 MiB (4 GiB RAM)
       },
   )
   ```
   *Valid Fargate CPU/Memory Combinations:*
   - `cpu: 256` $\rightarrow$ `memory: 512, 1024, 2048`
   - `cpu: 512` $\rightarrow$ `memory: 1024, 2048, 3072, 4096`
   - `cpu: 1024` $\rightarrow$ `memory: 2048, 3072, 4096, 5120, 6144, 7168, 8192`
   - `cpu: 2048` $\rightarrow$ `memory: 4096 to 16384`

---

## 3. Zombie Tasks or Database Connection Timeouts to RDS PostgreSQL

### Symptoms
- Airflow tasks remain marked as `running` in the Web UI indefinitely, even though the underlying Fargate task in ECS has already terminated or failed.
- Eventually, the Scheduler marks the task as a `Zombie Task` and terminates it:
  ```text
  TaskInstance detected as zombie: TaskInstanceKey(...)
  ```
- Worker container startup logs report:
  ```text
  psycopg2.OperationalError: could not connect to server: Connection timed out
  Is the server running on host "..." and accepting TCP/IP connections on port 5432?
  ```

### Root Cause Analysis (RCA)
When a Fargate worker task starts, it must connect back to Amazon RDS PostgreSQL (`sg_airflow_db` on port 5432) to report its heartbeat, status transitions, and XCom outputs. If `sg_airflow_workers` is not explicitly permitted in `sg_airflow_db`, packets are dropped silently, causing TCP handshake timeouts.

### Diagnostic & Remediation Steps

1. **Verify Security Group Chaining:**
   Inspect inbound rules for `sg_airflow_db` to confirm that `sg_airflow_workers` is authorized:
   ```bash
   aws ec2 describe-security-group-rules \
     --filters "Name=group-id,Values=<SG_AIRFLOW_DB_ID>" \
     --query "SecurityGroupRules[*].[FromPort,ToPort,ReferencedGroupInfo.GroupId,Description]" \
     --output table
   ```
   *Expected: An ingress rule with `FromPort: 5432`, `ToPort: 5432` referencing `sg_airflow_workers` ID.*

2. **Test PostgreSQL Port Connectivity from Private Subnet:**
   Start an SSM session on the Airflow EC2 instance and test the RDS endpoint:
   ```bash
   aws ssm start-session --target <EC2_INSTANCE_ID>
   ```
   Inside the instance shell:
   ```bash
   nc -zv <RDS_ENDPOINT_HOSTNAME> 5432
   # Expected: Connection to ... 5432 port [tcp/postgres] succeeded!
   ```

3. **Check PostgreSQL Active Connection Pool Limits:**
   If connections time out under high task concurrency, verify RDS `max_connections`:
   ```sql
   SELECT count(*) FROM pg_stat_activity;
   SHOW max_connections;
   ```

---

## 4. DAG Version Drift / Desynchronization Between Scheduler and Workers

### Symptoms
- Code updates pushed to GitHub appear in the Airflow Web UI, but worker execution runs an older version of the Python script or fails with `ImportError: cannot import name ...`.
- Tasks report stale task definitions or miss recently added dependencies.

### Root Cause Analysis (RCA)
In the hybrid model, DAG code distribution follows a two-tier synchronization mechanism:
1. Control Plane (EC2): Synchronized every 30 seconds via systemd timer `airflow-dag-sync.timer`.
2. Data Plane (Fargate Workers): Synchronized at container startup inside `entrypoint.sh` via `aws s3 sync`.
If the GitHub Actions workflow fails to push to the S3 bucket, or if an invalid S3 bucket path is configured in the ECS Task Definition environment, workers cannot fetch current code.

### Diagnostic & Remediation Steps

1. **Verify S3 Bucket Contents and Last Modified Timestamps:**
   ```bash
   aws s3 ls s3://<DAGS_BUCKET_NAME>/ --recursive --human-readable
   ```

2. **Verify EC2 Local DAG Sync Service Status:**
   ```bash
   aws ssm start-session --target <EC2_INSTANCE_ID>
   ```
   Inside EC2:
   ```bash
   systemctl status airflow-dag-sync.service
   systemctl status airflow-dag-sync.timer
   journalctl -u airflow-dag-sync.service -n 50 --no-pager
   ```

3. **Inspect Fargate Worker Entrypoint Logs in CloudWatch:**
   Search CloudWatch Logs for the S3 sync output of the failing task:
   ```bash
   aws logs filter-log-events \
     --log-group-name "/ecs/airflow-blueprint-production-workers" \
     --filter-pattern "Synchronizing DAGs" \
     --max-items 10 \
     --output table
   ```
   Ensure the output reports:
   ```text
   ==> Synchronizing DAGs from s3://... to /opt/airflow/dags...
   ==> S3 DAG sync completed successfully.
   ```

---

## 5. AWS Systems Manager (SSM) Session Manager Connection Failures

### Symptoms
- Running `aws ssm start-session --target <EC2_INSTANCE_ID>` fails with:
  ```text
  An error occurred (TargetNotConnected) when calling the StartSession operation: Instance is not connected to SSM.
  ```

### Root Cause Analysis (RCA)
The Amazon SSM Agent requires:
1. An active IAM Instance Profile with the managed policy `AmazonSSMManagedInstanceCore`.
2. Outbound network connectivity (TCP port 443) from the private subnet to regional SSM endpoints (`ssm.<region>.amazonaws.com`, `ssmmessages.<region>.amazonaws.com`, `ec2messages.<region>.amazonaws.com`) via the NAT Gateway.

### Diagnostic & Remediation Steps

1. **Verify IAM Instance Profile Attachment:**
   ```bash
   aws ec2 describe-instances \
     --instance-ids <EC2_INSTANCE_ID> \
     --query "Reservations[*].Instances[*].[InstanceId,IamInstanceProfile.Arn,State.Name]" \
     --output table
   ```

2. **Verify SSM Agent Registration Status:**
   ```bash
   aws ssm describe-instance-information \
     --filters "Key=InstanceIds,Values=<EC2_INSTANCE_ID>" \
     --output table
   ```
   *If the table is empty, the instance is unable to register with the AWS SSM service.*

3. **Inspect Instance Console Output via AWS CLI:**
   Retrieve the serial console log to verify boot and user-data execution:
   ```bash
   aws ec2 get-console-output \
     --instance-id <EC2_INSTANCE_ID> \
     --output text
   ```
