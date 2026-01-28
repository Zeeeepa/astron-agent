#!/bin/bash

# ============================================================================
# ASTRON-RPA DEPLOYMENT SCRIPT
# Based on official astron-rpa repository documentation
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
SKIP_DEPS_CHECK=false
FORCE_RECREATE=false
INSTALL_DOCKER=true
SETUP_ALIASES=true
PRODUCTION_MODE=false

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
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
        --production)
            PRODUCTION_MODE=true
            shift
            ;;
        --help)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --skip-deps        Skip dependency checks"
            echo "  --force-recreate   Force recreate containers"
            echo "  --skip-docker      Skip Docker installation"
            echo "  --skip-aliases     Skip shell alias setup"
            echo "  --production       Enable production mode"
            echo "  --help             Show this help message"
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
    
    # Check memory
    if command -v free &> /dev/null; then
        TOTAL_MEM=$(free -g | awk '/^Mem:/{print $2}')
        if [ "$TOTAL_MEM" -lt 4 ]; then
            warn "⚠️ Low memory detected: ${TOTAL_MEM}GB (recommended: 4GB+)"
        else
            log "✅ Memory: ${TOTAL_MEM}GB"
        fi
    fi
    
    # Check disk space
    AVAILABLE_SPACE=$(df -BG . | awk 'NR==2 {print $4}' | sed 's/G//')
    if [ "$AVAILABLE_SPACE" -lt 10 ]; then
        warn "⚠️ Low disk space: ${AVAILABLE_SPACE}GB (recommended: 10GB+)"
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

setup_repository() {
    log "📁 Setting up astron-rpa repository..."
    
    # Check if we're already in astron-rpa directory
    if [[ $(basename "$PWD") == "astron-rpa" ]]; then
        log "✅ Already in astron-rpa directory"
    else
        # Check if astron-rpa directory exists
        if [ -d "astron-rpa" ]; then
            log "📁 Found existing astron-rpa directory"
            cd astron-rpa
        else
            log "📥 Cloning astron-rpa repository..."
            git clone https://github.com/Zeeeepa/astron-rpa.git
            cd astron-rpa
        fi
    fi
    
    # Update repository
    log "🔄 Updating repository..."
    git fetch origin
    git pull origin main || git pull origin master || warn "Could not update repository"
    
    success "✅ Repository setup completed"
}

# ============================================================================
# ENVIRONMENT CONFIGURATION
# ============================================================================

setup_environment() {
    log "🔧 Setting up environment configuration..."
    
    # Navigate to docker directory
    if [ -d "docker" ]; then
        cd docker
    else
        error "❌ Docker directory not found in astron-rpa repository"
    fi
    
    # Setup environment file
    if [ -f ".env.example" ]; then
        if [ ! -f ".env" ]; then
            log "📝 Creating environment configuration from template..."
            cp .env.example .env
        else
            log "✅ Environment file already exists"
        fi
    else
        log "📝 Creating default environment configuration..."
        cat > .env << 'EOF'
# ============================================================================
# ASTRON-RPA ENVIRONMENT CONFIGURATION
# ============================================================================

# MySQL Database Configuration
MYSQL_ROOT_PASSWORD=root123
MYSQL_DATABASE=astron_rpa
MYSQL_USER=astron
MYSQL_PASSWORD=astron123

# Redis Configuration
REDIS_PASSWORD=redis123

# MinIO Configuration
MINIO_ROOT_USER=minioadmin
MINIO_ROOT_PASSWORD=minioadmin123

# Service Ports
AI_SERVICE_PORT=8010
OPENAPI_SERVICE_PORT=8020
RESOURCE_SERVICE_PORT=8030
ROBOT_SERVICE_PORT=8040
FRONTEND_PORT=8080

# Network Configuration
NETWORK_SUBNET=172.30.0.0/16

# Production Settings
PRODUCTION_MODE=${PRODUCTION_MODE}
LOG_LEVEL=INFO
DEBUG_MODE=false

# Security Settings
JWT_SECRET=your-jwt-secret-key-here
API_KEY=your-api-key-here

# External Integrations
DEEPSEEK_API_KEY=your-deepseek-api-key
DEEPSEEK_BASE_URL=https://api.deepseek.com

# File Storage
UPLOAD_MAX_SIZE=100MB
STORAGE_PATH=/app/storage
EOF
    fi
    
    # Update production mode in .env if specified
    if [ "$PRODUCTION_MODE" = true ]; then
        sed -i 's/PRODUCTION_MODE=.*/PRODUCTION_MODE=true/' .env
        sed -i 's/DEBUG_MODE=.*/DEBUG_MODE=false/' .env
        sed -i 's/LOG_LEVEL=.*/LOG_LEVEL=WARN/' .env
    fi
    
    success "✅ Environment configuration completed"
}

