#!/bin/bash

# ============================================================
#  Ngrok + NoMachine Setup Script (Updated for Ngrok v3)
#  Repo: https://github.com/kmille36/Docker-Ubuntu-Desktop-NoMachine
# ============================================================

function install_ngrok() {
    echo "[*] Downloading latest official ngrok v3..."
    curl -sSL https://ngrok-agent.s3.amazonaws.com/ngrok.asc \
        | sudo tee /etc/apt/trusted.gpg.d/ngrok.asc >/dev/null
    echo "deb https://ngrok-agent.s3.amazonaws.com buster main" \
        | sudo tee /etc/apt/sources.list.d/ngrok.list >/dev/null
    sudo apt-get update -qq && sudo apt-get install -y ngrok

    # Fallback: direct binary download if apt fails
    if ! command -v ngrok &>/dev/null; then
        echo "[*] Falling back to direct binary download..."
        curl -sSLo /tmp/ngrok.tgz \
            "https://bin.equinox.io/c/bNyj1mQVY4c/ngrok-v3-stable-linux-amd64.tgz"
        tar -xzf /tmp/ngrok.tgz -C /usr/local/bin
        chmod +x /usr/local/bin/ngrok
    fi

    echo "[+] ngrok version: $(ngrok version)"
}

function goto() {
    label=$1
    cd
    cmd=$(sed -n "/^:[[:blank:]][[:blank:]]*${label}/{:a;n;p;ba};" "$0" |
          grep -v ':$')
    eval "$cmd"
    exit
}

: setup
clear

# Install ngrok if not present
if ! command -v ngrok &>/dev/null; then
    install_ngrok
fi

echo "=============================="
echo " Ngrok + NoMachine Setup v3"
echo "=============================="
echo ""
echo " Go to: https://dashboard.ngrok.com/get-started/your-authtoken"
echo ""
read -p " Paste Ngrok Authtoken: " NGROK_TOKEN

# Save authtoken (ngrok v3 syntax)
ngrok config add-authtoken "$NGROK_TOKEN"

: region
clear
echo "=============================="
echo " Choose Ngrok Region"
echo "=============================="
echo " 1) us  - United States"
echo " 2) eu  - Europe"
echo " 3) ap  - Asia/Pacific"
echo " 4) au  - Australia"
echo " 5) sa  - South America"
echo " 6) jp  - Japan"
echo " 7) in  - India"
echo ""
read -p " Enter region code (us/eu/ap/au/sa/jp/in): " NGROK_REGION

# Kill any existing ngrok
pkill -f "ngrok tcp" 2>/dev/null
sleep 1

# Start ngrok v3 TCP tunnel (--region is removed, use --url or leave default)
# In ngrok v3, region is configured via config or env var
export NGROK_REGION="$NGROK_REGION"

# ngrok v3: use 'ngrok tcp <port>' — region set via NGROK_REGION env or config
ngrok tcp 4000 \
    --log=stdout \
    --log-level=warn \
    --region="$NGROK_REGION" \
    > /tmp/ngrok.log 2>&1 &

NGROK_PID=$!
echo "[*] Starting ngrok tunnel (PID: $NGROK_PID)..."
sleep 3

# Verify tunnel is up
if curl --silent --max-time 5 http://127.0.0.1:4040/api/tunnels | grep -q "public_url"; then
    echo "[+] Ngrok tunnel is UP!"
else
    echo "[!] Ngrok Error! Checking log..."
    cat /tmp/ngrok.log
    echo ""
    read -p "Press Enter to retry..." _
    goto region
fi

# Start NoMachine Docker container
echo "[*] Starting NoMachine Docker container..."
docker run --rm -d \
    --network host \
    --privileged \
    --name nomachine-xfce4 \
    -e PASSWORD=123456 \
    -e USER=user \
    --cap-add=SYS_PTRACE \
    --shm-size=1g \
    thuonghai2711/nomachine-ubuntu-desktop:windows10

clear
echo "=============================="
echo " NoMachine Connection Info"
echo "=============================="
echo " Download NoMachine: https://www.nomachine.com/download"
echo ""

# Extract public IP:PORT from ngrok API
NGROK_ADDR=$(curl --silent http://127.0.0.1:4040/api/tunnels \
    | sed -nE 's/.*"public_url":"tcp:\/\/([^"]*).*/\1/p')

echo " IP:Port  : $NGROK_ADDR"
echo " User     : user"
echo " Password : 123456"
echo ""
echo "[!] Can't connect? Restart Cloud Shell and re-run the script."
echo "=============================="

# Keep session alive for 12 hours
echo "[*] Session will run for 12 hours..."
SECONDS_LEFT=43200
while [ $SECONDS_LEFT -gt 0 ]; do
    MINS=$(( SECONDS_LEFT / 60 ))
    SECS=$(( SECONDS_LEFT % 60 ))
    printf "\r Running... %02d:%02d remaining   " "$MINS" "$SECS"
    sleep 1
    (( SECONDS_LEFT-- ))
done
echo ""
echo "[*] Session ended."
