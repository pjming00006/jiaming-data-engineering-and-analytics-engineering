from airflow import DAG
from airflow.models import Variable
from airflow.providers.amazon.aws.operators.emr import EmrCreateJobFlowOperator
from airflow.providers.amazon.aws.sensors.emr import EmrJobFlowSensor
from datetime import datetime, timedelta

JAR_S3_PATH = f"s3://{Variable.get("de_etl_bucket")}/emr_packages/{{{{ jar_name }}}}"

# EMR cluster configuration
JOB_FLOW_OVERRIDES = {
    "Name": "single-step-emr-job",
    "ReleaseLabel": "emr-7.12.0",
    "Applications": [{"Name": "Spark"}],
    "Instances": {
        "InstanceGroups": [
            {
                "Name": "Master",
                "InstanceRole": "MASTER",
                "InstanceType": "r8g.xlarge", # r8g.xlarge, c5.xlarge
                "InstanceCount": 1,
            },
        ],
        "KeepJobFlowAliveWhenNoSteps": False,
        "Ec2SubnetId": Variable.get("emr_subnet_id"),
        "EmrManagedMasterSecurityGroup": Variable.get("emr_master_sg_id"),
        "EmrManagedSlaveSecurityGroup": Variable.get("emr_slave_sg_id"),
        "AdditionalMasterSecurityGroups": [],
        "AdditionalSlaveSecurityGroups": []
    },

    "Steps": [
        {
            "Name": "run-my-jar",
            "ActionOnFailure": "TERMINATE_CLUSTER",
            "HadoopJarStep": {
                "Jar": "command-runner.jar",
                "Args": [
                    "spark-submit",
                    "--deploy-mode", "cluster",
                    "--class", "{{ params.entrypoint_class }}", # It's required to specify an entrypoint
                    JAR_S3_PATH
                ],
            },
        }
    ],
    "JobFlowRole": f"arn:aws:iam::{Variable.get("aws_account_id")}:instance-profile/emr-instance-profile",
    "ServiceRole": f"arn:aws:iam::{Variable.get("aws_account_id")}:role/emr-service-role",
    "AutoTerminationPolicy": {"IdleTimeout": 60},
    "LogUri": f"s3://{Variable.get("de_etl_bucket")}/spark-test/logs/{{{{ run_id }}}}/",
}

# ----- DAG -----
with DAG(
    "sample_emr",
    start_date=datetime(2025, 1, 1),
    schedule=None,
    catchup=False,
    default_args={"retries": 0},
    params={"entrypoint_class": "HelloSpark",
            "jar_name": "spark-scala-assembly-0.1.0.jar"}
):

    create_cluster = EmrCreateJobFlowOperator(
        task_id="create_cluster",
        job_flow_overrides=JOB_FLOW_OVERRIDES,
        aws_conn_id=None,  # uses your mounted ~/.aws creds
    )

    wait_for_cluster = EmrJobFlowSensor(
        task_id="wait_for_cluster",
        job_flow_id=create_cluster.output,
        aws_conn_id=None,
    )

    create_cluster >> wait_for_cluster
