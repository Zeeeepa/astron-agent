#!/bin/bash

# ============================================================================
# ASTRON UNIFIED DEPLOYMENT SCRIPT
# Complete deployment for astron-agent + astron-rpa Integration
# ============================================================================

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="${SCRIPT_DIR}/.env.unified"
COMPOSE_FILE="${SCRIPT_DIR}/docker-compose.unified.yml"
LOG_FILE="${SCRIPT_DIR}/deployment.log"

# Default values
SKIP_DEPS_CHECK=false
SKIP_BUILD=false
FORCE_RECREATE=false
ENABLE_MONITORING=false
PRODUCTION_MODE=false
INSTALL_DOCKER=true
SETUP_ALIASES=true

# ============================================================================
# UTILITY FUNCTIONS
# ============================================================================

log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1" | tee -a "$LOG_FILE"
}

warn() {
    echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')] WARNING:${NC} $1" | tee -a "$LOG_FILE"
}

error() {
    echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')] ERROR:${NC} $1" | tee -a "$LOG_FILE"
    exit 1
}

info() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')] INFO:${NC} $1" | tee -a "$LOG_FILE"
}

success() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] SUCCESS:${NC} $1" | tee -a "$LOG_FILE"
}

# ============================================================================
# HELP FUNCTION
# ============================================================================

show_help() {
    echo -e "${PURPLE}"
    echo "============================================================================"
    echo "                    ASTRON UNIFIED DEPLOYMENT"
    echo "                   astron-agent + astron-rpa"
    echo "============================================================================"
    echo -e "${NC}"
    echo ""
    echo -e "${CYAN}Usage:${NC} $0 [OPTIONS]"
    echo ""
    echo -e "${CYAN}Options:${NC}"
    echo "  -h, --help              Show this help message"
    echo "  --skip-deps             Skip dependency installation"
    echo "  --skip-docker           Skip Docker installation"
    echo "  --skip-aliases          Skip shell alias setup"
    echo "  --force-recreate        Force recreate all containers"
    echo "  --production            Enable production mode"
    echo "  --enable-monitoring     Enable Prometheus/Grafana monitoring"
    echo "  --no-build              Skip building custom images"
    echo ""
    echo -e "${CYAN}Examples:${NC}"
    echo "  $0                      # Full deployment with all features"
    echo "  $0 --skip-deps          # Skip dependency installation"
    echo "  $0 --production         # Production deployment"
    echo "  $0 --force-recreate     # Force recreate all containers"
    echo ""
    echo -e "${CYAN}What this script does:${NC}"
    echo "  ✅ Check system requirements"
    echo "  ✅ Install Docker and dependencies"
    echo "  ✅ Configure environment"
    echo "  ✅ Deploy 21+ integrated services"
    echo "  ✅ Set up shell aliases"
    echo "  ✅ Verify deployment"
    echo ""
}

# ============================================================================
# SYSTEM REQUIREMENTS CHECK
# ============================================================================

check_system_requirements() {
    info "🔍 Checking system requirements..."
    
    # Check OS
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        success "✅ Operating System: Linux"
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        success "✅ Operating System: macOS"
    else
        error "❌ Unsupported operating system: $OSTYPE"
    fi
    
    # Check architecture
    ARCH=$(uname -m)
    if [[ "$ARCH" == "x86_64" ]] || [[ "$ARCH" == "amd64" ]]; then
        success "✅ Architecture: $ARCH"
    elif [[ "$ARCH" == "arm64" ]] || [[ "$ARCH" == "aarch64" ]]; then
        success "✅ Architecture: $ARCH (ARM64)"
    else
        warn "⚠️ Architecture: $ARCH (may have compatibility issues)"
    fi
    
    # Check memory
    if command -v free >/dev/null 2>&1; then
        MEMORY_GB=$(free -g | awk '/^Mem:/{print $2}')
        if [ "$MEMORY_GB" -ge 8 ]; then
            success "✅ Memory: ${MEMORY_GB}GB"
        else
            warn "⚠️ Memory: ${MEMORY_GB}GB (8GB+ recommended)"
        fi
    else
        warn "⚠️ Cannot check memory (free command not available)"
    fi
    
    # Check disk space
    DISK_GB=$(df -BG . | awk 'NR==2 {print $4}' | sed 's/G//')
    if [ "$DISK_GB" -ge 50 ]; then
        success "✅ Disk Space: ${DISK_GB}GB available"
    else
        warn "⚠️ Disk Space: ${DISK_GB}GB (50GB+ recommended)"
    fi
}

