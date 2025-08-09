import time
import random
import logging
import sys
import threading
import json
from datetime import datetime
from kafka import KafkaProducer
from kafka.errors import KafkaError
from prometheus_client import start_http_server, Gauge

# To produce messages to store as json:
# python3 producer.py topic-json 9108
#
# To produce messages to store as parquet:
# python3 producer.py topic-parq 9109

# === Defaults ===
DEFAULT_TOPIC = "test-topic"
DEFAULT_BROKER = "localhost:9092"  # Use "kafka:29092" if inside Docker
DEFAULT_LAMBDA = 5
LOG_INTERVAL = 10  # seconds
if len(sys.argv) < 3:
    print("Usage: python3 producer.py <topic> <prometheus_port>")
    sys.exit(1)

args = sys.argv[1:]
TOPIC = args[0]
try:
    PROM_PORT = int(args[1])
except ValueError:
    print("Error: Prometheus port must be an integer.")
    sys.exit(1)

from pathlib import Path

now_str = datetime.now().strftime("%Y%m%d_%H%M%S")
run_id = 1
log_dir = Path("logs")
log_dir.mkdir(exist_ok=True)

while True:
    log_file_candidate = log_dir / f"{TOPIC}_run{run_id}_{now_str}.csv"
    if not log_file_candidate.exists():
        break
    run_id += 1

LOG_FILE = str(log_file_candidate)

# === Prometheus Setup ===
start_http_server(PROM_PORT)

# Shared metrics with labels
lambda_gauge = Gauge('kafka_producer_lambda', 'Current Poisson lambda', ['topic'])
message_rate_gauge = Gauge('kafka_producer_message_rate', 'Messages per second', ['topic'])
dropped_messages_gauge = Gauge('kafka_producer_dropped_messages', 'Number of dropped messages', ['topic'])
error_rate_gauge = Gauge('kafka_producer_error_rate', 'Errors per second', ['topic'])
average_delay_gauge = Gauge('kafka_producer_avg_delay', 'Average message delay (s)', ['topic'])

lambda_gauge.labels(topic=TOPIC).set(DEFAULT_LAMBDA)

# === Logging Setup ===
LOG_TEXT_FILE = log_dir / f"{TOPIC}_run{run_id}_{now_str}.log"
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s - %(message)s",
    handlers=[
        logging.StreamHandler(),
        logging.FileHandler(LOG_TEXT_FILE, mode='w')
    ]
)

sys.excepthook = lambda t, v, tb: logging.error(f"Unhandled exception: {v}")

# === Kafka Setup ===
producer = KafkaProducer(
    bootstrap_servers=DEFAULT_BROKER,
    retries=5,
    retry_backoff_ms=30000,
    max_block_ms=60000,
    value_serializer=lambda v: json.dumps(v).encode("utf-8")
)

msg_count = 0
error_count = 0
dropped_count = 0
total_delay = 0.0
start_time = time.time()
absolute_start = start_time

# Write CSV header
with open(LOG_FILE, 'w') as f:
    f.write("elapsed_seconds,rate,msg_count,error_count,dropped_count,avg_delay")

logging.info(f"Starting Poisson message producer to topic '{TOPIC}' on port {PROM_PORT}")

# === IoT Data Generator ===
def generate_iot_data():
    return {
        "device_id": f"iot_device_{random.randint(1, 50)}",
        "battery_level": random.randint(20, 100),
        "motion_detected": random.choice([True, False]),
        "timestamp": datetime.utcnow().isoformat() + "Z"
    }

# === Background thread to monitor lambda.txt ===
lambda_lock = threading.Lock()
current_lambda = [DEFAULT_LAMBDA]

def lambda_watcher():
    while True:
        try:
            with open(f"lambda_{TOPIC}.txt", "r") as f:
                value = float(f.read().strip())
                with lambda_lock:
                    current_lambda[0] = value
                    lambda_gauge.labels(topic=TOPIC).set(value)
        except Exception as e:
            logging.debug(f"Lambda watcher error: {e}")
        time.sleep(2)

threading.Thread(target=lambda_watcher, daemon=True).start()

try:
    while True:
        message = generate_iot_data()
        try:
            producer.send(TOPIC, value=message)
        except KafkaError as e:
            logging.error(f"Failed to send message: {e}")
            error_count += 1
            dropped_count += 1

        msg_count += 1

        now = time.time()
        with lambda_lock:
            delay = random.expovariate(current_lambda[0])
        total_delay += delay

        if now - start_time >= LOG_INTERVAL:
            elapsed = now - start_time
            total_elapsed = now - absolute_start
            rate = msg_count / elapsed
            avg_delay = total_delay / msg_count if msg_count else 0
            error_rate = error_count / elapsed if elapsed > 0 else 0

            logging.info(f"Sent {msg_count} messages in {elapsed:.2f}s ({rate:.2f} msg/sec), errors={error_count}, dropped={dropped_count}, avg_delay={avg_delay:.3f}s")

            message_rate_gauge.labels(topic=TOPIC).set(rate)
            dropped_messages_gauge.labels(topic=TOPIC).set(dropped_count)
            error_rate_gauge.labels(topic=TOPIC).set(error_rate)
            average_delay_gauge.labels(topic=TOPIC).set(avg_delay)

            with open(LOG_FILE, 'a') as f:
                f.write(f"{total_elapsed:.2f},{rate:.2f},{msg_count},{error_count},{dropped_count},{avg_delay:.4f}")

            msg_count = 0
            error_count = 0
            dropped_count = 0
            total_delay = 0.0
            start_time = now

        time.sleep(delay)

except KeyboardInterrupt:
    logging.info("Producer stopped by user.")

finally:
    producer.flush()
    producer.close()

# === Future Work ===
# 1. Use run_id to offset the Prometheus port (e.g., PROM_PORT = BASE_PORT + run_id) so multiple producers can run concurrently.
# 2. Enable multiple producers per topic to simulate distributed edge devices with shared Kafka ingestion.
# 3. Track additional metrics such as latency between production and Kafka acknowledgment.
# 4. Automatically rotate log files based on time or size.
# 5. Parameterize configuration via argparse or YAML config for better control.
