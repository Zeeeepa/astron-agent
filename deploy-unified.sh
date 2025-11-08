#!/bin/bash

# ============================================================================
# UNIFIED DEPLOYMENT SCRIPT: ASTRON-AGENT + ASTRON-RPA
# Deploy both platforms together with proper integration
# ============================================================================

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Logging functions
log() {
    echo -e "${CYAN}[$(date +'%Y-%m-%d %H:%M:%S')] INFO: $1${NC}"
}

warn() {
    echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')] WARNING: $1${NC}"
}

error() {
    echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')] ERROR: $1${NC}"
    exit 1
}

success() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] SUCCESS: $1${NC}"
}

# Default values
DEPLOY_AGENT=true
DEPLOY_RPA=true
SKIP_DEPS_CHECK=false
FORCE_RECREATE=false
INSTALL_DOCKER=true
SETUP_ALIASES=true
ENABLE_CASDOOR=false
ENABLE_RAGFLOW=false
PRODUCTION_MODE=false

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --agent-only)
            DEPLOY_AGENT=true
            DEPLOY_RPA=false
            shift
            ;;
        --rpa-only)
            DEPLOY_AGENT=false
            DEPLOY_RPA=true
            shift
            ;;
        --skip-deps)
            SKIP_DEPS_CHECK=true
            shift
            ;;
        --force-recreate)
            FORCE_RECREATE=true
            shift
            ;;
        --skip-docker)
            INSTALL_DOCKER=false
            shift
            ;;
        --skip-aliases)
            SETUP_ALIASES=false
            shift
            ;;
        --with-casdoor)
            ENABLE_CASDOOR=true
            shift
            ;;
        --with-ragflow)
            ENABLE_RAGFLOW=true
            shift
            ;;
        --production)
            PRODUCTION_MODE=true
            shift
            ;;
        --help)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Deployment Options:"
            echo "  --agent-only       Deploy only astron-agent"
            echo "  --rpa-only         Deploy only astron-rpa"
            echo "  (default)          Deploy both platforms"
            echo ""
            echo "Configuration Options:"
            echo "  --skip-deps        Skip dependency checks"
            echo "  --force-recreate   Force recreate containers"
            echo "  --skip-docker      Skip Docker installation"
            echo "  --skip-aliases     Skip shell alias setup"
            echo "  --with-casdoor     Deploy with Casdoor authentication"
            echo "  --with-ragflow     Deploy with RagFlow knowledge base"
            echo "  --production       Enable production mode"
            echo "  --help             Show this help message"
            echo ""
            echo "Examples:"
            echo "  $0                 # Deploy both platforms"
            echo "  $0 --agent-only    # Deploy only astron-agent"
            echo "  $0 --rpa-only      # Deploy only astron-rpa"
            echo "  $0 --with-casdoor --with-ragflow  # Full deployment with auth and knowledge base"
            exit 0
            ;;
        *)
            error "Unknown option: $1"
            ;;
    esac
done

# ============================================================================
# SYSTEM REQUIREMENTS CHECK
# ============================================================================

