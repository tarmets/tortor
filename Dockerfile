# syntax=docker/dockerfile:1.6
FROM ubuntu:24.04 AS builder

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
        ca-certificates wget curl jq unzip \
    && rm -rf /var/lib/apt/lists/*

# Создаём директории
RUN mkdir -p /TS

# TorrServer — последняя версия с YouROK/TorrServer
ARG TARGETARCH
ARG TARGETVARIANT

RUN case "${TARGETARCH}" in \
        amd64)  TS_ARCH=amd64   ;; \
        arm64)  TS_ARCH=arm64   ;; \
        arm/v7) TS_ARCH=arm7    ;; \
        *)      TS_ARCH=amd64   ;; \
    esac && \
    VERSION=$(curl -s https://api.github.com/repos/YouROK/TorrServer/releases/latest | jq -r .tag_name) && \
    wget -q "https://github.com/YouROK/TorrServer/releases/download/${VERSION}/TorrServer-linux-${TS_ARCH}" \
         -O /TS/TorrServer && chmod +x /TS/TorrServer

# ffprobe — с ffbinaries.com
RUN case "${TARGETARCH}" in \
        amd64)  FF_ARCH=64   ;; \
        arm64)  FF_ARCH=arm-64   ;; \
        arm/v7) FF_ARCH=armhf-32   ;; \
        *)      FF_ARCH=64   ;; \
    esac && \
    FF_URL=$(curl -s https://ffbinaries.com/api/v1/version/latest | jq -r ".bin[] | select(.ffprobe != null and contains(\"linux-${FF_ARCH}\")) | .ffprobe") && \
    wget -q "$FF_URL" -O /tmp/ffprobe.zip && \
    unzip -o /tmp/ffprobe.zip -d /usr/local/bin/ && \
    chmod +x /usr/local/bin/ffprobe && \
    rm /tmp/ffprobe.zip

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
