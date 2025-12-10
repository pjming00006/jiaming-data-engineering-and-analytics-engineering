package utils

import com.amazonaws.services.s3.AmazonS3ClientBuilder
import com.amazonaws.services.s3.model.ListObjectsV2Request
import scala.collection.JavaConverters._

object S3Utils {

  // Get current output version under s3 path
  def getVersion(s3Path: String): String = {

    // Extract bucket and prefix by simple split (no regex)
    val path = s3Path.stripPrefix("s3://")
    val parts = path.split("/", 2)
    val bucket = parts(0)
    val prefix = if (parts.length > 1) parts(1).stripSuffix("/") + "/" else ""

    // Create S3 client
    val s3 = AmazonS3ClientBuilder.defaultClient()

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
}
