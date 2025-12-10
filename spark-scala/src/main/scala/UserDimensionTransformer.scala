import org.apache.spark.sql.{SparkSession, DataFrame}
import org.apache.spark.sql.expressions.Window
import org.apache.spark.sql.functions._
import org.apache.logging.log4j.LogManager
import org.apache.logging.log4j.Logger

import utils.S3Utils

object UserDimensionTransformer {
  def main(args: Array[String]): Unit = {
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

    // Full Load
    val df = spark.read.parquet(sourcePath)

    // SCD Type 1 processing
    val windowSpec = Window.partitionBy("user_id").orderBy(col("processing_timestamp").desc)
    val df_rk = df.withColumn("rk", row_number().over(windowSpec)).filter("rk = 1")

    // --- Write result back to S3 ---
    val outputPath = targetPath + nextVersion + "/"

    df.write.mode("overwrite").parquet(outputPath)

    logger.info(s"Write complete: $outputPath")

    spark.stop()
  }
}