# ============================================================================
# DOCKER INSTALLATION
# ============================================================================

install_docker() {
    if [ "$INSTALL_DOCKER" = false ]; then
        info "⏭️ Skipping Docker installation"
        return
    fi
    
    info "🐳 Installing Docker..."
    
    # Check if Docker is already installed and working
    if command -v docker >/dev/null 2>&1 && docker info >/dev/null 2>&1; then
        DOCKER_VERSION=$(docker --version | cut -d' ' -f3 | cut -d',' -f1)
        success "✅ Docker already installed and working: $DOCKER_VERSION"
        
        # Check Docker Compose
        if docker compose version >/dev/null 2>&1; then
            COMPOSE_VERSION=$(docker compose version --short)
            success "✅ Docker Compose plugin available: $COMPOSE_VERSION"
        else
            warn "⚠️ Docker Compose plugin not available, installing..."
            install_docker_compose
        fi
        return
    fi
    
    # Detect WSL2
    if grep -qi microsoft /proc/version 2>/dev/null; then
        warn "⚠️ WSL2 detected. Docker Desktop integration required."
        echo ""
        echo -e "${YELLOW}WSL2 Docker Setup Instructions:${NC}"
        echo "1. Install Docker Desktop on Windows"
        echo "2. Enable WSL2 integration in Docker Desktop settings"
        echo "3. Restart this script after Docker is available"
        echo ""
        echo -e "${CYAN}Alternative - Install Docker directly in WSL2:${NC}"
        read -p "Install Docker directly in WSL2? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            install_docker_wsl2
        else
            error "Docker is required for deployment. Please set up Docker and try again."
        fi
        return
    fi
    
    # Install Docker on Linux
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        install_docker_linux
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        install_docker_macos
    else
        error "Automatic Docker installation not supported on $OSTYPE"
    fi
}

install_docker_linux() {
    info "📦 Installing Docker on Linux..."
    
    # Update package index
    sudo apt-get update
    
    # Install prerequisites
    sudo apt-get install -y \
        ca-certificates \
        curl \
        gnupg \
        lsb-release
    
    # Add Docker's official GPG key
    sudo mkdir -p /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    
    # Set up repository
    echo \
        "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
        $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
    
    # Install Docker Engine
    sudo apt-get update
    sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
    
    # Add user to docker group
    sudo usermod -aG docker $USER
    
    # Start Docker service
    sudo systemctl start docker
    sudo systemctl enable docker
    
    success "✅ Docker installed successfully"
    warn "⚠️ Please log out and back in for group changes to take effect"
}

install_docker_wsl2() {
    info "📦 Installing Docker in WSL2..."
    
    # Update package index
    sudo apt-get update
    
    # Install prerequisites
    sudo apt-get install -y \
        ca-certificates \
        curl \
        gnupg \
        lsb-release \
        iptables
    
    # Add Docker's official GPG key
    sudo mkdir -p /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    
    # Set up repository
    echo \
        "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
        $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
    
    # Install Docker Engine
    sudo apt-get update
    sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
    
    # Configure Docker for WSL2
    sudo update-alternatives --set iptables /usr/sbin/iptables-legacy
    
    # Add user to docker group
    sudo usermod -aG docker $USER
    
    # Start Docker service
    sudo service docker start
    
    success "✅ Docker installed in WSL2"
    info "💡 Docker will start automatically on WSL2 startup"
}

install_docker_macos() {
    info "📦 Installing Docker on macOS..."
    
    if command -v brew >/dev/null 2>&1; then
        brew install --cask docker
        success "✅ Docker Desktop installed via Homebrew"
        info "💡 Please start Docker Desktop from Applications"
    else
        warn "⚠️ Homebrew not found. Please install Docker Desktop manually:"
        echo "https://docs.docker.com/desktop/install/mac-install/"
        error "Manual Docker installation required"
    fi
}

# ============================================================================
# DEPENDENCY INSTALLATION
# ============================================================================

