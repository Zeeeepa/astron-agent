#!/bin/bash

# ============================================================================
# COMPLETE ASTRON SETUP SCRIPT
# One-command setup for astron-agent + astron-rpa unified deployment
# ============================================================================

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

# Configuration
REPO_URL="https://github.com/Zeeeepa/astron-agent.git"
BRANCH="codegen-bot/unified-deployment-1759128224"
INSTALL_DIR="$HOME/astron-agent"

echo -e "${PURPLE}"
echo "============================================================================"
echo "                    🚀 ASTRON UNIFIED PLATFORM SETUP 🚀"
echo "                   Complete Installation & Configuration"
echo "============================================================================"
echo -e "${NC}"

# ============================================================================
# STEP 1: CLONE REPOSITORY
# ============================================================================

echo -e "${BLUE}📥 Step 1: Cloning repository...${NC}"

if [ -d "$INSTALL_DIR" ]; then
    echo -e "  📁 Directory exists, updating..."
    cd "$INSTALL_DIR"
    git fetch origin
    git checkout "$BRANCH"
    git pull origin "$BRANCH"
else
    echo -e "  📥 Cloning repository..."
    git clone "$REPO_URL" "$INSTALL_DIR"
    cd "$INSTALL_DIR"
    git checkout "$BRANCH"
fi

echo -e "${GREEN}  ✅ Repository ready${NC}"

# ============================================================================
# STEP 2: MAKE SCRIPTS EXECUTABLE
# ============================================================================

echo -e "${BLUE}🔧 Step 2: Setting up scripts...${NC}"

