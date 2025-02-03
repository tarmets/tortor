#!/bin/sh

# Sleep a random number of seconds between 1 and 40 before executing a task.
sleep $((RANDOM % 40))

# Load environment variables from cron.env if it exists.
if [ -e /TS/cron.env ]; then
    set -a
    . /TS/cron.env
    set +a
fi

# Ensure the /TS/updates directory exists and clean up old updates.
if [ ! -d /TS/updates ]; then
    mkdir -p /TS/updates
else
    rm -rf /TS/updates/*
    mkdir -p /TS/updates
fi

# Start checking for ffprobe updates.
echo ""
echo "=================================================="
echo "$(date): Start checking for ffprobe updates ..."

# Download the latest ffprobe binary.
ffprobe_url=$(curl -s "$FFBINARIES" | jq -r '.bin | .[].ffprobe' | grep linux | 
               grep -i -E "$(dpkg --print-architecture | sed 's/amd64/linux-64/g' | 
                            sed 's/arm64/linux-arm-64/g' | 
                            sed -E 's/armhf/linux-armhf-32/g')")

if [ -n "$ffprobe_url" ]; then
    wget --no-verbose --no-check-certificate --user-agent="$USER_AGENT" --output-document=/tmp/ffprobe.zip --tries=3 "$ffprobe_url"

    # Unzip and install the new ffprobe binary.
    unzip -o /tmp/ffprobe.zip -d /usr/local/bin/
    chmod -R +x /usr/local/bin/ffprobe
else
    echo "No valid ffprobe URL found."
fi

echo ""
echo "Finished checking for ffprobe updates."
echo "=================================================="
echo ""

# Start checking for blacklist IP updates.
if [ ! -z "$BIP_URL" ]; then
    echo ""
    echo "=================================================="
    echo "$(date): Start checking for blacklist IP updates ..."

    # Download and process the blacklist IP list.
    wget -nv --no-check-certificate --user-agent="$USER_AGENT" --content-disposition "$BIP_URL" --output-document=bip_raw
    EXT="${bip_raw##*.}"

    file_type=$(file -b --mime-type "bip_raw")
    if [ "$file_type" = "application/gzip" ]; then
        gunzip -c "bip_raw" > "bip_processed"
    else
        cat "bip_raw" > "bip_processed"
    fi

    # Process the IP list.
    awk '!/^#/ && NF { gsub(/[a-zA-Z]/,""); gsub(/-/, "\n"); print }' "bip_processed" | 
    awk '{ gsub(/[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+[a-zA-Z]/,""); print }' |
    awk '{ gsub(/0+([0-9]+)/, "\\1"); print }' |
    egrep -o '([0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}-[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}|[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3})' |
    sort -t . -k 1,1n -k 2,2n -k 3,3n -k 4,4n -u > bip.txt

    rm -f "bip_raw"
    bip_size=$(wc -l < "bip.txt")

    if [ "$bip_size" -gt 0 ]; then
        cp -f "bip.txt" "$TS_CONF_PATH/bip.txt"
        chmod a+r "$TS_CONF_PATH/bip.txt"
        echo "New bip.txt size: $bip_size lines. Restarting TorrServer..."
        pkill TorrServer
        cd "$TS_TORR_DIR"
        /TS/TorrServer --path="$TS_CONF_PATH/" --torrentsdir="$TS_TORR_DIR" --port="$TS_PORT" "$TS_OPTIONS" &
    else
        echo "Error updating blacklist IP from URL - $BIP_URL"
    fi

    echo "Finished checking for blacklist IP updates."
    echo "=================================================="
    echo ""
fi

# Start checking for TorrServer updates.
echo ""
echo "=================================================="
echo "$(date): Start checking for TorrServer updates ..."

# Download the latest TorrServer binary.
torrserver_url=$(curl -s "$TS_URL" | egrep -o 'http.+\w+' | 
                 grep -i "$(uname)" | 
                 grep -i "$(dpkg --print-architecture | tr -s armhf arm7 | tr -s i386 386)")

if [ -n "$torrserver_url" ]; then
    wget --no-check-certificate --no-verbose --user-agent="$USER_AGENT" --output-document=/TS/updates/TorrServer --tries=3 "$torrserver_url"

    # Install the new TorrServer binary.
    chmod a+x "/TS/updates/TorrServer"
    updated_ver=$(/TS/updates/TorrServer --version)

    if [ $? -eq 0 ] && [ -n "$updated_ver" ]; then
        current_ver=$(/TS/TorrServer --version)

        if [ "$updated_ver" != "$current_ver" ]; then
            echo "Updating to $updated_ver ..."

            if [ ! -d "$TS_CONF_PATH/backup" ]; then
                mkdir -p "$TS_CONF_PATH/backup"
            else
                [ -e "$TS_CONF_PATH/backup/TorrServer" ] && rm -f "$TS_CONF_PATH/backup/TorrServer"
            fi

            pkill TorrServer
            cp -f "/TS/TorrServer" "$TS_CONF_PATH/backup/"
            cp -f "/TS/updates/TorrServer" "/TS/TorrServer"
            chmod a+x "/TS/TorrServer"

            /TS/TorrServer --path="$TS_CONF_PATH/" --torrentsdir="$TS_TORR_DIR" --port="$TS_PORT" "$TS_OPTIONS" &

            sleep 5

            if [ "$(ps aux | grep TorrServer | wc -w)" -le 1 ]; then
                echo "Error during the update process: downloaded file is corrupted. Restoring backup."
                rm -f "/TS/TorrServer"
                cp -f "$TS_CONF_PATH/backup/TorrServer" "/TS/TorrServer"
                chmod a+x "/TS/TorrServer"
                /TS/TorrServer --path="$TS_CONF_PATH/" --torrentsdir="$TS_TORR_DIR" --port="$TS_PORT" "$TS_OPTIONS" &
            fi
        else
            echo "Version $current_ver is the latest. No update needed."
        fi
    else
        echo "Error during the update process: no internet access or the downloaded file is corrupted."
    fi
else
    echo "No valid TorrServer URL found."
fi

echo "Finished checking for updates."
echo "=================================================="
echo ""
