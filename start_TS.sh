#!/bin/sh
[ ! -d "$TS_TORR_DIR" ] && mkdir -p "$TS_TORR_DIR" && chmod 777 "$TS_TORR_DIR"
ln -sf "$TS_TORR_DIR" /torrents
rm -f "$TS_TORR_DIR/torrents"

GH="https://raw.githubusercontent.com/tarmets/tortor/main"

download() { [ -e "$2" ] || wget -q --no-check-certificate --user-agent="$USER_AGENT" -O "$2" "$1"; }
download "$GH/ts.ini" "$TS_CONF_PATH/ts.ini"
download "$GH/accs.db" "$TS_CONF_PATH/accs.db"
download "$GH/config.db" "$TS_CONF_PATH/config.db"

[ -e "$TS_CONF_PATH/ts.ini" ] && sed -i 's/\r//' "$TS_CONF_PATH/ts.ini" && . "$TS_CONF_PATH/ts.ini"

rm -f /TS/cron.env

$LINUX_UPDATE 2>/dev/null && apt-get update && apt-get upgrade -y && apt-get clean

/TS/TorrServer --path="$TS_CONF_PATH/" --torrentsdir="$TS_TORR_DIR" --port="$TS_PORT" $TS_OPTIONS &
sleep 5

if ! pgrep TorrServer >/dev/null 2>&1; then
    /TS/TorrServer --path="$TS_CONF_PATH/" --torrentsdir="$TS_TORR_DIR" --port="$TS_PORT" &
    sleep 3
    if ! pgrep TorrServer >/dev/null 2>&1 && [ -e "$TS_CONF_PATH/backup/TorrServer" ]; then
        cp -f "$TS_CONF_PATH/backup/TorrServer" /TS/TorrServer
        chmod +x /TS/TorrServer
        /TS/TorrServer --path="$TS_CONF_PATH/" --torrentsdir="$TS_TORR_DIR" --port="$TS_PORT" &
        sleep 5
        pgrep TorrServer >/dev/null 2>&1 || echo "Fatal!"
    fi
fi

[ "$TS_RELEASE" != "latest" ] && curl -sI "$GIT_URL/tags/$TS_RELEASE" | grep -q "200 OK" && export TS_URL="$GIT_URL/tags/$TS_RELEASE"

env | grep -v cron_task | awk 'NF{sub("=","=\"",$0);print $0"\""}' >/TS/cron.env
$TS_UPDATE && . /update_TS.sh

[ -n "$cron_task" ] && echo "$cron_task /update_TS.sh >>/var/log/cron.log 2>&1" | crontab - && cron -f &

tail -f /dev/null
