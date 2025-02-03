#!/bin/sh

# Sleep a random number of seconds before executing a task (1 - 40 sec.)
sleep $((RANDOM % 40 + 1))

# Load environment variables if available
if [ -e /TS/cron.env ]; then
    set -a
    . /TS/cron.env
    set +a
fi

# Clean and prepare update directory
rm -rf /TS/updates && mkdir -p /TS/updates

# Check for ffprobe updates
echo "\n=================================================="
echo "$(date): Checking for ffprobe updates ..."

FFPROBE_URL=$(curl -s "$FFBINARIES" | jq -r '.bin[].ffprobe' | grep linux |
    grep -Ei "$(dpkg --print-architecture | sed -E "s/amd64/linux-64/;s/arm64/linux-arm-64/;s/armhf/linux-armhf-32/")")

if [ -n "$FFPROBE_URL" ]; then
    wget --no-verbose --no-check-certificate --user-agent="$USER_AGENT" \
         --output-document=/tmp/ffprobe.zip --tries=3 "$FFPROBE_URL"

    if [ $? -eq 0 ]; then
        unzip -o /tmp/ffprobe.zip ffprobe -d /usr/local/bin && chmod +x /usr/local/bin/ffprobe
        echo "\n$(ffprobe -version)"
    else
        echo "Error: Unable to download ffprobe."
    fi
else
    echo "Error: Unable to fetch ffprobe URL."
fi

echo "Finished checking for ffprobe updates."
echo "==================================================\n"

# Check for blacklist IP updates
if [ -n "$BIP_URL" ]; then
    echo "\n=================================================="
    echo "$(date): Checking for blacklist IP updates ..."

    cd /TS/updates || exit

    EXT=$(wget --spider --no-check-certificate --user-agent="$USER_AGENT" \
         --content-disposition "$BIP_URL" -O - 2>&1 | grep -Eo 'http[^ ]+' | awk -F. '{print $NF}')

    wget --no-check-certificate --user-agent="$USER_AGENT" --content-disposition "$BIP_URL" -O bip_raw.$EXT

    if [ $? -eq 0 ]; then
        file -b --mime-type bip_raw.$EXT | grep -q 'text/plain' && cat bip_raw.$EXT || gunzip -c bip_raw.$EXT |
            grep -Ev '^#' | tr -d '[:blank:]' |
            grep -Eo '([0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}(-[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3})?)' |
            sort -u > bip.txt

        rm -f bip_raw.$EXT
        bip_size=$(wc -l < bip.txt)

        if [ "$bip_size" -gt 0 ]; then
            mv bip.txt "$TS_CONF_PATH/bip.txt" && chmod a+r "$TS_CONF_PATH/bip.txt"
            echo "Updated bip.txt ($bip_size entries). Restarting TorrServer..."
            pkill TorrServer
            /TS/TorrServer --path="$TS_CONF_PATH/" --torrentsdir="$TS_TORR_DIR" --port="$TS_PORT" $TS_OPTIONS &
        else
            echo "Error: No valid IPs found in blacklist."
        fi
    else
        echo "Error: Unable to download blacklist IP file."
    fi

    echo "Finished checking for blacklist IP updates."
    echo "==================================================\n"
fi

# Check for TorrServer updates
echo "\n=================================================="
echo "$(date): Checking for TorrServer updates ..."

TORRSERVER_URL=$(curl -s "$TS_URL" | grep -Eo 'http[^ ]+' |
    grep -i "$(uname)" | grep -i "$(dpkg --print-architecture | sed -E 's/armhf/arm7/;s/i386/386/')")

if [ -n "$TORRSERVER_URL" ]; then
    wget --no-check-certificate --no-verbose --user-agent="$USER_AGENT" \
         --output-document=/TS/updates/TorrServer --tries=3 "$TORRSERVER_URL"

    if [ $? -eq 0 ]; then
        chmod a+x /TS/updates/TorrServer
        updated_ver=$(/TS/updates/TorrServer --version 2>/dev/null)
        current_ver=$(/TS/TorrServer --version 2>/dev/null)

        if [ -n "$updated_ver" ] && [ "$updated_ver" != "$current_ver" ]; then
            echo "Updating TorrServer to $updated_ver ..."
            mkdir -p "$TS_CONF_PATH/backup" && rm -f "$TS_CONF_PATH/backup/TorrServer"
            cp -f /TS/TorrServer "$TS_CONF_PATH/backup/"
            mv /TS/updates/TorrServer /TS/TorrServer
            chmod a+x /TS/TorrServer
            /TS/TorrServer --path="$TS_CONF_PATH/" --torrentsdir="$TS_TORR_DIR" --port="$TS_PORT" $TS_OPTIONS &
            sleep 5

            if ! pgrep TorrServer > /dev/null; then
                echo "Error: Update failed. Restoring backup."
                cp -f "$TS_CONF_PATH/backup/TorrServer" /TS/TorrServer
                chmod a+x /TS/TorrServer
                /TS/TorrServer --path="$TS_CONF_PATH/" --torrentsdir="$TS_TORR_DIR" --port="$TS_PORT" $TS_OPTIONS &
            fi
        else
            echo "TorrServer is up to date ($current_ver)."
        fi
    else
        echo "Error: Unable to download TorrServer."
    fi
else
    echo "Error: Unable to fetch TorrServer URL."
fi

echo "Finished checking for updates."
echo "==================================================\n"
