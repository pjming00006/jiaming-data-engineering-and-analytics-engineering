import org.apache.spark.sql.{SparkSession, DataFrame}
import org.apache.spark.sql.expressions.Window
import org.apache.spark.sql.functions._
import org.apache.logging.log4j.LogManager
import org.apache.logging.log4j.Logger

import utils.CheckpointUtils
import utils.S3Utils

object UserDimensionTransformer {
  def main(args: Array[String]): Unit = {
    val mode = if (args.nonEmpty && args(0).toLowerCase == "incremental") "incremental" else "full"

    val sourcePath  = "s3://etl-poc-2025-b8a9c11/dynamo-lambda-firehose-s3-etl-parquet/"
    val targetPath = "s3://etl-poc-2025-b8a9c11/spark-scala/userDimensionCdcFull/"

    val logger: Logger = LogManager.getLogger(getClass)

    val spark = SparkSession.builder()
      .appName("user-dimension-job")
    //   .master("local[*]")
      .getOrCreate()
    
    // Get target version
    val currVersion = S3Utils.getVersion(targetPath)
    val nextVersion = S3Utils.getNextVersion(currVersion)
    logger.info(f"Current Version: ${currVersion}, Next Version: ${nextVersion}")

    // Construct Output paths
    val outputBasePath = targetPath + nextVersion + "/"
    val outputDataPath = outputBasePath + "Data/"
    val outputCheckpointPath = outputBasePath + "Checkpoint/checkpoint.json"

    // Full Load Checkpoint
    val (earliestFile, earliestFileTs) =
        S3Utils.getTargetS3File(sourcePath, None, false) match {
            case Some((file, ts)) => (file, ts)
            case None             => throw new Exception("No earliest file found")
    }

    val (latestFile, latestFileTs) =
        S3Utils.getTargetS3File(sourcePath, None, true) match {
            case Some((file, ts)) => (file, ts)
            case None             => throw new Exception("No latest file found")
    }

    val targetFileList =
        if (earliestFileTs != latestFileTs) {
            S3Utils.getFilesBetween(sourcePath, earliestFileTs, latestFileTs)
        } else {
            Seq(earliestFile)   // only one file in range
        }
    
    // Full Load Logic
    val df = spark.read.parquet(targetFileList: _*)

    // SCD Type 1 processing
    val windowSpec = Window.partitionBy("user_id").orderBy(col("processing_timestamp").desc)
    val df_rk = df.withColumn("rk", row_number().over(windowSpec)).filter("rk = 1")

    // --- Write result back to S3 ---
    CheckpointUtils.generateCheckpoint(outputCheckpointPath, mode, earliestFile, earliestFileTs, latestFile, latestFileTs)

    df.write.mode("overwrite").parquet(outputDataPath)

    logger.info(s"Write complete: $outputDataPath")

    spark.stop()
  }
}
