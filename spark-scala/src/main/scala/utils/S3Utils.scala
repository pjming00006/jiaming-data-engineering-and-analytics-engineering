package utils

import com.amazonaws.services.s3.AmazonS3
import com.amazonaws.services.s3.AmazonS3ClientBuilder
import com.amazonaws.services.s3.model.{ListObjectsV2Request, S3ObjectSummary}
import scala.collection.JavaConverters._
import java.time.{Instant, ZoneId}
import java.time.format.DateTimeFormatter

object S3Utils {
  // s3 client shared across util functions
  private val s3 = AmazonS3ClientBuilder.defaultClient()

  def breakS3Path(s3Path: String): (String, String) = {
    val path = s3Path.stripPrefix("s3://")
    val parts = path.split("/", 2)
    val bucket = parts(0)
    val prefix = if (parts.length > 1) parts(1).stripSuffix("/") + "/" else ""

    (bucket, prefix)
  }

  // Get current output version under s3 path
  def getVersion(s3Path: String): String = {

    val (bucket, prefix) = breakS3Path(s3Path)

    // List "folders" under the prefix
    val req = new ListObjectsV2Request()
      .withBucketName(bucket)
      .withPrefix(prefix)
      .withDelimiter("/")

    val result = s3.listObjectsV2(req)

    // Get existing 5-digit version folders
    val existing = result.getCommonPrefixes.asScala.toList
      .map(_.stripPrefix(prefix).stripSuffix("/"))
      .filter(p => p.forall(_.isDigit) && p.length == 5)
      .sorted(Ordering[String].reverse)

    // Compute next version
    val curr = if (existing.nonEmpty) existing.head.toInt else 0
    f"$curr%05d"
  }

  def getNextVersion(currVersion: String): String = {
    val nextVersionInt = currVersion.toInt + 1
    f"$nextVersionInt%05d"
  }

  def listPartitions(s3Path: String): Seq[String] = {

    def recurse(bucket: String, prefix: String): Seq[String] = {
      val req = new ListObjectsV2Request()
        .withBucketName(bucket)
        .withPrefix(prefix)
        .withDelimiter("/")

      val res = s3.listObjectsV2(req)
      val subPartitions = res.getCommonPrefixes.asScala.toSeq

      if (subPartitions.isEmpty) {
        // This prefix has no more subfolders → deepest node
        Seq(f"s3://${bucket}/${prefix}")
      } else {
        // Recurse into each sub-partition
        subPartitions.flatMap(p => recurse(bucket, p))
      }
    }

    val (bucket, prefix) = breakS3Path(s3Path)
    recurse(bucket, prefix)
  }

  def listFiles(s3Path: String): Seq[S3ObjectSummary] = {

    val (bucket, prefix) = breakS3Path(s3Path)
    val req = new ListObjectsV2Request()
      .withBucketName(bucket)
      .withPrefix(prefix)
    s3.listObjectsV2(req).getObjectSummaries.asScala.toSeq
    
  }

  def findTargetPartition(
    path: String,
    latest: Boolean = true
  ): String = {

    val (bucket, prefix) = breakS3Path(path)

    val req = new ListObjectsV2Request()
      .withBucketName(bucket)
      .withPrefix(prefix)
      .withDelimiter("/")

    val res = s3.listObjectsV2(req)
    val prefixes = res.getCommonPrefixes.asScala

    if (prefixes.isEmpty) {
      // no more subfolders. This is the deepest partition
      f"s3://${bucket}/${prefix}"
    } else {
      // pick latest subfolder and recurse
      val targetPrefix = if (latest) prefixes.max else prefixes.min
      findTargetPartition(s"s3://${bucket}/${targetPrefix}", latest)
    }
  }

  def getTargetS3File(
    s3Path: String,
    afterTs: Option[Instant] = None,
    latest: Boolean = true
  ): Option[(String, Instant)] = {

    def fileTs(obj: S3ObjectSummary): Instant = obj.getLastModified.toInstant

    val (bucket, prefix) = breakS3Path(s3Path)

    if (latest) {
      val targetPartition = findTargetPartition(s3Path, latest = true)
      val files = listFiles(targetPartition)

      files.sortBy(fileTs).lastOption.map { f =>
        (f"s3://${bucket}/${f.getKey}", fileTs(f))
      }
    }

    else if (afterTs.isEmpty) {
      val targetPartition = findTargetPartition(s3Path, latest = false)
      val files = listFiles(targetPartition)

      files.sortBy(fileTs).headOption.map { f =>
        (f"s3://${bucket}/${f.getKey}", fileTs(f))
      }
    }

    else {
      val ts = afterTs.get

      val partitions = listPartitions(s3Path)
      val allFiles = partitions.flatMap(listFiles)

      // filter earliest after ts
      allFiles
        .filter(f => fileTs(f).isAfter(ts))
        .sortBy(fileTs)
        .headOption
        .map(f => (s"s3://$bucket/${f.getKey}", fileTs(f)))
    }
  }

}
