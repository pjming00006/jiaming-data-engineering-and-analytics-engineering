import utils.S3Utils
import java.time.Instant

import com.amazonaws.services.s3.AmazonS3ClientBuilder
import com.amazonaws.services.s3.model.ListObjectsV2Request

object Test {
  def main(args: Array[String]): Unit = {
    val userDimensionPath = "s3://etl-poc-2025-b8a9c11/spark-scala/userDimensionCdcFull/"
    val s3Path = "s3://etl-poc-2025-b8a9c11/dynamo-lambda-firehose-s3-etl-parquet/"

    val (bucket, prefix) = S3Utils.breakS3Path(s3Path)
    println(f"Testing S3Utils.breakS3Path: bucket: ${bucket}, prefix: ${prefix}")

    val currVersion = S3Utils.getVersion(userDimensionPath)
    println(s"Testing S3Utils.getVersion: currVersion: $currVersion")

    val nextVersion = S3Utils.getNextVersion(currVersion)
    println(s"Testing S3Utils.getNextVersion: nextVersion: $nextVersion")

    val latestPartition = S3Utils.findTargetPartition(userDimensionPath)
    println(s"Testing S3Utils.findTargetPartition: latestPartition: $latestPartition")

    val earliestPartition = S3Utils.findTargetPartition(userDimensionPath, false)
    println(s"Testing S3Utils.findTargetPartition: earliestPartition: $earliestPartition")

    S3Utils.getTargetS3File(s3Path, None) match {
      case Some((f, ts)) =>
        println(s"Testing S3Utils.getTargetS3File: Latest file: $f, lastModified: $ts")
      case None =>
        println("No file found")
    }

    S3Utils.getTargetS3File(s3Path, None, false) match {
      case Some((f, ts)) =>
        println(s"Testing S3Utils.getTargetS3File: Earliest file: $f, lastModified: $ts")
      case None =>
        println("No file found")
    }

    val ts = Instant.parse("2025-10-30T20:00:00Z")
    S3Utils.getTargetS3File(s3Path, Some(ts), false) match {
      case Some((f, ts)) =>
        println(s"Testing S3Utils.getTargetS3File: Earliest file after certain ts: $f, lastModified: $ts")
      case None =>
        println("No file found")
    }

    val (fileBucket, filePrefix) = S3Utils.breakS3Path("s3://etl-poc-2025-b8a9c11/spark-scala/userDimensionCdcFull/00018/Checkpoint/checkpoint.json", false)
    println(f"Testing S3Utils.breakS3Path: fileBucket: ${fileBucket}, prefix: ${filePrefix}")

    System.exit(0)
  }
}
