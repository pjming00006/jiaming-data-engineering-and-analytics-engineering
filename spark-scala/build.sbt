name := "spark-scala"

version := "0.1.0"

scalaVersion := "2.12.17"

// Pick a Spark version compatible with Scala 2.12 (Spark 3.x)
val sparkVersion = "3.5.6"

// For Testing Locally
// libraryDependencies ++= Seq(
//   "org.apache.spark" %% "spark-core" % sparkVersion,
//   "org.apache.spark" %% "spark-sql"  % sparkVersion
// )

// For EMR
libraryDependencies ++= Seq(
  "org.apache.spark" %% "spark-core" % sparkVersion % "provided",
  "org.apache.spark" %% "spark-sql"  % sparkVersion % "provided",
  "com.amazonaws" % "aws-java-sdk-s3" % "1.12.568",
)

assembly / assemblyMergeStrategy := {
  case PathList("META-INF", _ @ _*) => MergeStrategy.discard
  case _ => MergeStrategy.first
}