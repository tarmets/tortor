#!/bin/sh
set -e

# Check if TorrServer is running
if pgrep TorrServer >/dev/null; then
    echo "TorrServer is running. Stopping..."
    pkill TorrServer
    sleep 5  # Wait for shutdown
fi

# Get latest version
VERSION=$(curl -s https://api.github.com/repos/YouROK/TorrServer/releases/latest | jq -r .tag_name)

# Download and update TorrServer (auto-detect architecture)
case "$(uname -m)" in
    x86_64) TS_ARCH="amd64";;
    aarch64) TS_ARCH="arm64";;
    armv7l) TS_ARCH="arm7";;
    *) echo "Unsupported architecture"; exit 1;;
esac

wget -q "https://github.com/YouROK/TorrServer/releases/download/${VERSION}/TorrServer-linux-${TS_ARCH}" -O /usr/bin/TorrServer
chmod +x /usr/bin/TorrServer

echo "Update completed. Restart TorrServer manually."
