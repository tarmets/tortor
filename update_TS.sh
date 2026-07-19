#!/bin/sh
sleep $((RANDOM % 40))
[ -e /TS/cron.env ] && set -a && . /TS/cron.env && set +a

ARCH_SED() { dpkg --print-architecture | sed 's/amd64/linux-64/g; s/arm64/linux-arm-64/g; s/armhf/linux-armhf-32/g'; }
ARCH_SED2() { dpkg --print-architecture | sed 's/armhf/arm7/g; s/i386/386/g'; }

rm -rf /TS/updates && mkdir -p /TS/updates

echo "$(date): ffprobe update..."
wget --no-check-certificate --user-agent="$USER_AGENT" -qO /tmp/ffprobe.zip --tries=3 \
  "$(curl -s $FFBINARIES | jq -r '.bin | .[].ffprobe' | grep linux | grep -iE "$(ARCH_SED)")"
unzip -o /tmp/ffprobe.zip ffprobe -d /usr/local/bin >/dev/null 2>&1 && chmod +x /usr/local/bin/*

if [ -n "$BIP_URL" ]; then
    echo "$(date): IP blacklist update..."
    cd /TS/updates
    EXT=$(basename $(wget --spider --no-check-certificate --user-agent="$USER_AGENT" "$BIP_URL" -O - 2>&1 | grep -oE 'https?://[^" ]+' | head -1) | grep -oE '[^.]+$')
    wget --no-check-certificate --user-agent="$USER_AGENT" -qO "bip_raw.$EXT" "$BIP_URL"
    (file -b --mime-type "bip_raw.$EXT" | grep -q text/plain && cat "bip_raw.$EXT" || gunzip -c "bip_raw.$EXT" 2>/dev/null) | \
      sed '/^#/d; s/[[:blank:]]//g' | grep -oE '([0-9]{1,3}\.){3}[0-9]{1,3}(-[0-9]{1,3}(\.[0-9]{1,3}){3})?' | \
      sed -r 's/\b0+([0-9])/\1/g' | grep -vE '^(0|22[4-9]|2[3-5]|192\.168)' | sort -t. -k1,1n -k2,2n -k3,3n -k4,4n -u > bip.txt
    rm -f "bip_raw.$EXT"
    if [ $(wc -l <bip.txt) -gt 0 ]; then
      cp -f bip.txt "$TS_CONF_PATH/bip.txt" && chmod a+r "$TS_CONF_PATH/bip.txt"
      pkill TorrServer 2>/dev/null; sleep 2
      cd "$TS_TORR_DIR" && /TS/TorrServer --path="$TS_CONF_PATH/" --torrentsdir="$TS_TORR_DIR" --port="$TS_PORT" $TS_OPTIONS &
    fi
fi

echo "$(date): TorrServer update..."
wget --no-check-certificate --user-agent="$USER_AGENT" -qO /TS/updates/TorrServer --tries=3 \
  "$(curl -s $TS_URL | grep -oE 'https?://[^" ]+' | grep -i "$(uname)" | grep -i "$(ARCH_SED2)")"
chmod +x /TS/updates/TorrServer

VER=$(/TS/updates/TorrServer --version 2>/dev/null)
CUR=$(/TS/TorrServer --version 2>/dev/null)
if [ -n "$VER" ] && [ "$VER" != "$CUR" ]; then
  echo "Update to $VER..."
  mkdir -p "$TS_CONF_PATH/backup" && cp -f /TS/TorrServer "$TS_CONF_PATH/backup/"
  cp -f /TS/updates/TorrServer /TS/TorrServer && chmod +x /TS/TorrServer
  pkill TorrServer 2>/dev/null; sleep 2
  /TS/TorrServer --path="$TS_CONF_PATH/" --torrentsdir="$TS_TORR_DIR" --port="$TS_PORT" $TS_OPTIONS &
fi
