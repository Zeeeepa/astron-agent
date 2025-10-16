#!/usr/bin/env bash

#############################################################################
# Quick Fix: Disable Casdoor Authentication
#############################################################################
# This script disables Casdoor OAuth authentication for local development
# Usage: ./disable_casdoor.sh
#############################################################################

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║${NC}  ${GREEN}Disabling Casdoor Authentication${NC}"
echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${NC}"
echo ""

# Find the .env file
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
ENV_FILE="${SCRIPT_DIR}/docker/astronAgent/.env"

if [ ! -f "${ENV_FILE}" ]; then
    echo -e "${RED}✗${NC} .env file not found at: ${ENV_FILE}"
    echo -e "${CYAN}ℹ${NC} Please run ./setup.sh first"
    exit 1
fi

echo -e "${CYAN}ℹ${NC} Found .env file: ${ENV_FILE}"

# Backup existing .env
BACKUP_FILE="${ENV_FILE}.backup.$(date +%Y%m%d_%H%M%S)"
cp "${ENV_FILE}" "${BACKUP_FILE}"
echo -e "${GREEN}✓${NC} Backed up .env to: ${BACKUP_FILE}"

# Disable Casdoor by commenting out and adding empty values
echo -e "${CYAN}ℹ${NC} Disabling Casdoor configuration..."

# Comment out existing values and add empty ones
sed -i.bak \
    -e 's/^CONSOLE_CASDOOR_URL=.*/#&\nCONSOLE_CASDOOR_URL=/' \
    -e 's/^CONSOLE_CASDOOR_ID=.*/#&\nCONSOLE_CASDOOR_ID=/' \
    -e 's/^CONSOLE_CASDOOR_APP=.*/#&\nCONSOLE_CASDOOR_APP=/' \
    -e 's/^CONSOLE_CASDOOR_ORG=.*/#&\nCONSOLE_CASDOOR_ORG=/' \
    "${ENV_FILE}"

# Also disable OAuth2 settings that depend on Casdoor
sed -i \
    -e 's/^OAUTH2_ISSUER_URI=.*/#&\nOAUTH2_ISSUER_URI=/' \
    -e 's/^OAUTH2_JWK_SET_URI=.*/#&\nOAUTH2_JWK_SET_URI=/' \
    -e 's/^OAUTH2_AUDIENCE=.*/#&\nOAUTH2_AUDIENCE=/' \
    "${ENV_FILE}"

echo -e "${GREEN}✓${NC} Casdoor authentication disabled"
echo ""

# Show what was changed
echo -e "${CYAN}Configuration changes:${NC}"
echo "  CONSOLE_CASDOOR_URL     = (empty)"
echo "  CONSOLE_CASDOOR_ID      = (empty)"
echo "  CONSOLE_CASDOOR_APP     = (empty)"
echo "  CONSOLE_CASDOOR_ORG     = (empty)"
echo "  OAUTH2_ISSUER_URI       = (empty)"
echo "  OAUTH2_JWK_SET_URI      = (empty)"
echo "  OAUTH2_AUDIENCE         = (empty)"
echo ""

echo -e "${YELLOW}⚠${NC}  ${CYAN}Important: You must restart the services for changes to take effect${NC}"
echo ""
echo -e "${CYAN}Run these commands:${NC}"
echo -e "  ${YELLOW}cd $(dirname ${SCRIPT_DIR})/astron-agent${NC}"
echo -e "  ${YELLOW}./stop.sh${NC}"
echo -e "  ${YELLOW}./start.sh${NC}"
echo ""
echo -e "${GREEN}✓${NC} Then open: ${CYAN}http://localhost${NC}"
echo -e "${GREEN}✓${NC} Console will load without authentication!"
echo ""

