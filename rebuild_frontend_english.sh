#!/usr/bin/env bash

#############################################################################
# Rebuild Frontend with English Default
#############################################################################
# This script rebuilds the console frontend with English as default language
# Usage: ./rebuild_frontend_english.sh
#############################################################################

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║${NC}  ${GREEN}Rebuilding Frontend with English Default${NC}"
echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${NC}"
echo ""

# Find the repository root
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
REPO_ROOT="${SCRIPT_DIR}"
FRONTEND_DIR="${REPO_ROOT}/console/frontend"
DOCKER_DIR="${REPO_ROOT}/docker/astronAgent"

if [ ! -d "${FRONTEND_DIR}" ]; then
    echo -e "${RED}✗${NC} Frontend directory not found: ${FRONTEND_DIR}"
    exit 1
fi

echo -e "${CYAN}ℹ${NC} Frontend directory: ${FRONTEND_DIR}"
echo -e "${CYAN}ℹ${NC} Docker directory: ${DOCKER_DIR}"
echo ""

# Check if Docker is available
if ! command -v docker &> /dev/null; then
    echo -e "${RED}✗${NC} Docker is not installed"
    exit 1
fi

# Check if docker-compose/docker compose is available
if command -v docker-compose &> /dev/null; then
    COMPOSE_CMD="docker-compose"
elif docker compose version &> /dev/null 2>&1; then
    COMPOSE_CMD="docker compose"
else
    echo -e "${RED}✗${NC} Docker Compose is not available"
    exit 1
fi

echo -e "${GREEN}✓${NC} Docker found"
echo -e "${GREEN}✓${NC} Docker Compose: ${COMPOSE_CMD}"
echo ""

# Check if Node.js is available (needed for local build)
if ! command -v node &> /dev/null; then
    echo -e "${YELLOW}⚠${NC} Node.js is not installed"
    echo -e "${CYAN}ℹ${NC} Will use Docker build instead"
    USE_DOCKER_BUILD=true
else
    NODE_VERSION=$(node --version)
    echo -e "${GREEN}✓${NC} Node.js found: ${NODE_VERSION}"
    USE_DOCKER_BUILD=false
fi
echo ""

# Verify the i18n file was updated
echo -e "${CYAN}Verifying i18n configuration...${NC}"
if grep -q "fallbackLng: 'en'" "${FRONTEND_DIR}/src/locales/i18n/index.ts" && \
   grep -q "lng: getSavedLanguage() || 'en'" "${FRONTEND_DIR}/src/locales/i18n/index.ts"; then
    echo -e "${GREEN}✓${NC} i18n configured for English default"
else
    echo -e "${RED}✗${NC} i18n not properly configured"
    echo -e "${CYAN}ℹ${NC} Attempting to fix..."
    
    sed -i.bak "s/fallbackLng: 'zh'/fallbackLng: 'en'/" "${FRONTEND_DIR}/src/locales/i18n/index.ts"
    sed -i.bak "s/lng: getSavedLanguage() || 'zh'/lng: getSavedLanguage() || 'en'/" "${FRONTEND_DIR}/src/locales/i18n/index.ts"
    
    echo -e "${GREEN}✓${NC} i18n configuration updated"
fi
echo ""

# Build the frontend
if [ "$USE_DOCKER_BUILD" = true ]; then
    echo -e "${CYAN}Building frontend with Docker...${NC}"
    echo -e "${YELLOW}⚠${NC} This may take 10-15 minutes"
    echo ""
    
    # Build using docker-compose
    cd "${DOCKER_DIR}"
    
    # Build only the frontend image
    ${COMPOSE_CMD} build console-frontend
    
    echo -e "${GREEN}✓${NC} Frontend image built successfully"
else
    echo -e "${CYAN}Building frontend locally...${NC}"
    echo -e "${YELLOW}⚠${NC} This may take 5-10 minutes"
    echo ""
    
    cd "${FRONTEND_DIR}"
    
    # Install dependencies if needed
    if [ ! -d "node_modules" ]; then
        echo -e "${CYAN}Installing dependencies...${NC}"
        if command -v pnpm &> /dev/null; then
            pnpm install
        elif command -v yarn &> /dev/null; then
            yarn install
        else
            npm install
        fi
    fi
    
    # Build the frontend
    echo -e "${CYAN}Building production bundle...${NC}"
    if command -v pnpm &> /dev/null; then
        pnpm build
    elif command -v yarn &> /dev/null; then
        yarn build
    else
        npm run build
    fi
    
    echo -e "${GREEN}✓${NC} Frontend built successfully"
    
    # Now rebuild the Docker image with the new build
    cd "${DOCKER_DIR}"
    ${COMPOSE_CMD} build console-frontend
fi

echo ""
echo -e "${GREEN}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}  ✓ Frontend Rebuilt with English Default!${NC}"
echo -e "${GREEN}═══════════════════════════════════════════════════════════════${NC}"
echo ""

echo -e "${CYAN}Next steps:${NC}"
echo "  1. Stop current services: ${YELLOW}./stop.sh${NC}"
echo "  2. Start with new frontend: ${YELLOW}./start.sh${NC}"
echo "  3. Clear browser cache: ${YELLOW}Ctrl+Shift+R${NC} or ${YELLOW}Cmd+Shift+R${NC}"
echo "  4. Open: ${YELLOW}http://localhost${NC}"
echo ""
echo -e "${GREEN}✓${NC} Console will now default to English!"
echo ""

echo -e "${YELLOW}⚠${NC}  ${CYAN}Note:${NC} If you've previously visited the console,"
echo -e "    clear your browser's localStorage to reset language:"
echo -e "    ${YELLOW}F12 → Console → localStorage.clear()${NC}"
echo ""