# ============================================================================
# ASTRON-RPA DEPLOYMENT
# ============================================================================

deploy_astron_rpa() {
    log "🚀 Deploying astron-rpa services..."
    
    # Pull images
    log "📥 Pulling Docker images..."
    if ! docker-compose pull; then
        warn "⚠️ Some images could not be pulled, continuing with deployment"
    fi
    
    # Deploy services
    COMPOSE_ARGS=()
    if [ "$FORCE_RECREATE" = true ]; then
        COMPOSE_ARGS+=("--force-recreate")
    fi
    
    log "🚀 Starting astron-rpa services..."
    docker-compose up -d "${COMPOSE_ARGS[@]}"
    
    success "✅ astron-rpa services deployed"
    
    # Go back to root directory
    cd ..
}

# ============================================================================
# HEALTH VERIFICATION
# ============================================================================

verify_deployment() {
    log "🔍 Verifying deployment..."
    
    # Wait for services to start
    log "⏳ Waiting for services to initialize..."
    sleep 30
    
    # Check core services
    SERVICES=(
        "http://localhost:8080:RPA Frontend"
        "http://localhost:8010:AI Service"
        "http://localhost:8020:OpenAPI Service"
        "http://localhost:8030:Resource Service"
        "http://localhost:8040:Robot Service"
        "http://localhost:9001:MinIO Console"
    )
    
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
    docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" | grep -E "(astron|rpa)" || true
    
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
    
    # Add aliases
    cat >> "$SHELL_RC" << 'EOF'

# ============================================================================
# ASTRON-RPA ALIASES
# ============================================================================
alias rpa-status='cd ~/astron-rpa/docker && docker-compose ps'
alias rpa-logs='cd ~/astron-rpa/docker && docker-compose logs -f'
alias rpa-start='cd ~/astron-rpa/docker && docker-compose up -d'
alias rpa-stop='cd ~/astron-rpa/docker && docker-compose down'
alias rpa-restart='cd ~/astron-rpa/docker && docker-compose restart'
alias rpa-console='echo "🌐 RPA Frontend: http://localhost:8080" && echo "🔧 OpenAPI Service: http://localhost:8020" && echo "💾 MinIO Console: http://localhost:9001"'
alias rpa-ai='curl -s http://localhost:8010/health || echo "AI Service not responding"'
alias rpa-api='curl -s http://localhost:8020/docs || echo "OpenAPI Service not responding"'
EOF
    
    success "✅ Shell aliases added to $SHELL_RC"
    log "💡 Run 'source $SHELL_RC' or restart your terminal to use aliases"
}

# ============================================================================
# DEVELOPMENT TOOLS SETUP (OPTIONAL)
# ============================================================================

setup_development_tools() {
    log "🛠️ Setting up development tools..."
    
    # Check if we're in development mode
    if [ "$PRODUCTION_MODE" = true ]; then
        log "⏭️ Skipping development tools setup (production mode)"
        return
    fi
    
    # Check for Node.js (for frontend development)
    if command -v node &> /dev/null; then
        NODE_VERSION=$(node --version)
        log "✅ Node.js found: $NODE_VERSION"
    else
        warn "⚠️ Node.js not found. Install Node.js 22+ for frontend development"
    fi
    
    # Check for Python (for backend development)
    if command -v python3 &> /dev/null; then
        PYTHON_VERSION=$(python3 --version)
        log "✅ Python found: $PYTHON_VERSION"
    else
        warn "⚠️ Python 3.13+ not found. Install Python for backend development"
    fi
    
    # Check for Java (for some services)
    if command -v java &> /dev/null; then
        JAVA_VERSION=$(java -version 2>&1 | head -n 1)
        log "✅ Java found: $JAVA_VERSION"
    else
        warn "⚠️ Java JDK 8+ not found. Install Java for some RPA services"
    fi
    
    success "✅ Development tools check completed"
}

