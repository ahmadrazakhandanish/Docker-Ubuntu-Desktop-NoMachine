#!/bin/bash

# ============================================================
#  Tailscale + NoMachine Setup Script
#  Repo: https://github.com/kmille36/Docker-Ubuntu-Desktop-NoMachine
#  Uses Tailscale VPN instead of ngrok — faster & more stable
# ============================================================

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

function print_banner() {
    clear
    echo -e "${CYAN}"
    echo "======================================"
    echo "   Tailscale + NoMachine Setup"
    echo "======================================"
    echo -e "${NC}"
}

function install_tailscale() {
    echo -e "${YELLOW}[*] Installing Tailscale...${NC}"
    curl -fsSL https://tailscale.com/install.sh | sh
    if ! command -v tailscale &>/dev/null; then
        echo -e "${RED}[!] Tailscale install failed!${NC}"
        exit 1
    fi
    echo -e "${GREEN}[+] Tailscale installed: $(tailscale version)${NC}"
}

function start_tailscale() {
    echo -e "${YELLOW}[*] Starting Tailscale daemon...${NC}"

    # Start tailscaled in background if not running
    if ! pgrep -x tailscaled > /dev/null; then
        sudo tailscaled --tun=userspace-networking --socks5-server=localhost:1055 \
            > /tmp/tailscaled.log 2>&1 &
        sleep 2
    fi
}

function login_tailscale() {
    print_banner
    echo -e "${CYAN} Go to: https://login.tailscale.com/admin/machines${NC}"
    echo ""
    echo -e "${YELLOW}[*] Authenticating Tailscale...${NC}"
    echo -e " You will get a URL below — open it in your browser to authenticate."
    echo ""

    # Use --authkey if provided as argument, else interactive login
    if [ -n "$1" ]; then
        sudo tailscale up --authkey="$1" --accept-routes --hostname="nomachine-server"
    else
        sudo tailscale up --accept-routes --hostname="nomachine-server"
    fi

    sleep 2

    # Get Tailscale IP
    TS_IP=$(tailscale ip -4 2>/dev/null)

    if [ -z "$TS_IP" ]; then
        echo -e "${RED}[!] Could not get Tailscale IP. Authentication may have failed.${NC}"
        echo -e " Check: https://login.tailscale.com/admin/machines"
        exit 1
    fi

    echo -e "${GREEN}[+] Tailscale connected! Your IP: ${TS_IP}${NC}"
}

function start_nomachine() {
    echo -e "${YELLOW}[*] Starting NoMachine Docker container...${NC}"

    # Stop existing container if running
    docker stop nomachine-xfce4 2>/dev/null
    docker rm nomachine-xfce4 2>/dev/null

    docker run --rm -d \
        --network host \
        --privileged \
        --name nomachine-xfce4 \
        -e PASSWORD=123456 \
        -e USER=user \
        --cap-add=SYS_PTRACE \
        --shm-size=1g \
        thuonghai2711/nomachine-ubuntu-desktop:windows10

    if [ $? -eq 0 ]; then
        echo -e "${GREEN}[+] NoMachine container started!${NC}"
    else
        echo -e "${RED}[!] Docker failed to start. Is Docker installed and running?${NC}"
        exit 1
    fi
}

function show_connection_info() {
    TS_IP=$(tailscale ip -4 2>/dev/null)

    clear
    echo -e "${CYAN}"
    echo "======================================"
    echo "   NoMachine Connection Info"
    echo "======================================"
    echo -e "${NC}"
    echo -e " Download NoMachine : ${CYAN}https://www.nomachine.com/download${NC}"
    echo -e " Tailscale Dashboard: ${CYAN}https://login.tailscale.com/admin/machines${NC}"
    echo ""
    echo -e "${GREEN} IP Address : ${TS_IP}${NC}"
    echo -e "${GREEN} Port       : 4000${NC}"
    echo -e "${GREEN} User       : user${NC}"
    echo -e "${GREEN} Password   : 123456${NC}"
    echo ""
    echo -e "${YELLOW} NOTE: Both your PC and this server must be on the same Tailscale account!${NC}"
    echo -e " Install Tailscale on your PC: ${CYAN}https://tailscale.com/download${NC}"
    echo ""
    echo "======================================"
    echo -e "${YELLOW}[!] Can't connect? Restart Cloud Shell and re-run the script.${NC}"
    echo "======================================"
}

function keepalive() {
    SECONDS_LEFT=43200
    echo -e "${CYAN}[*] Session will run for 12 hours...${NC}"
    while [ $SECONDS_LEFT -gt 0 ]; do
        HOURS=$(( SECONDS_LEFT / 3600 ))
        MINS=$(( (SECONDS_LEFT % 3600) / 60 ))
        SECS=$(( SECONDS_LEFT % 60 ))
        printf "\r ${GREEN}Running...${NC} %02d:%02d:%02d remaining   " "$HOURS" "$MINS" "$SECS"
        sleep 1
        (( SECONDS_LEFT-- ))
    done
    echo ""
    echo -e "${YELLOW}[*] Session ended.${NC}"
}

# ============================================================
# MAIN
# ============================================================
print_banner

# 1. Install Tailscale if not present
if ! command -v tailscale &>/dev/null; then
    install_tailscale
else
    echo -e "${GREEN}[+] Tailscale already installed: $(tailscale version)${NC}"
fi

# 2. Ask for optional Auth Key (for non-interactive / headless login)
echo ""
echo -e " You can use a ${CYAN}Tailscale Auth Key${NC} for headless login (optional)."
echo -e " Get one at: ${CYAN}https://login.tailscale.com/admin/settings/keys${NC}"
echo -e " (Press Enter to use interactive browser login instead)"
echo ""
read -p " Paste Tailscale Auth Key (or press Enter to skip): " TS_AUTHKEY

# 3. Start daemon
start_tailscale

# 4. Login
login_tailscale "$TS_AUTHKEY"

# 5. Start NoMachine
start_nomachine

# 6. Show info
show_connection_info

# 7. Keep session alive
keepalive
