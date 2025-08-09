from pyspark.sql import SparkSession

spark = SparkSession.builder \
    .appName("KafkaJSONToMinIO") \
    .config("spark.hadoop.fs.s3a.access.key", "minioadmin") \
    .config("spark.hadoop.fs.s3a.secret.key", "minioadmin") \
    .config("spark.hadoop.fs.s3a.endpoint", "http://minio:9000") \
    .config("spark.hadoop.fs.s3a.path.style.access", "true") \
    .config("spark.hadoop.fs.s3a.impl", "org.apache.hadoop.fs.s3a.S3AFileSystem") \
    .getOrCreate()


df = spark.readStream.format("kafka") \
    .option("kafka.bootstrap.servers", "kafka:29092") \
    .option("subscribe", "topic-json") \
    .option("startingOffsets", "latest") \
    .option("kafka.group.id", "spark-consumers") \
    .load()

parsed_df = df.selectExpr("CAST(value AS STRING) as value", "timestamp")

parsed_df.writeStream \
    .format("json") \
    .option("path", "s3a://spark-output/json") \
    .option("checkpointLocation", "/tmp/json-checkpoint") \
    .outputMode("append") \
    .start() \
    .awaitTermination()