# ============================================================================
# MAIN DEPLOYMENT FUNCTION
# ============================================================================

main() {
    # Show banner
    echo -e "${PURPLE}"
    echo "============================================================================"
    echo "                    🤖 ASTRON-RPA DEPLOYMENT 🤖"
    echo "                  Robotic Process Automation Platform"
    echo "============================================================================"
    echo -e "${NC}"
    echo ""
    echo -e "${CYAN}This script will:${NC}"
    echo "  ✅ Check system requirements"
    echo "  ✅ Install Docker and dependencies"
    echo "  ✅ Setup astron-rpa repository"
    echo "  ✅ Configure environment"
    echo "  ✅ Deploy astron-rpa services"
    echo "  ✅ Set up shell aliases"
    echo "  ✅ Verify deployment"
    if [ "$PRODUCTION_MODE" = false ]; then
        echo "  ✅ Setup development tools"
    fi
    echo ""
    echo -e "${YELLOW}⚠️ This will download Docker images (~2-3GB)${NC}"
    echo -e "${YELLOW}⚠️ Ensure sufficient disk space and internet connection${NC}"
    echo ""
    
    # Confirm deployment
    read -p "Do you want to proceed with the deployment? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log "Deployment cancelled by user"
        exit 0
    fi
    
    # Start deployment
    log "🚀 Starting astron-rpa deployment..."
    
    # Execute deployment steps
    if [ "$SKIP_DEPS_CHECK" = false ]; then
        check_system_requirements
    fi
    install_docker
    setup_repository
    setup_environment
    deploy_astron_rpa
    verify_deployment
    setup_shell_aliases
    setup_development_tools
    
    # Final success message
    echo ""
    echo -e "${GREEN}============================================================================${NC}"
    echo -e "${GREEN}                    🎉 DEPLOYMENT COMPLETED! 🎉${NC}"
    echo -e "${GREEN}============================================================================${NC}"
    echo ""
    echo -e "${CYAN}🌐 Access URLs:${NC}"
    echo "   🖥️  RPA Frontend: http://localhost:8080"
    echo "   🤖 AI Service: http://localhost:8010"
    echo "   🔧 OpenAPI Service: http://localhost:8020"
    echo "   📊 Resource Service: http://localhost:8030"
    echo "   🤖 Robot Service: http://localhost:8040"
    echo "   💾 MinIO Console: http://localhost:9001 (minioadmin/minioadmin123)"
    echo ""
    echo -e "${CYAN}📚 API Documentation:${NC}"
    echo "   📖 OpenAPI Docs: http://localhost:8020/docs"
    echo "   📖 AI Service Docs: http://localhost:8010/docs"
    echo ""
    echo -e "${CYAN}🛠️ Management Commands:${NC}"
    echo "   rpa-status       - Check service status"
    echo "   rpa-logs         - View service logs"
    echo "   rpa-start        - Start all services"
    echo "   rpa-stop         - Stop all services"
    echo "   rpa-restart      - Restart all services"
    echo "   rpa-console      - Show console URLs"
    echo "   rpa-ai           - Test AI service"
    echo "   rpa-api          - Test API service"
    echo ""
    echo -e "${CYAN}🔧 Development:${NC}"
    if [ "$PRODUCTION_MODE" = false ]; then
        echo "   📁 Frontend: cd ~/astron-rpa/frontend && pnpm dev:web"
        echo "   🐍 Backend: cd ~/astron-rpa/backend && python main.py"
        echo "   📖 Docs: Visit http://localhost:8020/docs for API documentation"
    else
        echo "   🏭 Production mode enabled - development tools skipped"
    fi
    echo ""
    echo -e "${YELLOW}💡 Tip: Run 'source ~/.bashrc' to enable aliases${NC}"
    echo ""
    echo -e "${GREEN}🚀 astron-rpa is now ready for robotic process automation!${NC}"
    echo ""
}

# Run main function
main "$@"
