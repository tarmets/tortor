#!/bin/bash
set -e

mkdir -p "$TS_CONF_PATH" "$TS_TORR_DIR"
chown -R ts:ts "$TS_CONF_PATH" "$TS_TORR_DIR" 2>/dev/null || true

echo "Запуск TorrServer (порт $TS_PORT)"

exec /usr/bin/TorrServer \
     --path="$TS_CONF_PATH" \
     --torrentsdir="$TS_TORR_DIR" \
     --port="$TS_PORT" \
     ${TS_OPTIONS:-}
