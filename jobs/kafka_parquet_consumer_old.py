from pyspark.sql import SparkSession
from pyspark.sql.functions import from_json, col
from pyspark.sql.types import StructType, StringType, IntegerType, BooleanType

# Define the schema for IoT data
schema = StructType() \
    .add("device_id", StringType()) \
    .add("battery_level", IntegerType()) \
    .add("motion_detected", BooleanType()) \
    .add("timestamp", StringType())

#spark = SparkSession.builder.appName("KafkaParquetToMinIO").getOrCreate()
# Build Spark session with proper S3A config
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
    .option("startingOffsets", "latest") \
    .option("kafka.group.id", "spark-consumers") \
    .load()

# Extract and parse JSON payload into structured columns
json_df = df.select(from_json(col("value").cast("string"), schema).alias("data")).select("data.*")

# Write to MinIO as Parquet
json_df.writeStream \
    .format("parquet") \
    .option("path", "s3a://spark-output/parquet") \
    .option("checkpointLocation", "/tmp/parquet-checkpoint") \
    .option("fs.s3a.access.key", "minioadmin") \
    .option("fs.s3a.secret.key", "minioadmin") \
    .option("fs.s3a.endpoint", "http://minio:9000") \
    .option("fs.s3a.path.style.access", "true") \
    .outputMode("append") \
    .start() \
    .awaitTermination()
