#!/bin/bash
set -euo pipefail

# ==============================================================================
# Airflow Worker Entrypoint (AwsEcsExecutor on AWS Fargate)
# Synchronizes latest DAG code from S3 before executing task workload.
# ==============================================================================

echo "=========================================================="
echo " Starting Ephemeral Airflow Worker on AWS Fargate"
echo "=========================================================="

AIRFLOW_DAGS_DIR="${AIRFLOW__CORE__DAGS_FOLDER:-/opt/airflow/dags}"
mkdir -p "${AIRFLOW_DAGS_DIR}"

if [ -n "${DAGS_S3_BUCKET:-}" ]; then
    echo "==> Synchronizing DAGs from s3://${DAGS_S3_BUCKET}/ to ${AIRFLOW_DAGS_DIR}..."
    aws s3 sync "s3://${DAGS_S3_BUCKET}/" "${AIRFLOW_DAGS_DIR}/" --delete
    echo "==> S3 DAG sync completed successfully."
else
    echo "==> WARNING: DAGS_S3_BUCKET environment variable not set. Skipping S3 sync."
fi

echo "==> Handing over execution to Airflow command: $@"
exec "$@"
