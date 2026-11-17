# ==============================================================================
# Stage 1: Build Dependencies and AWS CLI
# ==============================================================================
FROM apache/airflow:2.9.2-python3.11 AS builder

USER root

# Install system compilation dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    unzip \
    gcc \
    g++ \
    libpq-dev \
    && rm -rf /var/lib/apt/lists/*

# Install AWS CLI v2
RUN curl -fsSL "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip" \
    && unzip -q awscliv2.zip \
    && ./aws/install --bin-dir /usr/local/bin --install-dir /usr/local/aws-cli \
    && rm -rf awscliv2.zip aws

# ==============================================================================
# Stage 2: Runtime Production Image (Non-Root)
# ==============================================================================
FROM apache/airflow:2.9.2-python3.11 AS runtime

USER root

# Copy AWS CLI v2 from builder stage
COPY --from=builder /usr/local/aws-cli /usr/local/aws-cli
COPY --from=builder /usr/local/bin/aws /usr/local/bin/aws

# Install runtime PostgreSQL client library
RUN apt-get update && apt-get install -y --no-install-recommends \
    libpq5 \
    && rm -rf /var/lib/apt/lists/*

# Copy entrypoint script and set executable permissions
COPY entrypoint.sh /entrypoint.sh
RUN chmod 755 /entrypoint.sh \
    && chown airflow:root /entrypoint.sh \
    && mkdir -p /opt/airflow/dags \
    && chown -R airflow:root /opt/airflow/dags

# Switch back to standard non-root airflow user (UID 50000)
USER airflow

# Install Airflow AWS and Postgres providers
RUN pip install --no-cache-dir \
    "apache-airflow-providers-amazon>=8.20.0" \
    "apache-airflow-providers-postgres>=5.11.0" \
    "psycopg2-binary>=2.9.9"

# Configure working directory and entrypoint
WORKDIR /opt/airflow
ENTRYPOINT ["/entrypoint.sh"]
CMD ["airflow", "--help"]
