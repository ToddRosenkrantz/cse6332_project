# RAM check function (Linux/macOS compatible)
check_ram := $(shell awk '/MemTotal/ {if ($2 < 6000000) exit 1}' /proc/meminfo 2>/dev/null || echo OK)

run:
	docker-compose up -d

stop:
	docker-compose down

logs:
	docker-compose logs -f --tail=50

reset:
	docker-compose down -v
	rm -rf /tmp/parquet-checkpoint/

open:
	@echo "Grafana:     http://localhost:3000"
	@echo "MinIO:       http://localhost:9001"
	@echo "Prometheus:  http://localhost:9090"

clean:
	@read -p "This will remove all containers/images/volumes. Are you sure? [y/N] " confirm && \
	if [ "$$confirm" = "y" ] || [ "$$confirm" = "Y" ]; then \
	  docker compose down -v --rmi all --remove-orphans; \
	else \
	  echo "Aborted."; \
	fi

install:
	@echo "> Installing Python dependencies..."
	pip3 install -r requirements.txt || true
	@echo "> Downloading required Spark/Kafka JARs..."
	./download_spark_kafka_jars.sh || true
	@echo "> Installing MinIO client (mc)..."
	[ -f ./mc ] || (wget -q https://dl.min.io/client/mc/release/linux-amd64/mc && chmod +x mc)
#	@echo "> Creating MinIO bucket if not exists..."
#	./mc alias set local http://localhost:9000 minioadmin minioadmin >/dev/null 2>&1 || true
#	./mc mb local/spark-output || echo "Bucket already exists"

lite:
	@echo "> Checking RAM..."
	@if [ "$(check_ram)" != "OK" ]; then \
	  echo "⚠️  WARNING: Available RAM appears to be less than 6GB. This setup may be unstable."; \
	fi
	docker compose -f docker-compose-lite.yml up -d
