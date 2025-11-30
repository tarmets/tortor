#!/bin/bash
set -e

ARCH=$(dpkg --print-architecture)
case "$ARCH" in
    amd64)   TS_ARCH="amd64" ;;
    arm64)   TS_ARCH="arm64" ;;
    armhf)   TS_ARCH="arm7" ;;
    i386)    TS_ARCH="386" ;;
    *)       echo "Неизвестная архитектура: $ARCH"; exit 1 ;;
esac

echo "Проверка обновлений TorrServer ($TS_ARCH)..."

VERSION=$(curl -s https://api.github.com/repos/YouROK/TorrServer/releases/latest | jq -r .tag_name)
URL="https://github.com/YouROK/TorrServer/releases/download/${VERSION}/TorrServer-linux-${TS_ARCH}"

[ -z "$VERSION" ] && { echo "Не найдена версия релиза"; exit 1; }

TEMP="/tmp/TorrServer.new"
wget -q "$URL" -O "$TEMP"
chmod +x "$TEMP"

NEW_VER=$("$TEMP" --version 2>/dev/null || echo "unknown")
CUR_VER=$(/usr/bin/TorrServer --version 2>/dev/null || echo "unknown")

if [ "$NEW_VER" != "$CUR_VER" ]; then
    echo "Обновление: $CUR_VER → $NEW_VER"
    mkdir -p "$TS_CONF_PATH/backup"
    cp /usr/bin/TorrServer "$TS_CONF_PATH/backup/TorrServer-old-$(date +%Y%m%d-%H%M)" 2>/dev/null || true
    mv "$TEMP" /usr/bin/TorrServer
    pkill TorrServer || true
    sleep 3
    /start.sh &
    echo "Обновление завершено"
else
    echo "Уже последняя версия: $CUR_VER"
    rm -f "$TEMP"
fi
