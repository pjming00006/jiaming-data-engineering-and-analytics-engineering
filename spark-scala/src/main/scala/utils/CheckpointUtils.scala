package utils

import java.time.Instant
import com.fasterxml.jackson.databind.ObjectMapper
import com.fasterxml.jackson.module.scala.DefaultScalaModule
import com.amazonaws.services.s3.model.PutObjectRequest
import java.io.ByteArrayInputStream

object CheckpointUtils {

  case class Checkpoint(
    earliest_file: String,
    earliest_ts: String,
    latest_file: String,
    latest_ts: String,
    run_time: String,
    mode: String
  )

  private val mapper = new ObjectMapper().registerModule(DefaultScalaModule)

  def generateCheckpoint(
    s3Path: String,
    mode: String,
    earliestFile: String,
    earliestTs: Instant,
    latestFile: String,
    latestTs: Instant
  ): Unit = {

    val cp = Checkpoint(
      earliest_file = earliestFile,
      earliest_ts   = earliestTs.toString,
      latest_file   = latestFile,
      latest_ts     = latestTs.toString,
      run_time      = Instant.now.toString,
      mode          = mode
    )

    val json = mapper.writeValueAsString(cp)

    val (bucket, prefix) = S3Utils.breakS3Path(s3Path, false)
    val stream = new ByteArrayInputStream(json.getBytes("UTF-8"))

    S3Utils.s3.putObject(
      new PutObjectRequest(bucket, prefix, stream, null)
    )
  }

  def readCheckpoint(s3Path: String): Checkpoint = {
    val (bucket, key) = S3Utils.breakS3Path(s3Path, isFolder = false)
    val s3Object = S3Utils.s3.getObject(bucket, key)
    val inputStream: InputStream = s3Object.getObjectContent
    val checkpoint = mapper.readValue(inputStream, classOf[Checkpoint])
    inputStream.close()
    checkpoint
  }
}
