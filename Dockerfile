FROM ubuntu:latest
LABEL maintainer="tarmets/tortor"

ENV TS_URL=https://releases.yourok.ru/torr/server_release.json \
    TS_RELEASE=latest TS_PORT=8090 \
    TS_UPDATE=true LINUX_UPDATE=true \
    TS_CONF_PATH=/TS/db TS_TORR_DIR=/TS/db/torrents \
    GIT_URL=https://api.github.com/repos/YouROK/TorrServer/releases \
    FFBINARIES=https://ffbinaries.com/api/v1/version/latest \
    USER_AGENT="Mozilla/5.0 (X11; Linux x86_64; rv:77.0) Gecko/20100101 Firefox/77.0" \
    GODEBUG=madvdontneed=1

COPY start_TS.sh update_TS.sh /

RUN chmod a+x /start_TS.sh /update_TS.sh && \
    apt-get update && apt-get upgrade -y && \
    apt-get install --no-install-recommends -y ca-certificates tzdata wget curl procps cron file jq unzip && \
    apt-get clean && mkdir /TS && chmod -R 666 /TS && \
    mkdir -p "$TS_CONF_PATH" && chmod -R 666 "$TS_CONF_PATH" && \
    wget --no-check-certificate --user-agent="$USER_AGENT" -qO /TS/TorrServer --tries=3 \
    "$(curl -s $TS_URL | grep -oE 'https?://[^\" ]+' | grep -i "$(uname)" | \
    grep -i "$(dpkg --print-architecture | sed 's/armhf/arm7/g; s/i386/386/g')")" && \
    chmod +x /TS/TorrServer && \
    wget --no-check-certificate --user-agent="$USER_AGENT" -qO /tmp/ffprobe.zip --tries=3 \
    "$(curl -s $FFBINARIES | jq -r '.bin | .[].ffprobe' | grep linux | \
    grep -iE "$(dpkg --print-architecture | sed 's/amd64/linux-64/g; s/arm64/linux-arm-64/g; s/armhf/linux-armhf-32/g')")" && \
    unzip -o /tmp/ffprobe.zip ffprobe -d /usr/local/bin && \
    chmod +x /usr/local/bin/* && touch /var/log/cron.log && \
    ln -sf /proc/1/fd/1 /var/log/cron.log

HEALTHCHECK --interval=5s --timeout=10s --retries=3 CMD curl -sS http://127.0.0.1:8090/ || exit 1
VOLUME ["/TS/db"]
EXPOSE 8090
ENTRYPOINT ["/start_TS.sh"]
