# 1. list containers
docker compose ps

# 2. exec into the webserver (or scheduler) container
docker compose exec airflow-apiserver bash
# or into scheduler/worker:
docker compose exec airflow-scheduler bash

# inside the container: check version + dags
airflow version
airflow db check  # sanity check for DB connection
airflow dags list

# to see logs from host (without entering):
docker compose logs -f airflow-webserver