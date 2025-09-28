#!/usr/bin/env bash
#
#   Manage confluent-kafka producers (one process per topic).
#   Works with the dynamic producer script that watches:
#     - lambda_<topic>.txt         (float; Poisson lambda)
#     - producers_<topic>.txt      (int; number of producer threads)
#
#   Usage:
#     ./manage_producers_ckafka.sh start
#     ./manage_producers_ckafka.sh stop
#     ./manage_producers_ckafka.sh status
#     ./manage_producers_ckafka.sh set-lambda  <topic-json|topic-parq> <value>
#     ./manage_producers_ckafka.sh set-prods   <topic-json|topic-parq> <count>
#     ./manage_producers_ckafka.sh logs        <topic-json|topic-parq>
#
#   Prereqs:
#     - python3 installed
#     - confluent-kafka in requirements.txt (pip install -r requirements.txt)
#     - producer script: producer_confluent_kafka.py
#
#   Notes:
#     - Uses separate PID/LOG filenames from manage_producers.sh
#     - If running alongside the kafka-python producers, use different ports
#

set -euo pipefail

# Producer script for confluent-kafka
PRODUCER_SCRIPT="producer_confluent_kafka.py"

# Topics
JSON_TOPIC="topic-json"
PARQ_TOPIC="topic-parq"

# Ports (change if running alongside old producers)
JSON_PORT=9118
PARQ_PORT=9119

# PID and log file names
JSON_PID="producer_json_ck.pid"
PARQ_PID="producer_parq_ck.pid"
JSON_LOG="json_ck.log"
PARQ_LOG="parq_ck.log"

is_running() { [[ -f "$1" ]] && ps -p "$(cat "$1")" >/dev/null 2>&1; }

ensure_ctrl_files() {
  local topic="$1"
  [[ -f "lambda_${topic}.txt"    ]] || echo 5  > "lambda_${topic}.txt"
  [[ -f "producers_${topic}.txt" ]] || echo 2  > "producers_${topic}.txt"
}

start_one() {
  local topic="$1" port="$2" pidfile="$3" logfile="$4"
  if is_running "$pidfile"; then
    echo "⚠️  $topic already running (PID $(cat "$pidfile"))"; return
  fi
  ensure_ctrl_files "$topic"
  echo "🚀 Starting $topic on port $port"
  nohup python3 "$PRODUCER_SCRIPT" "$topic" "$port" > "$logfile" 2>&1 &
  echo $! > "$pidfile"
  sleep 1
  is_running "$pidfile" && echo "✅ $topic started (PID $(cat "$pidfile")); logs → $logfile" \
                        || { echo "❌ Failed to start $topic; see $logfile"; rm -f "$pidfile"; }
}

stop_one() {
  local name="$1" pidfile="$2"
  if [[ ! -f "$pidfile" ]]; then echo "ℹ️  $name not running"; return; fi
  local pid="$(cat "$pidfile")"
  if ps -p "$pid" >/dev/null 2>&1; then
    echo "🛑 Stopping $name (PID $pid)"; kill -TERM "$pid" || true
    for _ in {1..5}; do sleep 1; ps -p "$pid" >/dev/null || { echo "✅ $name stopped"; rm -f "$pidfile"; return; }; done
    echo "⚠️  Forcing stop…"; kill -KILL "$pid" || true; rm -f "$pidfile"; echo "✅ $name killed"
  else
    echo "⚠️  Stale PID; cleaning"; rm -f "$pidfile"
  fi
}

status_one() {
  local label="$1" topic="$2" pidfile="$3" port="$4"
  local l="lambda_${topic}.txt" p="producers_${topic}.txt"
  if is_running "$pidfile"; then
    echo "✅ $label running (PID $(cat "$pidfile")) • port=$port • lambda=$(cat "$l" 2>/dev/null || echo '?') • producers=$(cat "$p" 2>/dev/null || echo '?')"
  else
    echo "❌ $label not running"
  fi
}

set_lambda() {
  local topic="$1" value="$2"
  if [[ ! "$value" =~ ^[0-9]+(\.[0-9]+)?$ ]]; then
    echo "❌ Lambda must be numeric"; exit 1
  fi
  echo "$value" > "lambda_${topic}.txt"
  echo "✅ lambda for $topic set to $value"
}

set_prods() {
  local topic="$1" count="$2"
  if [[ ! "$count" =~ ^[0-9]+$ ]]; then
    echo "❌ Producer count must be integer"; exit 1
  fi
  echo "$count" > "producers_${topic}.txt"
  echo "✅ producers for $topic set to $count"
}

show_logs() {
  local topic="$1" logfile
  case "$topic" in
    "$JSON_TOPIC") logfile="$JSON_LOG" ;;
    "$PARQ_TOPIC") logfile="$PARQ_LOG" ;;
    *) echo "❌ Unknown topic $topic"; exit 1 ;;
  esac
  tail -n 20 -f "$logfile"
}

print_help() {
  cat <<EOF
Manage confluent-kafka producers (one process per topic)

Usage:
  $0 start                        Start both producers
  $0 stop                         Stop both producers
  $0 status                       Show status of both producers
  $0 set-lambda <topic> <value>   Set Poisson lambda (float) for topic
  $0 set-prods  <topic> <count>   Set number of producer threads (int) for topic
  $0 logs       <topic>           Tail logs for topic
  $0 --help | -?                  Show this help

Topics:
  $JSON_TOPIC
  $PARQ_TOPIC
EOF
}

case "${1:-}" in
  start)
    start_one "$JSON_TOPIC" "$JSON_PORT" "$JSON_PID" "$JSON_LOG"
    start_one "$PARQ_TOPIC" "$PARQ_PORT" "$PARQ_PID" "$PARQ_LOG"
    ;;
  stop)
    stop_one "JSON Producer (ckafka)" "$JSON_PID"
    stop_one "Parquet Producer (ckafka)" "$PARQ_PID"
    ;;
  status)
    status_one "JSON Producer (ckafka)" "$JSON_TOPIC" "$JSON_PID" "$JSON_PORT"
    status_one "Parquet Producer (ckafka)" "$PARQ_TOPIC" "$PARQ_PID" "$PARQ_PORT"
    ;;
  set-lambda)
    [[ $# -eq 3 ]] || { echo "Usage: $0 set-lambda <topic> <value>"; exit 1; }
    set_lambda "$2" "$3"
    ;;
  set-prods)
    [[ $# -eq 3 ]] || { echo "Usage: $0 set-prods <topic> <count>"; exit 1; }
    set_prods "$2" "$3"
    ;;
  logs)
    [[ $# -eq 2 ]] || { echo "Usage: $0 logs <topic>"; exit 1; }
    show_logs "$2"
    ;;
  --help|-?)
    print_help
    ;;
  *)
    echo "Unknown command: ${1:-}"
    echo "Run '$0 --help' for usage."
    exit 1
    ;;
esac
