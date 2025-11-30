# syntax=docker/dockerfile:1.6
FROM ubuntu:24.04 AS builder

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
        ca-certificates wget curl jq unzip xz-utils \
    && rm -rf /var/lib/apt/lists/*

# Создаём директории
RUN mkdir -p /TS

# TorrServer — последняя версия с официального репозитория
ARG TARGETARCH
ARG TARGETVARIANT

RUN arch=$(echo "${TARGETARCH}" | sed 's/amd64/x86_64/;s/arm64/aarch64/;s/arm/v7l/' | \
           sed 's/386/386/;s//unknown/') && \
    case "$arch" in \
        x86_64|aarch64|armv7l|386) \
            wget -q "https://github.com/torrserver/server/releases/latest/download/TorrServer-linux-${arch}" \
                 -O /TS/TorrServer && chmod +x /TS/TorrServer ;; \
        *) echo "Unsupported arch: $TARGETARCH" && exit 1 ;; \
    esac

# ffprobe — статическая сборка от johnvansickle (всегда живой)
RUN case "${TARGETARCH}" in \
        amd64)  JV_ARCH=amd64   ;; \
        arm64)  JV_ARCH=arm64   ;; \
        arm/v7) JV_ARCH=armhf   ;; \
        *)      JV_ARCH=amd64   ;; \
    esac && \
    wget -q "https://johnvansickle.com/ffmpeg/releases/ffmpeg-release-${JV_ARCH}-static.tar.xz" && \
    tar xf ffmpeg-release-${JV_ARCH}-static.tar.xz && \
    cp ffmpeg-*-static/ffprobe /usr/local/bin/ffprobe && \
    chmod +x /usr/local/bin/ffprobe && \
    rm -rf ffmpeg-*

# Финальный минимальный образ
FROM ubuntu:24.04

RUN apt-get update && apt-get install -y --no-install-recommends ca-certificates curl jq && \
    rm -rf /var/lib/apt/lists/* && \
    groupadd -r ts && useradd -r -g ts ts

COPY --from=builder /TS/TorrServer /usr/bin/TorrServer
COPY --from=builder /usr/local/bin/ffprobe /usr/local/bin/ffprobe
COPY start.sh /start.sh
COPY update.sh /update.sh

RUN chmod +x /start.sh /update.sh

ENV TS_PORT=8090 \
    TS_CONF_PATH=/config \
    TS_TORR_DIR=/torrents \
    GODEBUG=madvdontneed=1

VOLUME ["/config", "/torrents"]
EXPOSE ${TS_PORT}

HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
    CMD curl -fs http://127.0.0.1:${TS_PORT}/ping || exit 1

ENTRYPOINT ["/start.sh"]
