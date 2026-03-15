#!/usr/bin/env bash
# onetimesecret.sh — Secure credential handoff via OneTimeSecret.com
#
# Creates a one-time secret link, displays it for the user to fill in,
# and optionally waits to retrieve the secret (piping to a command or file).
# The secret is NEVER displayed to the agent.
#
# Usage:
#   onetimesecret.sh [--wait TIMEOUT_SECONDS] [--passphrase PASSPHRASE]
#                    [--ttl SECONDS] [--pipe CMD] [--file PATH] [--quiet]
#
# Examples:
#   # Create link only (agent shows URL to user)
#   onetimesecret.sh
#
#   # Create link, wait up to 2 minutes, pipe to CDP injection script
#   onetimesecret.sh --wait 120 --pipe "node inject-password.js"
#
#   # Create link, wait, save to temp file
#   onetimesecret.sh --wait 60 --file /tmp/secret.txt
#
#   # With passphrase protection
#   onetimesecret.sh --wait 120 --passphrase "enter code: 4291" --file /tmp/secret.txt

set -euo pipefail

# Defaults
WAIT_TIMEOUT=""
PASSPHRASE=""
TTL=600
PIPE_CMD=""
OUTPUT_FILE=""
QUIET=false
OTS_API="https://onetimesecret.com/api/v1"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m' # No Color

usage() {
    cat <<'EOF'
Usage: onetimesecret.sh [OPTIONS]

Create a one-time secret link for secure credential handoff.

Options:
  --wait SECONDS       Wait up to SECONDS for the secret (mandatory timeout)
  --passphrase TEXT    Require passphrase to view secret
  --ttl SECONDS        Time-to-live in seconds (default: 600)
  --pipe CMD           Pipe retrieved secret to command (implies --wait)
  --file PATH          Save secret to file (implies --wait)
  --quiet              Only output the secret URL (for scripting)
  --help               Show this help

The secret is NEVER displayed to stdout when --wait is used.
Output goes only to the specified --pipe command or --file.

Examples:
  onetimesecret.sh
  onetimesecret.sh --wait 120 --pipe "python3 inject.py"
  onetimesecret.sh --wait 60 --file /tmp/secret.txt
  onetimesecret.sh --wait 120 --passphrase "code: 4291" --pipe "cat > /tmp/key"
EOF
    exit 0
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        --wait)
            WAIT_TIMEOUT="$2"
            shift 2
            ;;
        --passphrase)
            PASSPHRASE="$2"
            shift 2
            ;;
        --ttl)
            TTL="$2"
            shift 2
            ;;
        --pipe)
            PIPE_CMD="$2"
            WAIT_TIMEOUT="${WAIT_TIMEOUT:-120}"  # Default 2 min if not set
            shift 2
            ;;
        --file)
            OUTPUT_FILE="$2"
            WAIT_TIMEOUT="${WAIT_TIMEOUT:-120}"  # Default 2 min if not set
            shift 2
            ;;
        --quiet)
            QUIET=true
            shift
            ;;
        --help|-h)
            usage
            ;;
        *)
            echo "Unknown option: $1" >&2
            usage
            ;;
    esac
done

# Validate: --wait is mandatory when piping or saving
if [[ -n "$PIPE_CMD" || -n "$OUTPUT_FILE" ]] && [[ -z "$WAIT_TIMEOUT" ]]; then
    echo -e "${RED}Error: --wait TIMEOUT_SECONDS is mandatory when using --pipe or --file${NC}" >&2
    exit 1
fi

# Step 1: Create a placeholder secret
create_secret() {
    local post_data="secret=%5BWaiting+for+user+input%5D&ttl=${TTL}"
    
    if [[ -n "$PASSPHRASE" ]]; then
        post_data="${post_data}&passphrase=$(python3 -c "import urllib.parse; print(urllib.parse.quote('$PASSPHRASE'))")"
    fi
    
    local response
    response=$(curl -sf -X POST "${OTS_API}/share" -d "$post_data" 2>/dev/null) || {
        echo -e "${RED}Error: Failed to create secret (network error or OTS unavailable)${NC}" >&2
        exit 1
    }
    
    echo "$response"
}