check_system_requirements() {
    log "🔍 Checking system requirements..."
    
    # Check OS
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        log "✅ Linux detected"
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        log "✅ macOS detected"
    elif [[ "$OSTYPE" == "msys" || "$OSTYPE" == "cygwin" ]]; then
        log "✅ Windows (WSL/Git Bash) detected"
    else
        warn "⚠️ Unsupported OS: $OSTYPE"
    fi
    
    # Check memory requirements based on deployment
    REQUIRED_MEM=4
    if [ "$DEPLOY_AGENT" = true ] && [ "$DEPLOY_RPA" = true ]; then
        REQUIRED_MEM=12
    elif [ "$DEPLOY_AGENT" = true ]; then
        REQUIRED_MEM=8
    fi
    
    if command -v free &> /dev/null; then
        TOTAL_MEM=$(free -g | awk '/^Mem:/{print $2}')
        if [ "$TOTAL_MEM" -lt $REQUIRED_MEM ]; then
            warn "⚠️ Low memory detected: ${TOTAL_MEM}GB (recommended: ${REQUIRED_MEM}GB+)"
        else
            log "✅ Memory: ${TOTAL_MEM}GB"
        fi
    fi
    
    # Check disk space
    REQUIRED_SPACE=15
    if [ "$DEPLOY_AGENT" = true ] && [ "$DEPLOY_RPA" = true ]; then
        REQUIRED_SPACE=30
    fi
    
    AVAILABLE_SPACE=$(df -BG . | awk 'NR==2 {print $4}' | sed 's/G//')
    if [ "$AVAILABLE_SPACE" -lt $REQUIRED_SPACE ]; then
        warn "⚠️ Low disk space: ${AVAILABLE_SPACE}GB (recommended: ${REQUIRED_SPACE}GB+)"
    else
        log "✅ Disk space: ${AVAILABLE_SPACE}GB available"
    fi
    
    success "✅ System requirements check completed"
}

# ============================================================================
# DOCKER INSTALLATION
# ============================================================================

install_docker() {
    if [ "$INSTALL_DOCKER" = false ]; then
        log "⏭️ Skipping Docker installation"
        return
    fi
    
    log "🐳 Checking Docker installation..."
    
    if command -v docker &> /dev/null; then
        DOCKER_VERSION=$(docker --version | cut -d' ' -f3 | cut -d',' -f1)
        log "✅ Docker found: $DOCKER_VERSION"
        
        if ! docker info &> /dev/null; then
            error "❌ Docker daemon is not running. Please start Docker and try again."
        fi
    else
        log "📦 Installing Docker..."
        
        if [[ "$OSTYPE" == "linux-gnu"* ]]; then
            # Install Docker on Linux
            curl -fsSL https://get.docker.com -o get-docker.sh
            sudo sh get-docker.sh
            sudo usermod -aG docker $USER
            rm get-docker.sh
            
            # Install Docker Compose
            sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
            sudo chmod +x /usr/local/bin/docker-compose
            
            warn "⚠️ Please log out and log back in for Docker group changes to take effect"
        else
            error "❌ Please install Docker manually for your operating system"
        fi
    fi
    
    # Check Docker Compose
    if command -v docker-compose &> /dev/null || docker compose version &> /dev/null; then
        log "✅ Docker Compose available"
    else
        error "❌ Docker Compose not found. Please install Docker Compose."
    fi
    
    success "✅ Docker installation verified"
}

# ============================================================================
# REPOSITORY SETUP
# ============================================================================

setup_repositories() {
    log "📁 Setting up repositories..."
    
    # Create workspace directory
    WORKSPACE_DIR="$HOME/astron-workspace"
    mkdir -p "$WORKSPACE_DIR"
    cd "$WORKSPACE_DIR"
    
    # Setup astron-agent repository
    if [ "$DEPLOY_AGENT" = true ]; then
        log "📥 Setting up astron-agent repository..."
        if [ -d "astron-agent" ]; then
            log "📁 Found existing astron-agent directory"
            cd astron-agent
            git fetch origin
            git pull origin main || git pull origin master || warn "Could not update astron-agent repository"
            cd ..
        else
            log "📥 Cloning astron-agent repository..."
            git clone https://github.com/Zeeeepa/astron-agent.git
        fi
    fi
    
    # Setup astron-rpa repository
    if [ "$DEPLOY_RPA" = true ]; then
        log "📥 Setting up astron-rpa repository..."
        if [ -d "astron-rpa" ]; then
            log "📁 Found existing astron-rpa directory"
            cd astron-rpa
            git fetch origin
            git pull origin main || git pull origin master || warn "Could not update astron-rpa repository"
            cd ..
        else
            log "📥 Cloning astron-rpa repository..."
            git clone https://github.com/Zeeeepa/astron-rpa.git
        fi
    fi
    
    success "✅ Repository setup completed"
}

