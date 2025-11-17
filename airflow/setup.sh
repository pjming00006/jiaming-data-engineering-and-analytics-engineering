# Documentation: https://airflow.apache.org/docs/apache-airflow/stable/howto/docker-compose/index.html

echo "AIRFLOW_UID=$(id -u)" > .env

# Download docker compose file for Airlfow
curl -LfO "https://airflow.apache.org/docs/apache-airflow/3.1.3/docker-compose.yaml"

# Run Airflow initialization
docker compose up airflow-init

# Run Airflow services
docker compose up -d