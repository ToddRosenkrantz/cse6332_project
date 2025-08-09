#!/bin/bash

#   This script manages the JSON and Parquet producers.
#   It can start, stop, and check the status of the producers.
#
#   Prior to first running this script, ensure that:  
#   chmod +x manage_producers.sh
#
#   Start both producers
#   ./manage_producers.sh start

#   Stop them
#   ./manage_producers.sh stop

#   Check if they're running
#   ./manage_producers.sh status

#!/bin/bash

PRODUCER_SCRIPT="poisson_kafka_producer.py"
JSON_TOPIC="topic-json"
PARQ_TOPIC="topic-parq"
JSON_PORT=9108
PARQ_PORT=9109
JSON_PID="producer_json.pid"
PARQ_PID="producer_parq.pid"

start_producer() {
  local topic=$1
  local port=$2
  local pidfile=$3
  local log=$4

  if [ -f "$pidfile" ] && ps -p $(cat "$pidfile") > /dev/null 2>&1; then
    echo "⚠️  Producer for $topic is already running (PID $(cat "$pidfile"))"
    return
  fi

  echo "🚀 Starting producer for topic: $topic on port $port"
  [ ! -f lambda_${topic}.txt ] && echo 5 > lambda_${topic}.txt

  python3 $PRODUCER_SCRIPT $topic $port > "$log" 2>&1 &
  echo $! > "$pidfile"
  sleep 1

  if ! ps -p $(cat "$pidfile") > /dev/null 2>&1; then
    echo "❌ Failed to start producer for $topic. Check $log"
    rm -f "$pidfile"
  else
    echo "✅ Producer for $topic started (PID $(cat "$pidfile"))"
  fi
}

stop_producer() {
  local name=$1
  local pidfile=$2

  if [ -f "$pidfile" ]; then
    local pid=$(cat "$pidfile")
    if ps -p "$pid" > /dev/null 2>&1; then
      echo "🛑 Sending SIGTERM to $name (PID $pid)"
      kill -TERM "$pid"
      for i in {1..5}; do
        sleep 1
        if ! ps -p "$pid" > /dev/null 2>&1; then
          echo "✅ $name stopped gracefully"
          rm -f "$pidfile"
          return
        fi
      done
      echo "⚠️  $name did not stop after 5 seconds, sending SIGKILL..."
      kill -KILL "$pid"
      rm -f "$pidfile"
      echo "✅ $name forcibly stopped"
    else
      echo "⚠️  No running process found for $name. Cleaning up stale PID."
      rm -f "$pidfile"
    fi
  else
    echo "ℹ️  No PID file for $name"
  fi
}

status_producer() {
  local name=$1
  local pidfile=$2

  if [ -f "$pidfile" ]; then
    local pid=$(cat "$pidfile")
    if ps -p "$pid" > /dev/null 2>&1; then
      echo "✅ $name running (PID $pid)"
    else
      echo "❌ $name PID file exists, but process is not running"
    fi
  else
    echo "❌ $name not running"
  fi
}

case "$1" in
  start)
    start_producer "$JSON_TOPIC" "$JSON_PORT" "$JSON_PID" "json.log"
    start_producer "$PARQ_TOPIC" "$PARQ_PORT" "$PARQ_PID" "parq.log"
    ;;
  stop)
    stop_producer "JSON Producer" "$JSON_PID"
    stop_producer "Parquet Producer" "$PARQ_PID"
    ;;
  status)
    status_producer "JSON Producer" "$JSON_PID"
    status_producer "Parquet Producer" "$PARQ_PID"
    ;;
  *)
    echo "Usage: $0 {start|stop|status}"
    ;;
esac

