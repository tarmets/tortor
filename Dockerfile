# syntax=docker/dockerfile:1.6
ARG BASE_UBUNTU_VERSION=24.04

# Builder stage for downloading binaries
FROM ubuntu:${BASE_UBUNTU_VERSION}-slim AS builder

ENV DEBIAN_FRONTEND=noninteractive
ARG TARGETARCH

# Install dependencies
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        ca-certificates \
        wget \
        curl \
        jq \
        unzip && \
    rm -rf /var/lib/apt/lists/*

# Create working directory
RUN mkdir -p /TS

# Install TorrServer (auto-detect architecture)
RUN set -eux; \
    case "${TARGETARCH}" in \
        amd64) TS_ARCH="amd64";; \
        arm64) TS_ARCH="arm64";; \
        arm/v7) TS_ARCH="arm7";; \
        *) echo "Unsupported architecture: ${TARGETARCH}"; exit 1;; \
    esac; \
    VERSION=$(curl -s https://api.github.com/repos/YouROK/TorrServer/releases/latest | jq -r .tag_name); \
    wget -q "https://github.com/YouROK/TorrServer/releases/download/${VERSION}/TorrServer-linux-${TS_ARCH}" -O /TS/TorrServer && \
    chmod +x /TS/TorrServer

# Install ffprobe (from BtbN/FFmpeg-Builds)
RUN set -eux; \
    case "${TARGETARCH}" in \
        amd64) FF_ARCH="linux64";; \
        arm64) FF_ARCH="linuxarm64";; \
        *) echo "Unsupported FFmpeg architecture"; exit 1;; \
    esac; \
    wget -q "https://github.com/BtbN/FFmpeg-Builds/releases/latest/download/ffmpeg-n5.1-latest-linux${FF_ARCH}-gpl-shared.tar.xz" -O /tmp/ffmpeg.tar.xz && \
    tar -xf /tmp/ffmpeg.tar.xz --strip-components=1 -C /usr/local/bin/ --wildcards '*/ffprobe' && \
    chmod +x /usr/local/bin/ffprobe && \
    rm /tmp/ffmpeg.tar.xz

# Final stage (minimal runtime)
FROM ubuntu:${BASE_UBUNTU_VERSION}-slim

# Create non-root user
RUN groupadd -r ts && useradd -r -g ts ts

# Copy binaries from builder
COPY --from=builder --chown=ts:ts /TS/TorrServer /usr/bin/TorrServer
COPY --from=builder --chown=ts:ts /usr/local/bin/ffprobe /usr/local/bin/ffprobe

# Copy scripts
COPY --chown=ts:ts start.sh /start.sh
COPY --chown=ts:ts update.sh /update.sh

# Set permissions
RUN chmod +x /start.sh /update.sh /usr/bin/TorrServer /usr/local/bin/ffprobe

# Environment variables
ENV TS_PORT=8090 \
    TS_CONF_PATH=/config \
    TS_TORR_DIR=/torrents \
    GODEBUG=madvdontneed=1 \
    HOME=/home/ts

# Volumes and port
VOLUME ["/config", "/torrents"]
EXPOSE ${TS_PORT}

# Healthcheck (using wget instead of curl)
HEALTHCHECK --interval=30s --timeout=10s --start-period=10s --retries=3 \
    CMD wget --spider -q "http://127.0.0.1:${TS_PORT}/ping" || exit 1

# Run as non-root user
USER ts
ENTRYPOINT ["/start.sh"]
