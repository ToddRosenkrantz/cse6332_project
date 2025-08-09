from pyspark.sql import SparkSession
from pyspark.sql.functions import from_json, col, to_date, hour
from pyspark.sql.types import StructType, StringType, IntegerType, BooleanType

# Define the schema for IoT data
schema = StructType() \
    .add("device_id", StringType()) \
    .add("battery_level", IntegerType()) \
    .add("motion_detected", BooleanType()) \
    .add("timestamp", StringType())

# Build Spark session with S3A config for MinIO
spark = SparkSession.builder \
    .appName("KafkaParquetToMinIO") \
    .config("spark.hadoop.fs.s3a.access.key", "minioadmin") \
    .config("spark.hadoop.fs.s3a.secret.key", "minioadmin") \
    .config("spark.hadoop.fs.s3a.endpoint", "http://minio:9000") \
    .config("spark.hadoop.fs.s3a.path.style.access", "true") \
    .config("spark.hadoop.fs.s3a.impl", "org.apache.hadoop.fs.s3a.S3AFileSystem") \
    .getOrCreate()

# Read Kafka stream
df = spark.readStream.format("kafka") \
    .option("kafka.bootstrap.servers", "kafka:29092") \
    .option("subscribe", "topic-parq") \
    .option("kafka.group.id", "spark-consumer-parq") \
    .option("kafka.metrics.recording.level", "DEBUG") \
    .option("kafka.consumer.metrics.enable", "true") \
    .load()
#    .option("kafka.group.id", "spark-consumers") \
#    .option("startingOffsets", "latest") \

# Parse JSON payload and add date/hour for partitioning
json_df = df.select(from_json(col("value").cast("string"), schema).alias("data")) \
    .select("data.*") \
    .withColumn("date", to_date(col("timestamp"))) \
    .withColumn("hour", hour(col("timestamp")))

# Write to MinIO as partitioned Parquet
json_df.writeStream \
    .format("parquet") \
    .option("path", "s3a://spark-output/parquet") \
    .option("checkpointLocation", "/tmp/parquet-checkpoint") \
    .partitionBy("date", "hour") \
    .outputMode("append") \
    .queryName("topic-parq_sink") \
    .start() \
    .awaitTermination()