install_dependencies() {
    if [ "$SKIP_DEPS_CHECK" = true ]; then
        info "⏭️ Skipping dependency installation"
        return
    fi
    
    info "📦 Installing system dependencies..."
    
    # Required packages
    PACKAGES=("curl" "jq" "openssl")
    MISSING_PACKAGES=()
    
    # Check which packages are missing
    for package in "${PACKAGES[@]}"; do
        if ! command -v "$package" >/dev/null 2>&1; then
            MISSING_PACKAGES+=("$package")
        fi
    done
    
    if [ ${#MISSING_PACKAGES[@]} -eq 0 ]; then
        success "✅ All dependencies already installed"
        return
    fi
    
    # Install missing packages
    info "📥 Installing missing packages: ${MISSING_PACKAGES[*]}"
    
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        # Detect package manager
        if command -v apt-get >/dev/null 2>&1; then
            sudo apt-get update
            sudo apt-get install -y "${MISSING_PACKAGES[@]}"
        elif command -v yum >/dev/null 2>&1; then
            sudo yum install -y "${MISSING_PACKAGES[@]}"
        elif command -v dnf >/dev/null 2>&1; then
            sudo dnf install -y "${MISSING_PACKAGES[@]}"
        else
            error "No supported package manager found"
        fi
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        if command -v brew >/dev/null 2>&1; then
            brew install "${MISSING_PACKAGES[@]}"
        else
            error "Homebrew required for macOS dependency installation"
        fi
    fi
    
    success "✅ Dependencies installed"
}

# ============================================================================
# ENVIRONMENT CONFIGURATION
# ============================================================================

configure_environment() {
    info "⚙️ Configuring environment..."
    
    # Check if environment file exists
    if [ -f "$ENV_FILE" ]; then
        success "✅ Environment configuration already exists"
    else
        error "❌ Environment file not found: $ENV_FILE"
    fi
    
    # Generate SSL certificates if needed
    SSL_DIR="${SCRIPT_DIR}/nginx/ssl"
    if [ ! -d "$SSL_DIR" ]; then
        info "🔐 Generating SSL certificates..."
        mkdir -p "$SSL_DIR"
        
        # Generate self-signed certificate
        openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
            -keyout "$SSL_DIR/key.pem" \
            -out "$SSL_DIR/cert.pem" \
            -subj "/C=US/ST=State/L=City/O=Organization/CN=localhost" \
            >/dev/null 2>&1
        
        success "✅ SSL certificates generated"
    fi
    
    # Set production mode if requested
    if [ "$PRODUCTION_MODE" = true ]; then
        info "🏭 Configuring for production mode..."
        # Update environment variables for production
        sed -i 's/DEBUG_MODE=true/DEBUG_MODE=false/' "$ENV_FILE" 2>/dev/null || true
        sed -i 's/SSL_ENABLED=false/SSL_ENABLED=true/' "$ENV_FILE" 2>/dev/null || true
        success "✅ Production mode configured"
    fi
}

# ============================================================================
# DOCKER NETWORK SETUP
# ============================================================================

setup_docker_networks() {
    info "🌐 Setting up Docker networks..."
    
    # Check if network already exists
    if docker network ls | grep -q "astron-unified-network"; then
        success "✅ Docker network already exists"
        return
    fi
    
    # Create custom network
    docker network create \
        --driver bridge \
        --subnet=172.50.0.0/16 \
        --ip-range=172.50.1.0/24 \
        --gateway=172.50.0.1 \
        astron-unified-network || {
        warn "⚠️ Could not create custom network, using default"
    }
    
    success "✅ Docker network configured"
}

# ============================================================================
# SERVICE DEPLOYMENT
# ============================================================================

deploy_services() {
    info "🚀 Deploying services..."
    
    # Check if compose file exists
    if [ ! -f "$COMPOSE_FILE" ]; then
        error "❌ Docker Compose file not found: $COMPOSE_FILE"
    fi
    
    # Validate compose file
    info "🔍 Validating Docker Compose configuration..."
    if ! docker compose -f "$COMPOSE_FILE" --env-file "$ENV_FILE" config >/dev/null 2>&1; then
        error "❌ Invalid Docker Compose configuration"
    fi
    success "✅ Docker Compose configuration valid"
    
    # Pull images first
    info "📥 Pulling Docker images..."
    docker compose -f "$COMPOSE_FILE" --env-file "$ENV_FILE" pull --quiet || {
        warn "⚠️ Some images could not be pulled, continuing with deployment"
    }
    
    # Deploy services
    COMPOSE_ARGS=()
    if [ "$FORCE_RECREATE" = true ]; then
        COMPOSE_ARGS+=("--force-recreate")
    fi
    
    info "🚀 Starting services..."
    docker compose -f "$COMPOSE_FILE" --env-file "$ENV_FILE" up -d "${COMPOSE_ARGS[@]}"
    
    success "✅ Services deployed"
}

# ============================================================================
# HEALTH VERIFICATION
# ============================================================================

verify_deployment() {
    info "🔍 Verifying deployment..."
    
    # Wait for services to start
    info "⏳ Waiting for services to initialize..."
    sleep 30
    
    # Check container status
    info "📊 Checking container status..."
    RUNNING_CONTAINERS=$(docker compose -f "$COMPOSE_FILE" --env-file "$ENV_FILE" ps --services --filter "status=running" | wc -l)
    TOTAL_CONTAINERS=$(docker compose -f "$COMPOSE_FILE" --env-file "$ENV_FILE" ps --services | wc -l)
    
    if [ "$RUNNING_CONTAINERS" -eq "$TOTAL_CONTAINERS" ]; then
        success "✅ All $TOTAL_CONTAINERS containers running"
    else
        warn "⚠️ $RUNNING_CONTAINERS/$TOTAL_CONTAINERS containers running"
    fi
    
    # Test key endpoints
    info "🌐 Testing service endpoints..."
    
    # Test main proxy
    if curl -s http://localhost/health >/dev/null 2>&1; then
        success "✅ Main proxy responding"
    else
        warn "⚠️ Main proxy not responding"
    fi
    
    # Test RPA API
    if curl -s http://localhost:8020/health >/dev/null 2>&1; then
        success "✅ RPA API responding"
    else
        warn "⚠️ RPA API not responding"
    fi
    
    # Test Agent Core
    if curl -s http://localhost:17870/health >/dev/null 2>&1; then
        success "✅ Agent Core responding"
    else
        warn "⚠️ Agent Core not responding"
    fi
    
    # Run health check script if available
    if [ -f "${SCRIPT_DIR}/scripts/health-check.sh" ]; then
        info "🏥 Running comprehensive health check..."
        "${SCRIPT_DIR}/scripts/health-check.sh" --quiet || {
            warn "⚠️ Some health checks failed"
        }
    fi
}

# ============================================================================
# SHELL ALIAS SETUP
# ============================================================================

setup_shell_aliases() {
    if [ "$SETUP_ALIASES" = false ]; then
        info "⏭️ Skipping shell alias setup"
        return
    fi
    
    info "📝 Setting up shell aliases..."
    
    # Check if aliases already exist
    if grep -q "# Astron Platform Aliases" ~/.bashrc 2>/dev/null; then
        success "✅ Shell aliases already configured"
        return
    fi
    
    # Add aliases to bashrc
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
alias ports='echo "🌐 Service Ports:"; echo "  Main Access: http://localhost (port 80)"; echo "  RPA API: http://localhost:8020"; echo "  Agent Core: http://localhost:17870"; echo "  Agent Console: http://localhost:8080"'

# Service Groups
alias start-infra='cd ~/astron-agent && ./scripts/manage-services.sh start infra'
alias start-rpa='cd ~/astron-agent && ./scripts/manage-services.sh start rpa'
alias start-agent='cd ~/astron-agent && ./scripts/manage-services.sh start agent'

# Maintenance
alias backup='cd ~/astron-agent && ./scripts/manage-services.sh backup'
alias cleanup='cd ~/astron-agent && ./scripts/manage-services.sh cleanup'
alias update='cd ~/astron-agent && ./scripts/manage-services.sh update'

BASHRC_EOF

    success "✅ Shell aliases configured"
    info "💡 Run 'source ~/.bashrc' to activate aliases"
}

# ============================================================================
# MAIN DEPLOYMENT FUNCTION
# ============================================================================

main() {
    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_help
                exit 0
                ;;
            --skip-deps)
                SKIP_DEPS_CHECK=true
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
            --force-recreate)
                FORCE_RECREATE=true
                shift
                ;;
            --production)
                PRODUCTION_MODE=true
                shift
                ;;
            --enable-monitoring)
                ENABLE_MONITORING=true
                shift
                ;;
            --no-build)
                SKIP_BUILD=true
                shift
                ;;
            *)
                error "Unknown option: $1"
                ;;
        esac
    done
    
    # Show banner
    echo -e "${PURPLE}"
    echo "============================================================================"
    echo "                    🚀 ASTRON UNIFIED DEPLOYMENT 🚀"
    echo "                   astron-agent + astron-rpa Integration"
    echo "============================================================================"
    echo -e "${NC}"
    echo ""
    echo -e "${CYAN}This script will:${NC}"
    echo "  ✅ Check system requirements"
    echo "  ✅ Install Docker and dependencies"
    echo "  ✅ Configure environment"
    echo "  ✅ Deploy 21+ integrated services"
    echo "  ✅ Set up shell aliases"
    echo "  ✅ Verify deployment"
    echo ""
    echo -e "${YELLOW}⚠️ This will download Docker images (~5GB)${NC}"
    echo -e "${YELLOW}⚠️ Ensure sufficient disk space and internet connection${NC}"
    echo ""
    
    # Confirm deployment
    read -p "Do you want to proceed with the deployment? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        info "Deployment cancelled by user"
        exit 0
    fi
    
    # Start deployment
    log "🚀 Starting unified deployment of astron-agent + astron-rpa..."
    
    # Execute deployment steps
    check_system_requirements
    install_docker
    install_dependencies
    configure_environment
    setup_docker_networks
    deploy_services
    verify_deployment
    setup_shell_aliases
    
    # Show completion message
    echo ""
    echo -e "${GREEN}"
    echo "============================================================================"
    echo "                    🎉 DEPLOYMENT COMPLETE! 🎉"
    echo "============================================================================"
    echo -e "${NC}"
    echo ""
    echo -e "${CYAN}🌐 Access Your Platforms:${NC}"
    echo -e "   🤖 RPA Platform:      ${GREEN}http://localhost/rpa/${NC}"
    echo -e "   🧠 Agent Console:     ${GREEN}http://localhost/agent/${NC}"
    echo -e "   🔐 Authentication:    ${GREEN}http://localhost/auth/${NC}"
    echo -e "   💾 MinIO Console:     ${GREEN}http://localhost/minio/${NC}"
    echo -e "   📊 Health Check:      ${GREEN}http://localhost/health${NC}"
    echo ""
    echo -e "${CYAN}💡 Quick Commands:${NC}"
    echo -e "   ${GREEN}start${NC}    - Start all services"
    echo -e "   ${GREEN}stop${NC}     - Stop all services"
    echo -e "   ${GREEN}status${NC}   - Check system health"
    echo -e "   ${GREEN}logs${NC}     - View service logs"
    echo -e "   ${GREEN}rpa${NC}      - Open RPA platform"
    echo -e "   ${GREEN}agent${NC}    - Open Agent console"
    echo ""
    echo -e "${CYAN}📚 Documentation:${NC}"
    echo -e "   ${GREEN}README-deployment.md${NC}     - Complete guide"
    echo -e "   ${GREEN}QUICK-START-COMMANDS.md${NC}  - Command reference"
    echo ""
    echo -e "${YELLOW}⚠️ Next Steps:${NC}"
    echo -e "   1. Run: ${GREEN}source ~/.bashrc${NC} to activate aliases"
    echo -e "   2. Test: ${GREEN}health${NC} to verify system status"
    echo -e "   3. Access: ${GREEN}rpa${NC} or ${GREEN}agent${NC} to open platforms"
    echo ""
    echo -e "${PURPLE}🎊 Welcome to the Astron Unified Platform! 🎊${NC}"
    
    success "✅ Deployment completed successfully!"
}

# ============================================================================
# SCRIPT EXECUTION
# ============================================================================

# Ensure script is run from correct directory
cd "$SCRIPT_DIR"

# Run main function
main "$@"

