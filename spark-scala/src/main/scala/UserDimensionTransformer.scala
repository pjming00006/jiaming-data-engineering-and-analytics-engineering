import java.time.Instant

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

    logger.info(f"Application user-dimension-job started running with ${mode} mode...")
    
    // Get target version
    val currVersion = S3Utils.getVersion(targetPath)
    val nextVersion = S3Utils.getNextVersion(currVersion)
    logger.info(f"Current Version: ${currVersion}, Next Version: ${nextVersion}")

    // Construct Output paths
    val dataFolder = "Data/"
    val checkpointFilePrefix = "Checkpoint/checkpoint.json"

    val outputBasePath = targetPath + nextVersion + "/"
    val outputDataPath = outputBasePath + dataFolder
    val outputCheckpointPath = outputBasePath + checkpointFilePrefix

    // Construct file ranges used for incremental loading and checkpoint writing
    val (latestFile, latestFileTs) =
          S3Utils.getTargetS3File(sourcePath, None, true) match {
              case Some((file, ts)) => (file, ts)
              case None             => throw new Exception("No latest file found")
    }

    val maybeEarliest: Option[(String, Instant)] =
      if (mode == "full") {
        S3Utils.getTargetS3File(sourcePath, None, false)
      } 
      else {
        val latestVersionCheckpointPath = targetPath + currVersion + "/" + checkpointFilePrefix
        val checkpoint = CheckpointUtils.readCheckpoint(latestVersionCheckpointPath)
        val checkpointTs = Instant.parse(checkpoint.latest_ts)
        logger.info(s"Checkpoint found at $latestVersionCheckpointPath, latest file: ${checkpoint.latest_file}")

        S3Utils.getTargetS3File(sourcePath, Some(checkpointTs), false)
      }


    val (earliestFile, earliestFileTs) = maybeEarliest match {
      case Some((file, ts)) => (file, ts)
      case None =>
        if (mode == "incremental") {
          logger.info("No new files to process; exiting incremental run.")
          spark.stop()
          System.exit(0)
          ("", Instant.EPOCH) // dummy, won't be used
        } else {
          throw new Exception("No earliest file found in full load")
        }
    }

    var df: DataFrame = null

    if (mode == "full") {
      df = spark.read.parquet(sourcePath)
    } else {
      // incremental
      val targetFileList =
        if (earliestFileTs != latestFileTs) {
          S3Utils.getFilesBetween(sourcePath, earliestFileTs, latestFileTs)
        } else Seq(earliestFile)

      if (targetFileList.isEmpty) {
        logger.info("No new files to process; exiting incremental run.")
        spark.stop()
        System.exit(0)
      }

      val sourceLoadDf = spark.read.parquet(targetFileList: _*)
      val latestTargetDf = spark.read.parquet(targetPath + currVersion + "/" + dataFolder)
      df = sourceLoadDf.union(latestTargetDf)
    }

    // SCD Type 1 processing
    val windowSpec = Window.partitionBy("user_id").orderBy(col("processing_timestamp").desc)
    val df_rk = df.withColumn("rk", row_number().over(windowSpec)).filter("rk = 1").drop("rk")

    // --- Write result back to S3 ---
    CheckpointUtils.generateCheckpoint(outputCheckpointPath, mode, earliestFile, earliestFileTs, latestFile, latestFileTs)

    df_rk.write.mode("overwrite").parquet(outputDataPath)

    logger.info(s"Write complete: $outputDataPath")

    spark.stop()
  }
}
