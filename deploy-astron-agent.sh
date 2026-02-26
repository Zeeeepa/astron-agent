#!/bin/bash

# ============================================================================
# ASTRON-AGENT DEPLOYMENT SCRIPT
# Based on official astron-agent repository documentation
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
ENABLE_CASDOOR=false
ENABLE_RAGFLOW=false

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
        --with-casdoor)
            ENABLE_CASDOOR=true
            shift
            ;;
        --with-ragflow)
            ENABLE_RAGFLOW=true
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
            echo "  --with-casdoor     Deploy with Casdoor authentication"
            echo "  --with-ragflow     Deploy with RagFlow knowledge base"
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
        if [ "$TOTAL_MEM" -lt 8 ]; then
            warn "⚠️ Low memory detected: ${TOTAL_MEM}GB (recommended: 8GB+)"
        else
            log "✅ Memory: ${TOTAL_MEM}GB"
        fi
    fi
    
    # Check disk space
    AVAILABLE_SPACE=$(df -BG . | awk 'NR==2 {print $4}' | sed 's/G//')
    if [ "$AVAILABLE_SPACE" -lt 20 ]; then
        warn "⚠️ Low disk space: ${AVAILABLE_SPACE}GB (recommended: 20GB+)"
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
    log "📁 Setting up astron-agent repository..."
    
    # Check if we're already in astron-agent directory
    if [[ $(basename "$PWD") == "astron-agent" ]]; then
        log "✅ Already in astron-agent directory"
    else
        # Check if astron-agent directory exists
        if [ -d "astron-agent" ]; then
            log "📁 Found existing astron-agent directory"
            cd astron-agent
        else
            log "📥 Cloning astron-agent repository..."
            git clone https://github.com/Zeeeepa/astron-agent.git
            cd astron-agent
        fi
    fi
    
    # Update repository
    log "🔄 Updating repository..."
    git fetch origin
    git pull origin main || git pull origin master || warn "Could not update repository"
    
    success "✅ Repository setup completed"
}

# ============================================================================
# CASDOOR DEPLOYMENT (OPTIONAL)
# ============================================================================

deploy_casdoor() {
    if [ "$ENABLE_CASDOOR" = false ]; then
        log "⏭️ Skipping Casdoor deployment"
        return
    fi
    
    log "🔐 Deploying Casdoor authentication service..."
    
    if [ -d "docker/casdoor" ]; then
        cd docker/casdoor
        
        # Create configuration if not exists
        if [ ! -f "conf/app.conf" ]; then
            mkdir -p conf logs
            cat > conf/app.conf << 'EOF'
appname = casdoor
httpport = 8000
runmode = prod
copyrequestbody = true
driverName = mysql
dataSourceName = casdoor:casdoor123@tcp(mysql:3306)/casdoor?charset=utf8
dbName = casdoor
tableNamePrefix = 
showSql = false
redisEndpoint = 
defaultStorageProvider = 
isCloudIntranet = false
authState = "casdoor"
socks5Proxy = ""
verificationCodeTimeout = 10
initScore = 2000
logPostOnly = true
origin = 
staticBaseUrl = "https://cdn.casbin.org"
isDemoMode = false
batchSize = 100
enableGzip = true
ldapServerPort = 389
radiusServerPort = 1812
radiusSecret = "secret"
quota = {"organization": -1, "user": -1, "application": -1, "provider": -1}
logConfig = {"filename": "logs/casdoor.log", "maxdays":99999, "perm":"0770"}
initDataFile = "./init_data.json"
frontendBaseDir = "../web"
EOF
        fi
        
        # Start Casdoor
        docker-compose up -d
        
        # Wait for service to be ready
        log "⏳ Waiting for Casdoor to be ready..."
        for i in {1..30}; do
            if curl -s http://localhost:8000 > /dev/null; then
                success "✅ Casdoor is ready at http://localhost:8000"
                break
            fi
            sleep 2
        done
        
        cd ../..
    else
        warn "⚠️ Casdoor configuration not found, skipping"
    fi
}

# ============================================================================
# RAGFLOW DEPLOYMENT (OPTIONAL)
# ============================================================================

deploy_ragflow() {
    if [ "$ENABLE_RAGFLOW" = false ]; then
        log "⏭️ Skipping RagFlow deployment"
        return
    fi
    
    log "🧠 Deploying RagFlow knowledge base service..."
    
    if [ -d "docker/ragflow" ]; then
        cd docker/ragflow
        
        # Copy environment file if exists
        if [ -f ".env.example" ]; then
            cp .env.example .env
        fi
        
        # Start RagFlow
        docker-compose up -d
        
        # Wait for service to be ready
        log "⏳ Waiting for RagFlow to be ready..."
        for i in {1..60}; do
            if curl -s http://localhost:9380 > /dev/null; then
                success "✅ RagFlow is ready at http://localhost:9380"
                break
            fi
            sleep 5
        done
        
        cd ../..
    else
        warn "⚠️ RagFlow configuration not found, skipping"
    fi
}

# ============================================================================
# ASTRON-AGENT CORE DEPLOYMENT
# ============================================================================

