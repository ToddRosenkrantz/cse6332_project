#!/bin/bash
# Create 'spark-output' bucket in MinIO
# Supports both mc_minio (renamed to avoid Midnight Commander conflict) and mc

# Determine which mc client to use
if command -v mc_minio &>/dev/null; then
    MC_CMD="mc_minio"
elif command -v mc &>/dev/null; then
    # Check if 'mc' is MinIO Client and not Midnight Commander
    if mc --help 2>&1 | grep -q 'mc [GLOBAL FLAGS]'; then
        MC_CMD="mc"
    else
        echo "'mc' found, but it appears to be Midnight Commander, not MinIO Client."
        echo "Please install and rename MinIO Client to 'mc_minio'."
        exit 1
    fi
else
    echo "Neither mc_minio nor valid mc (MinIO Client) found in PATH."
    echo "Please install MinIO Client from https://min.io/download"
    exit 1
fi

# Set alias and create bucket
$MC_CMD alias set local http://localhost:9000 minioadmin minioadmin

# Create bucket (ignore error if it already exists)
$MC_CMD mb local/spark-output || echo "Bucket 'spark-output' already exists or failed to create."
