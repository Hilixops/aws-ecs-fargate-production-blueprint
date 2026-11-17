"""
Example ETL DAG for AWS Apache Airflow Hybrid Blueprint.
Demonstrates dynamic CPU and Memory sizing per task on AWS Fargate using AwsEcsExecutor.
"""

from datetime import datetime, timedelta
from airflow import DAG
from airflow.operators.python import PythonOperator
from airflow.operators.bash import BashOperator

default_args = {
    "owner": "airflow",
    "depends_on_past": False,
    "email_on_failure": False,
    "email_on_retry": False,
    "retries": 1,
    "retry_delay": timedelta(minutes=2),
}

def extract_data(**context):
    print("Extracting business records from source systems...")
    return {"total_records": 50000, "status": "EXTRACTED"}

def transform_data(**context):
    print("Executing heavy transformations in memory...")
    ti = context["ti"]
    extracted = ti.xcom_pull(task_ids="extract_task")
    print(f"Transforming {extracted['total_records']} rows using dedicated Fargate capacity.")
    return {"status": "TRANSFORMED"}

def load_data(**context):
    print("Loading validated data records into Clients Database...")
    return {"status": "SUCCESS"}

with DAG(
    dag_id="example_etl_fargate",
    default_args=default_args,
    description="Production ETL pipeline utilizing elastic AWS Fargate tasks via AwsEcsExecutor",
    schedule_interval=timedelta(days=1),
    start_date=datetime(2026, 1, 1),
    catchup=False,
    tags=["production", "fargate", "etl", "blueprint"],
) as dag:

    # Task 1: Lightweight extraction task (256 CPU, 512 MiB RAM)
    extract_task = PythonOperator(
        task_id="extract_task",
        python_callable=extract_data,
        executor_config={
            "cpu": 256,
            "memory": 512,
        },
    )

    # Task 2: Compute-intensive transformation task (1024 CPU, 2048 MiB RAM)
    transform_task = PythonOperator(
        task_id="transform_task",
        python_callable=transform_data,
        executor_config={
            "cpu": 1024,
            "memory": 2048,
        },
    )

    # Task 3: Database loading task (512 CPU, 1024 MiB RAM)
    load_task = PythonOperator(
        task_id="load_task",
        python_callable=load_data,
        executor_config={
            "cpu": 512,
            "memory": 1024,
        },
    )

    # Orchestrate workflow dependencies
    extract_task >> transform_task >> load_task