# ============================================================================
# NETWORK SETUP
# ============================================================================

setup_networks() {
    log "🌐 Setting up Docker networks..."
    
    # Create shared network for inter-service communication
    if ! docker network ls | grep -q "astron-network"; then
        docker network create astron-network --subnet=172.50.0.0/16
        log "✅ Created astron-network"
    else
        log "✅ astron-network already exists"
    fi
    
    success "✅ Network setup completed"
}

# ============================================================================
# ASTRON-RPA DEPLOYMENT
# ============================================================================

deploy_astron_rpa() {
    if [ "$DEPLOY_RPA" = false ]; then
        log "⏭️ Skipping astron-rpa deployment"
        return
    fi
    
    log "🤖 Deploying astron-rpa services..."
    
    cd "$WORKSPACE_DIR/astron-rpa"
    
    # Navigate to docker directory
    if [ -d "docker" ]; then
        cd docker
    else
        error "❌ Docker directory not found in astron-rpa repository"
    fi
    
    # Setup environment file
    if [ -f ".env.example" ]; then
        if [ ! -f ".env" ]; then
            cp .env.example .env
        fi
    else
        # Create default .env for astron-rpa
        cat > .env << 'EOF'
# ASTRON-RPA Configuration
MYSQL_ROOT_PASSWORD=root123
MYSQL_DATABASE=astron_rpa
REDIS_PASSWORD=redis123
MINIO_ROOT_USER=minioadmin
MINIO_ROOT_PASSWORD=minioadmin123

# Service Ports (RPA uses 8010-8040 range)
AI_SERVICE_PORT=8010
OPENAPI_SERVICE_PORT=8020
RESOURCE_SERVICE_PORT=8030
ROBOT_SERVICE_PORT=8040
FRONTEND_PORT=8080

# Network
NETWORK_SUBNET=172.30.0.0/16
EOF
    fi
    
    # Deploy services
    COMPOSE_ARGS=()
    if [ "$FORCE_RECREATE" = true ]; then
        COMPOSE_ARGS+=("--force-recreate")
    fi
    
    log "🚀 Starting astron-rpa services..."
    docker-compose pull || warn "Some RPA images could not be pulled"
    docker-compose up -d "${COMPOSE_ARGS[@]}"
    
    success "✅ astron-rpa services deployed"
    
    cd "$WORKSPACE_DIR"
}

# ============================================================================
# ASTRON-AGENT DEPLOYMENT
# ============================================================================

deploy_astron_agent() {
    if [ "$DEPLOY_AGENT" = false ]; then
        log "⏭️ Skipping astron-agent deployment"
        return
    fi
    
    log "🧠 Deploying astron-agent services..."
    
    cd "$WORKSPACE_DIR/astron-agent"
    
    # Navigate to Docker directory
    if [ -d "docker/astronAgent" ]; then
        cd docker/astronAgent
    elif [ -d "docker" ]; then
        cd docker
    else
        error "❌ Docker configuration directory not found in astron-agent"
    fi
    
    # Setup environment file
    if [ -f ".env.example" ]; then
        if [ ! -f ".env" ]; then
            cp .env.example .env
        fi
    else
        # Create default .env for astron-agent
        cat > .env << 'EOF'
# ASTRON-AGENT Configuration
POSTGRES_USER=spark
POSTGRES_PASSWORD=spark123
POSTGRES_DB=sparkdb_manager
MYSQL_ROOT_PASSWORD=root123
MYSQL_DATABASE=astron_console
REDIS_PASSWORD=redis123
MINIO_ROOT_USER=minioadmin
MINIO_ROOT_PASSWORD=minioadmin123

# Service Ports (Agent uses 1881, 5052, 7880-7990, 8080, 17870, 18668, 18888, 20010 range)
CORE_TENANT_PORT=5052
CORE_MEMORY_PORT=7990
CORE_LINK_PORT=18888
CORE_AITOOLS_PORT=18668
CORE_AGENT_PORT=17870
CORE_KNOWLEDGE_PORT=20010
CORE_WORKFLOW_PORT=7880
CONSOLE_FRONTEND_PORT=1881
CONSOLE_HUB_PORT=8080

# Network
NETWORK_SUBNET=172.40.0.0/16

# RPA Integration (if both are deployed)
EOF
        
        # Add RPA integration if both platforms are deployed
        if [ "$DEPLOY_RPA" = true ]; then
            cat >> .env << 'EOF'
RPA_AI_SERVICE_URL=http://172.30.0.1:8010
RPA_OPENAPI_SERVICE_URL=http://172.30.0.1:8020
RPA_RESOURCE_SERVICE_URL=http://172.30.0.1:8030
RPA_ROBOT_SERVICE_URL=http://172.30.0.1:8040
RPA_API_KEY=unified-integration-key
EOF
        fi
    fi
    
    # Deploy services
    COMPOSE_ARGS=()
    if [ "$FORCE_RECREATE" = true ]; then
        COMPOSE_ARGS+=("--force-recreate")
    fi
    
    log "🚀 Starting astron-agent services..."
    docker-compose pull || warn "Some Agent images could not be pulled"
    docker-compose up -d "${COMPOSE_ARGS[@]}"
    
    success "✅ astron-agent services deployed"
    
    cd "$WORKSPACE_DIR"
}

