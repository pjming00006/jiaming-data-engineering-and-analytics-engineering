import org.apache.spark.sql.SparkSession

object HelloSpark {
  def main(args: Array[String]): Unit = {
    println(s"Creating a Spark app...")
    val spark = SparkSession.builder()
      .appName("hello-spark")
      .getOrCreate()

    println(s"Spark App created.")
    // val sc = spark.sparkContext
    // println(s"Spark version: ${sc.version}")

    // val data = sc.parallelize(1 to 10)
    // val doubled = data.map(x => x * 2).collect()
    // println("doubled: " + doubled.mkString(", "))

    // spark.stop()
    println(s"Hello World!!!!")
    println(s"Hello World!!!!")
    println(s"Hello World!!!!")
  }
}