chmod +x *.sh scripts/*.sh 2>/dev/null || true

echo -e "${GREEN}  ✅ Scripts configured${NC}"

# ============================================================================
# STEP 3: DEPLOY SERVICES
# ============================================================================

echo -e "${BLUE}🚀 Step 3: Deploying services...${NC}"

if [ -f "quick-setup.sh" ]; then
    echo -e "  🚀 Running quick setup..."
    echo "y" | ./quick-setup.sh || {
        echo -e "${YELLOW}  ⚠️ Quick setup had issues, trying manual deployment...${NC}"
        ./deploy.sh --skip-deps || {
            echo -e "${YELLOW}  ⚠️ Automated deployment had issues, setting up manually...${NC}"
            docker compose -f docker-compose.unified.yml --env-file .env.unified up -d
        }
    }
else
    echo -e "${RED}  ❌ Quick setup script not found${NC}"
    exit 1
fi

echo -e "${GREEN}  ✅ Services deployed${NC}"

# ============================================================================
# STEP 4: SETUP BASHRC ALIASES
# ============================================================================

echo -e "${BLUE}📝 Step 4: Setting up shell aliases...${NC}"

# Check if aliases already exist
if ! grep -q "# Astron Platform Aliases" ~/.bashrc 2>/dev/null; then
    echo -e "  📝 Adding aliases to ~/.bashrc..."
    
    cat >> ~/.bashrc << 'BASHRC_EOF'

# ============================================================================
# Astron Platform Aliases
# ============================================================================

# Navigation
alias astron='cd ~/astron-agent'

# Service Management
alias start='cd ~/astron-agent && docker compose -f docker-compose.unified.yml --env-file .env.unified up -d && echo "🚀 Services started! Access: http://localhost/rpa/ | http://localhost/agent/"'
alias stop='cd ~/astron-agent && docker compose -f docker-compose.unified.yml --env-file .env.unified down && echo "⏹️ Services stopped"'
alias restart='cd ~/astron-agent && docker compose -f docker-compose.unified.yml --env-file .env.unified restart && echo "🔄 Services restarted"'
alias status='cd ~/astron-agent && ./scripts/health-check.sh 2>/dev/null || docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" | grep -E "(astron|rpa|agent|unified)"'
alias logs='cd ~/astron-agent && docker compose -f docker-compose.unified.yml --env-file .env.unified logs -f --tail=50'

# Quick Access
alias rpa='echo "🤖 RPA Platform: http://localhost/rpa/" && (command -v xdg-open >/dev/null && xdg-open http://localhost/rpa/ 2>/dev/null || true)'
alias agent='echo "🧠 Agent Console: http://localhost/agent/" && (command -v xdg-open >/dev/null && xdg-open http://localhost/agent/ 2>/dev/null || true)'
alias auth='echo "🔐 Authentication: http://localhost/auth/" && (command -v xdg-open >/dev/null && xdg-open http://localhost/auth/ 2>/dev/null || true)'
alias minio='echo "💾 MinIO Console: http://localhost/minio/" && (command -v xdg-open >/dev/null && xdg-open http://localhost/minio/ 2>/dev/null || true)'

# Health Checks
alias health='curl -s http://localhost/health >/dev/null && echo "✅ System healthy" || echo "❌ System not responding"'
alias ports='echo "🌐 Service Ports:"; echo "  Main Access: http://localhost (port 80)"; echo "  RPA API: http://localhost:8020"; echo "  Agent Core: http://localhost:17870"; echo "  Agent Console: http://localhost:8080"; echo "  RPA Frontend: http://localhost:32742"; echo "  Agent Frontend: http://localhost:1881"'

# Service Groups
alias start-infra='cd ~/astron-agent && ./scripts/manage-services.sh start infra'
alias start-rpa='cd ~/astron-agent && ./scripts/manage-services.sh start rpa'
alias start-agent='cd ~/astron-agent && ./scripts/manage-services.sh start agent'

# Maintenance
alias backup='cd ~/astron-agent && ./scripts/manage-services.sh backup'
alias cleanup='cd ~/astron-agent && ./scripts/manage-services.sh cleanup'
alias update='cd ~/astron-agent && ./scripts/manage-services.sh update'

# Show status on shell startup
astron_startup_check() {
    if command -v docker &> /dev/null && docker info &> /dev/null 2>&1; then
        local running=$(docker ps --filter "name=astron" --filter "name=unified" --filter "name=rpa" --filter "name=agent" -q | wc -l)
        if [ "$running" -gt 0 ]; then
            echo -e "\n🟢 Astron Platform: $running services running"
            echo "   🌐 Access: http://localhost/rpa/ | http://localhost/agent/"
        else
            echo -e "\n🔴 Astron Platform: Services not running"
            echo "   ▶️  Type 'start' to start all services"
        fi
        echo -e "   💡 Commands: start | stop | status | logs | rpa | agent | ports\n"
    fi
}

# Run startup check (only in interactive shells)
if [[ $- == *i* ]]; then
    astron_startup_check
fi

BASHRC_EOF

    echo -e "${GREEN}  ✅ Aliases added to ~/.bashrc${NC}"
else
    echo -e "${GREEN}  ✅ Aliases already configured${NC}"
fi

# ============================================================================
# STEP 5: WAIT FOR SERVICES AND VERIFY
# ============================================================================

echo -e "${BLUE}⏳ Step 5: Waiting for services to start...${NC}"

sleep 30

# Check if services are responding
echo -e "  🔍 Checking service health..."

# Test main endpoints
if curl -s http://localhost/health >/dev/null 2>&1; then
    echo -e "${GREEN}  ✅ Main proxy responding${NC}"
else
    echo -e "${YELLOW}  ⚠️ Main proxy not yet ready${NC}"
fi

if curl -s http://localhost:8020/health >/dev/null 2>&1; then
    echo -e "${GREEN}  ✅ RPA API responding${NC}"
else
    echo -e "${YELLOW}  ⚠️ RPA API not yet ready${NC}"
fi

if curl -s http://localhost:17870/health >/dev/null 2>&1; then
    echo -e "${GREEN}  ✅ Agent Core responding${NC}"
else
    echo -e "${YELLOW}  ⚠️ Agent Core not yet ready${NC}"
fi

# ============================================================================
# COMPLETION MESSAGE
# ============================================================================

echo -e "${GREEN}"
echo "============================================================================"
echo "                    🎉 SETUP COMPLETE! 🎉"
echo "============================================================================"
echo -e "${NC}"

echo -e "${CYAN}🌐 Access Your Platforms:${NC}"
echo -e "   🤖 RPA Platform:      ${GREEN}http://localhost/rpa/${NC}"
echo -e "   🧠 Agent Console:     ${GREEN}http://localhost/agent/${NC}"
echo -e "   🔐 Authentication:    ${GREEN}http://localhost/auth/${NC}"
echo -e "   💾 MinIO Console:     ${GREEN}http://localhost/minio/${NC}"
echo -e "   📊 Health Check:      ${GREEN}http://localhost/health${NC}"

echo ""
echo -e "${CYAN}💡 Quick Commands (available after 'source ~/.bashrc'):${NC}"
echo -e "   ${GREEN}start${NC}    - Start all services"
echo -e "   ${GREEN}stop${NC}     - Stop all services"
echo -e "   ${GREEN}status${NC}   - Check system health"
echo -e "   ${GREEN}logs${NC}     - View service logs"
echo -e "   ${GREEN}rpa${NC}      - Open RPA platform"
echo -e "   ${GREEN}agent${NC}    - Open Agent console"
echo -e "   ${GREEN}ports${NC}    - Show all service ports"
echo -e "   ${GREEN}health${NC}   - Quick health check"

echo ""
echo -e "${CYAN}🔧 Management Commands:${NC}"
echo -e "   ${GREEN}astron${NC}           - Navigate to astron directory"
echo -e "   ${GREEN}backup${NC}           - Create system backup"
echo -e "   ${GREEN}cleanup${NC}          - Clean up Docker resources"
echo -e "   ${GREEN}update${NC}           - Update all services"

echo ""
echo -e "${CYAN}📚 Documentation:${NC}"
echo -e "   ${GREEN}~/astron-agent/README-deployment.md${NC}     - Complete guide"
echo -e "   ${GREEN}~/astron-agent/QUICK-START-COMMANDS.md${NC}  - Command reference"
echo -e "   ${GREEN}~/astron-agent/DEPLOYMENT-SUMMARY.md${NC}    - Architecture overview"

echo ""
echo -e "${YELLOW}⚠️ Next Steps:${NC}"
echo -e "   1. Run: ${GREEN}source ~/.bashrc${NC} to activate aliases"
echo -e "   2. Test: ${GREEN}health${NC} to verify system status"
echo -e "   3. Access: ${GREEN}rpa${NC} or ${GREEN}agent${NC} to open platforms"
echo -e "   4. If services aren't ready, wait a few minutes and run: ${GREEN}status${NC}"

echo ""
echo -e "${PURPLE}🎊 Welcome to the Astron Unified Platform! 🎊${NC}"
echo -e "${PURPLE}The future of AI agents with RPA capabilities! 🚀${NC}"

# Source bashrc if running interactively
if [[ $- == *i* ]]; then
    source ~/.bashrc
fi