# Parse JSON field (avoids jq dependency)
json_field() {
    local json="$1"
    local field="$2"
    echo "$json" | python3 -c "import json,sys; d=json.loads(sys.stdin.read()); print(d.get('$field',''))"
}

# Step 2: Poll for the secret
poll_secret() {
    local metadata_key="$1"
    local timeout="$2"
    local poll_interval=2
    local elapsed=0
    
    while [[ $elapsed -lt $timeout ]]; do
        local response
        response=$(curl -sf "${OTS_API}/private/${metadata_key}" 2>/dev/null) || true
        
        if [[ -n "$response" ]]; then
            local state
            state=$(json_field "$response" "state")
            
            if [[ "$state" == "received" ]]; then
                local secret
                secret=$(json_field "$response" "value")
                if [[ -n "$secret" ]]; then
                    echo "$secret"
                    return 0
                fi
            elif [[ "$state" == "burned" ]]; then
                echo -e "${RED}Error: Secret was burned (viewed by someone else?)${NC}" >&2
                return 1
            fi
        fi
        
        sleep $poll_interval
        elapsed=$((elapsed + poll_interval))
    done
    
    echo -e "${RED}Error: Timeout after ${timeout}s waiting for secret${NC}" >&2
    return 1
}

# Main
main() {
    # Create the secret
    local result
    result=$(create_secret)
    
    local secret_key metadata_key
    secret_key=$(json_field "$result" "secret_key")
    metadata_key=$(json_field "$result" "metadata_key")
    
    if [[ -z "$secret_key" ]]; then
        echo -e "${RED}Error: Failed to create secret${NC}" >&2
        exit 1
    fi
    
    local secret_url="https://onetimesecret.com/secret/${secret_key}"
    
    # Output for user/agent
    if [[ "$QUIET" == true ]]; then
        echo "$secret_url"
    else
        echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}" >&2
        echo -e "${BOLD}🔒 OneTimeSecret — Secure Credential Handoff${NC}" >&2
        echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}" >&2
        echo "" >&2
        echo -e "${GREEN}Please visit this URL and enter your secret:${NC}" >&2
        echo -e "${BOLD}${YELLOW}${secret_url}${NC}" >&2
        echo "" >&2
        if [[ -n "$PASSPHRASE" ]]; then
            echo -e "${YELLOW}⚠️  Passphrase required: ${PASSPHRASE}${NC}" >&2
            echo "" >&2
        fi
        echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}" >&2
    fi
    
    # If waiting, poll for the secret
    if [[ -n "$WAIT_TIMEOUT" ]]; then
        if [[ "$QUIET" != true ]]; then
            echo "" >&2
            echo -e "${YELLOW}⏳ Waiting for secret (timeout: ${WAIT_TIMEOUT}s)...${NC}" >&2
        fi
        
        local secret
        secret=$(poll_secret "$metadata_key" "$WAIT_TIMEOUT") || exit 1
        
        # Secret is NEVER printed to stdout for the agent to see
        # Instead, pipe to command or write to file
        if [[ -n "$PIPE_CMD" ]]; then
            echo "$secret" | eval "$PIPE_CMD"
            if [[ "$QUIET" != true ]]; then
                echo -e "${GREEN}✅ Secret piped to: ${PIPE_CMD}${NC}" >&2
            fi
        elif [[ -n "$OUTPUT_FILE" ]]; then
            echo -n "$secret" > "$OUTPUT_FILE"
            chmod 600 "$OUTPUT_FILE"
            if [[ "$QUIET" != true ]]; then
                echo -e "${GREEN}✅ Secret saved to: ${OUTPUT_FILE}${NC}" >&2
            fi
        else
            # No pipe/file: write to a secure temp file and report path
            local tmpfile
            tmpfile=$(mktemp /tmp/ots-secret-XXXXXX)
            chmod 600 "$tmpfile"
            echo -n "$secret" > "$tmpfile"
            echo -e "${GREEN}✅ Secret saved to: ${tmpfile}${NC}" >&2
            echo -e "${YELLOW}   (use --pipe or --file to control destination)${NC}" >&2
        fi
    else
        if [[ "$QUIET" != true ]]; then
            echo "" >&2
            echo -e "${YELLOW}ℹ️  Run with --wait SECONDS to retrieve the secret automatically${NC}" >&2
        fi
    fi
}

main