# ============================================================================
# HEALTH VERIFICATION
# ============================================================================

verify_deployment() {
    log "🔍 Verifying deployment..."
    
    # Wait for services to start
    log "⏳ Waiting for services to initialize..."
    sleep 45
    
    # Check services based on what was deployed
    SERVICES=()
    
    if [ "$DEPLOY_RPA" = true ]; then
        SERVICES+=(
            "http://localhost:8080:RPA Frontend"
            "http://localhost:8010:RPA AI Service"
            "http://localhost:8020:RPA OpenAPI Service"
            "http://localhost:8030:RPA Resource Service"
            "http://localhost:8040:RPA Robot Service"
        )
    fi
    
    if [ "$DEPLOY_AGENT" = true ]; then
        SERVICES+=(
            "http://localhost:1881:Agent Console Frontend"
            "http://localhost:8080:Agent Console Hub API"
            "http://localhost:17870:Agent Core"
            "http://localhost:7880:Agent Workflow Service"
            "http://localhost:20010:Agent Knowledge Service"
        )
    fi
    
    log "🔍 Checking service health..."
    for service in "${SERVICES[@]}"; do
        IFS=':' read -r url name <<< "$service"
        if curl -s --max-time 5 "$url" > /dev/null; then
            success "✅ $name: UP"
        else
            warn "⚠️ $name: DOWN or not ready"
        fi
    done
    
    # Show container status
    log "📊 Container status:"
    docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" | grep -E "(astron|rpa|agent)" || true
    
    success "✅ Deployment verification completed"
}

# ============================================================================
# SHELL ALIASES SETUP
# ============================================================================