deploy_astron_agent() {
    log "🚀 Deploying astron-agent core services..."
    
    # Navigate to Docker directory
    if [ -d "docker/astronAgent" ]; then
        cd docker/astronAgent
    elif [ -d "docker" ]; then
        cd docker
    else
        error "❌ Docker configuration directory not found"
    fi
    
    # Setup environment file
    if [ -f ".env.example" ]; then
        if [ ! -f ".env" ]; then
            log "📝 Creating environment configuration..."
            cp .env.example .env
        fi
    else
        log "📝 Creating default environment configuration..."
        cat > .env << 'EOF'
# PostgreSQL Configuration
POSTGRES_USER=spark
POSTGRES_PASSWORD=spark123
POSTGRES_DB=sparkdb_manager

# MySQL Configuration
MYSQL_ROOT_PASSWORD=root123
MYSQL_DATABASE=astron_console

# Redis Configuration
REDIS_PASSWORD=redis123

# MinIO Configuration
MINIO_ROOT_USER=minioadmin
MINIO_ROOT_PASSWORD=minioadmin123

# Network Configuration
NETWORK_SUBNET=172.40.0.0/16

# Service Ports
CORE_TENANT_PORT=5052
CORE_MEMORY_PORT=7990
CORE_LINK_PORT=18888
CORE_AITOOLS_PORT=18668
CORE_AGENT_PORT=17870
CORE_KNOWLEDGE_PORT=20010
CORE_WORKFLOW_PORT=7880
CONSOLE_FRONTEND_PORT=1881
CONSOLE_HUB_PORT=8080

# External Service Integration
RAGFLOW_BASE_URL=http://localhost:9380
RAGFLOW_API_TOKEN=ragflow-your-api-token-here
RAGFLOW_TIMEOUT=60
EOF
    fi
    
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
    
    log "🚀 Starting astron-agent services..."
    docker-compose up -d "${COMPOSE_ARGS[@]}"
    
    success "✅ astron-agent services deployed"
    
    # Go back to root directory
    cd ../..
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
        "http://localhost:1881:Console Frontend"
        "http://localhost:8080:Console Hub API"
        "http://localhost:17870:Agent Core"
        "http://localhost:7880:Workflow Service"
        "http://localhost:20010:Knowledge Service"
    )
    
    # Add optional services
    if [ "$ENABLE_CASDOOR" = true ]; then
        SERVICES+=("http://localhost:8000:Casdoor Auth")
    fi
    
    if [ "$ENABLE_RAGFLOW" = true ]; then
        SERVICES+=("http://localhost:9380:RagFlow")
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
    docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" | grep -E "(astron|casdoor|ragflow)" || true
    
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
# ASTRON-AGENT ALIASES
# ============================================================================
alias astron-status='cd ~/astron-agent && docker-compose -f docker/astronAgent/docker-compose.yml ps'
alias astron-logs='cd ~/astron-agent && docker-compose -f docker/astronAgent/docker-compose.yml logs -f'
alias astron-start='cd ~/astron-agent && docker-compose -f docker/astronAgent/docker-compose.yml up -d'
alias astron-stop='cd ~/astron-agent && docker-compose -f docker/astronAgent/docker-compose.yml down'
alias astron-restart='cd ~/astron-agent && docker-compose -f docker/astronAgent/docker-compose.yml restart'
alias astron-console='echo "🌐 Console Frontend: http://localhost:1881" && echo "🔧 Console Hub API: http://localhost:8080"'
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
    echo "                    🚀 ASTRON-AGENT DEPLOYMENT 🚀"
    echo "                   Enterprise AI Agent Platform"
    echo "============================================================================"
    echo -e "${NC}"
    echo ""
    echo -e "${CYAN}This script will:${NC}"
    echo "  ✅ Check system requirements"
    echo "  ✅ Install Docker and dependencies"
    echo "  ✅ Setup astron-agent repository"
    if [ "$ENABLE_CASDOOR" = true ]; then
        echo "  ✅ Deploy Casdoor authentication service"
    fi
    if [ "$ENABLE_RAGFLOW" = true ]; then
        echo "  ✅ Deploy RagFlow knowledge base service"
    fi
    echo "  ✅ Deploy astron-agent core services"
    echo "  ✅ Set up shell aliases"
    echo "  ✅ Verify deployment"
    echo ""
    echo -e "${YELLOW}⚠️ This will download Docker images (~3-5GB)${NC}"
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
    log "🚀 Starting astron-agent deployment..."
    
    # Execute deployment steps
    if [ "$SKIP_DEPS_CHECK" = false ]; then
        check_system_requirements
    fi
    install_docker
    setup_repository
    deploy_casdoor
    deploy_ragflow
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
    echo "   🖥️  Console Frontend: http://localhost:1881"
    echo "   🔧 Console Hub API: http://localhost:8080"
    echo "   🤖 Agent Core: http://localhost:17870"
    echo "   🔄 Workflow Service: http://localhost:7880"
    echo "   🧠 Knowledge Service: http://localhost:20010"
    
    if [ "$ENABLE_CASDOOR" = true ]; then
        echo "   🔐 Casdoor Auth: http://localhost:8000"
    fi
    
    if [ "$ENABLE_RAGFLOW" = true ]; then
        echo "   📚 RagFlow: http://localhost:9380"
    fi
    
    echo ""
    echo -e "${CYAN}🛠️ Management Commands:${NC}"
    echo "   astron-status    - Check service status"
    echo "   astron-logs      - View service logs"
    echo "   astron-start     - Start all services"
    echo "   astron-stop      - Stop all services"
    echo "   astron-restart   - Restart all services"
    echo "   astron-console   - Show console URLs"
    echo ""
    echo -e "${YELLOW}💡 Tip: Run 'source ~/.bashrc' to enable aliases${NC}"
    echo ""
}

# Run main function
main "$@"
