import utils.S3Utils
import org.apache.logging.log4j.LogManager
import org.apache.logging.log4j.Logger

object Test {
  def main(args: Array[String]): Unit = {
    val logger: Logger = LogManager.getLogger(getClass)
    logger.info("Hello")

    val s3Path = "s3://etl-poc-2025-b8a9c11/spark-scala/userDimensionCdcFull/"

    val currVersion = S3Utils.getVersion(s3Path)
    println(s"Current version: $currVersion")

    val nextVersion = S3Utils.getNextVersion(currVersion)
    println(s"Next version: $nextVersion")

    System.exit(0)
  }
}