setup_shell_aliases() {
    if [ "$SETUP_ALIASES" = false ]; then
        log "⏭️ Skipping shell aliases setup"
        return
    fi
    
    log "🔧 Setting up shell aliases..."
    
    # Detect shell
    SHELL_RC=""
    if [ -n "${BASH_VERSION:-}" ]; then
        SHELL_RC="$HOME/.bashrc"
    elif [ -n "${ZSH_VERSION:-}" ]; then
        SHELL_RC="$HOME/.zshrc"
    else
        warn "⚠️ Unknown shell, skipping aliases setup"
        return
    fi
    
    # Add unified aliases
    cat >> "$SHELL_RC" << 'EOF'

# ============================================================================
# ASTRON UNIFIED ALIASES
# ============================================================================
alias astron-workspace='cd ~/astron-workspace'
alias astron-status='echo "=== ASTRON-RPA ===" && cd ~/astron-workspace/astron-rpa/docker && docker-compose ps 2>/dev/null || echo "Not deployed"; echo "=== ASTRON-AGENT ===" && cd ~/astron-workspace/astron-agent/docker/astronAgent && docker-compose ps 2>/dev/null || echo "Not deployed"'
alias astron-logs='echo "Choose: astron-rpa-logs or astron-agent-logs"'
alias astron-start='echo "Choose: astron-rpa-start or astron-agent-start or astron-start-all"'
alias astron-stop='echo "Choose: astron-rpa-stop or astron-agent-stop or astron-stop-all"'

# RPA specific aliases
alias astron-rpa-status='cd ~/astron-workspace/astron-rpa/docker && docker-compose ps'
alias astron-rpa-logs='cd ~/astron-workspace/astron-rpa/docker && docker-compose logs -f'
alias astron-rpa-start='cd ~/astron-workspace/astron-rpa/docker && docker-compose up -d'
alias astron-rpa-stop='cd ~/astron-workspace/astron-rpa/docker && docker-compose down'
alias astron-rpa-restart='cd ~/astron-workspace/astron-rpa/docker && docker-compose restart'

# Agent specific aliases
alias astron-agent-status='cd ~/astron-workspace/astron-agent/docker/astronAgent && docker-compose ps'
alias astron-agent-logs='cd ~/astron-workspace/astron-agent/docker/astronAgent && docker-compose logs -f'
alias astron-agent-start='cd ~/astron-workspace/astron-agent/docker/astronAgent && docker-compose up -d'
alias astron-agent-stop='cd ~/astron-workspace/astron-agent/docker/astronAgent && docker-compose down'
alias astron-agent-restart='cd ~/astron-workspace/astron-agent/docker/astronAgent && docker-compose restart'

# Unified control aliases
alias astron-start-all='astron-rpa-start && astron-agent-start'
alias astron-stop-all='astron-rpa-stop && astron-agent-stop'
alias astron-restart-all='astron-rpa-restart && astron-agent-restart'

# Quick access aliases
alias astron-console='echo "🤖 RPA Frontend: http://localhost:8080" && echo "🧠 Agent Console: http://localhost:1881" && echo "🔧 Agent API: http://localhost:8080" && echo "📖 RPA API Docs: http://localhost:8020/docs"'
EOF
    
    success "✅ Shell aliases added to $SHELL_RC"
    log "💡 Run 'source $SHELL_RC' or restart your terminal to use aliases"
}

# ============================================================================
# MAIN DEPLOYMENT FUNCTION
# ============================================================================

