#!/bin/sh
set -e

# Signal handling for graceful shutdown
trap 'kill -TERM $PID' TERM INT

# Start TorrServer in background
/usr/bin/TorrServer \
    -conf_path "${TS_CONF_PATH}" \
    -torr_dir "${TS_TORR_DIR}" \
    -port "${TS_PORT}" &
PID=$!

# Wait for termination
wait $PID
trap - TERM INT
wait $PID 2>/dev/null