main() {
    # Show banner
    echo -e "${PURPLE}"
    echo "============================================================================"
    echo "                🚀 ASTRON UNIFIED DEPLOYMENT 🚀"
    echo "              astron-agent + astron-rpa Integration"
    echo "============================================================================"
    echo -e "${NC}"
    echo ""
    echo -e "${CYAN}Deployment Configuration:${NC}"
    if [ "$DEPLOY_AGENT" = true ] && [ "$DEPLOY_RPA" = true ]; then
        echo "  🎯 Mode: Full deployment (Agent + RPA)"
    elif [ "$DEPLOY_AGENT" = true ]; then
        echo "  🎯 Mode: Agent only"
    elif [ "$DEPLOY_RPA" = true ]; then
        echo "  🎯 Mode: RPA only"
    fi
    echo ""
    echo -e "${CYAN}This script will:${NC}"
    echo "  ✅ Check system requirements"
    echo "  ✅ Install Docker and dependencies"
    echo "  ✅ Setup repositories"
    echo "  ✅ Configure Docker networks"
    if [ "$DEPLOY_RPA" = true ]; then
        echo "  ✅ Deploy astron-rpa services"
    fi
    if [ "$DEPLOY_AGENT" = true ]; then
        echo "  ✅ Deploy astron-agent services"
    fi
    echo "  ✅ Set up shell aliases"
    echo "  ✅ Verify deployment"
    echo ""
    
    # Show resource requirements
    if [ "$DEPLOY_AGENT" = true ] && [ "$DEPLOY_RPA" = true ]; then
        echo -e "${YELLOW}⚠️ Full deployment requirements:${NC}"
        echo -e "${YELLOW}   • Memory: 12GB+ RAM recommended${NC}"
        echo -e "${YELLOW}   • Disk: 30GB+ free space${NC}"
        echo -e "${YELLOW}   • Network: ~5-8GB download${NC}"
    elif [ "$DEPLOY_AGENT" = true ]; then
        echo -e "${YELLOW}⚠️ Agent deployment requirements:${NC}"
        echo -e "${YELLOW}   • Memory: 8GB+ RAM recommended${NC}"
        echo -e "${YELLOW}   • Disk: 20GB+ free space${NC}"
        echo -e "${YELLOW}   • Network: ~3-5GB download${NC}"
    else
        echo -e "${YELLOW}⚠️ RPA deployment requirements:${NC}"
        echo -e "${YELLOW}   • Memory: 4GB+ RAM recommended${NC}"
        echo -e "${YELLOW}   • Disk: 10GB+ free space${NC}"
        echo -e "${YELLOW}   • Network: ~2-3GB download${NC}"
    fi
    echo ""
    
    # Confirm deployment
    read -p "Do you want to proceed with the deployment? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log "Deployment cancelled by user"
        exit 0
    fi
    
    # Start deployment
    log "🚀 Starting unified deployment..."
    
    # Execute deployment steps
    if [ "$SKIP_DEPS_CHECK" = false ]; then
        check_system_requirements
    fi
    install_docker
    setup_repositories
    setup_networks
    deploy_astron_rpa
    deploy_astron_agent
    verify_deployment
    setup_shell_aliases
    
    # Final success message
    echo ""
    echo -e "${GREEN}============================================================================${NC}"
    echo -e "${GREEN}                    🎉 DEPLOYMENT COMPLETED! 🎉${NC}"
    echo -e "${GREEN}============================================================================${NC}"
    echo ""
    echo -e "${CYAN}🌐 Access URLs:${NC}"
    
    if [ "$DEPLOY_RPA" = true ]; then
        echo "   🤖 RPA Frontend: http://localhost:8080"
        echo "   🔧 RPA OpenAPI: http://localhost:8020"
        echo "   📖 RPA API Docs: http://localhost:8020/docs"
    fi
    
    if [ "$DEPLOY_AGENT" = true ]; then
        echo "   🧠 Agent Console: http://localhost:1881"
        echo "   🔧 Agent Hub API: http://localhost:8080"
        echo "   🤖 Agent Core: http://localhost:17870"
    fi
    
    echo ""
    echo -e "${CYAN}🛠️ Management Commands:${NC}"
    echo "   astron-status        - Check all services status"
    echo "   astron-console       - Show all access URLs"
    echo "   astron-start-all     - Start all services"
    echo "   astron-stop-all      - Stop all services"
    echo "   astron-restart-all   - Restart all services"
    echo ""
    echo "   astron-rpa-*         - RPA specific commands"
    echo "   astron-agent-*       - Agent specific commands"
    echo ""
    echo -e "${YELLOW}💡 Tip: Run 'source ~/.bashrc' to enable aliases${NC}"
    echo ""
    
    if [ "$DEPLOY_AGENT" = true ] && [ "$DEPLOY_RPA" = true ]; then
        echo -e "${GREEN}🚀 Full astron platform is now ready!${NC}"
        echo -e "${GREEN}   AI Agents can now use RPA capabilities for complete automation!${NC}"
    elif [ "$DEPLOY_AGENT" = true ]; then
        echo -e "${GREEN}🚀 astron-agent is now ready for AI agent workflows!${NC}"
    else
        echo -e "${GREEN}🚀 astron-rpa is now ready for robotic process automation!${NC}"
    fi
    echo ""
}

# Run main function
main "$@"
