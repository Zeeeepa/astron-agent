#!/bin/bash

# ============================================================================
# QUICK SETUP SCRIPT
# One-command setup for astron-agent + astron-rpa
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
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ============================================================================
# BANNER
# ============================================================================

show_banner() {
    clear
    echo -e "${PURPLE}"
    echo "============================================================================"
    echo "                    🚀 ASTRON UNIFIED QUICK SETUP 🚀"
    echo "                   astron-agent + astron-rpa Integration"
    echo "============================================================================"
    echo -e "${NC}"
    echo ""
    echo -e "${CYAN}This script will:${NC}"
    echo -e "  ✅ Check system requirements"
    echo -e "  ✅ Install dependencies"
    echo -e "  ✅ Configure environment"
    echo -e "  ✅ Deploy both platforms"
    echo -e "  ✅ Verify installation"
    echo ""
    echo -e "${YELLOW}⚠️ This will download and install Docker images (~5GB)${NC}"
    echo -e "${YELLOW}⚠️ Ensure you have sufficient disk space and internet connection${NC}"
    echo ""
}

# ============================================================================
# SYSTEM CHECK
# ============================================================================

check_system() {
    echo -e "${BLUE}🔍 Checking system requirements...${NC}"
    
    # Check OS
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        echo -e "  ✅ Operating System: Linux"
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        echo -e "  ✅ Operating System: macOS"
    else
        echo -e "  ❌ Unsupported operating system: $OSTYPE"
        exit 1
    fi
    
    # Check architecture
    local arch=$(uname -m)
    if [[ "$arch" == "x86_64" ]] || [[ "$arch" == "amd64" ]]; then
        echo -e "  ✅ Architecture: $arch"
    elif [[ "$arch" == "arm64" ]] || [[ "$arch" == "aarch64" ]]; then
        echo -e "  ✅ Architecture: $arch (ARM)"
    else
        echo -e "  ❌ Unsupported architecture: $arch"
        exit 1
    fi
    
    # Check memory
    local memory_gb
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        memory_gb=$(free -g | awk 'NR==2{print $2}')
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        memory_gb=$(( $(sysctl -n hw.memsize) / 1024 / 1024 / 1024 ))
    fi
    
    if [ "$memory_gb" -ge 8 ]; then
        echo -e "  ✅ Memory: ${memory_gb}GB"
    else
        echo -e "  ⚠️ Memory: ${memory_gb}GB (8GB+ recommended)"
    fi
    
    # Check disk space
    local disk_gb=$(df -BG / | awk 'NR==2{print $4}' | sed 's/G//')
    if [ "$disk_gb" -ge 50 ]; then
        echo -e "  ✅ Disk Space: ${disk_gb}GB available"
    else
        echo -e "  ⚠️ Disk Space: ${disk_gb}GB available (50GB+ recommended)"
    fi
    
    echo ""
}

# ============================================================================
# DEPENDENCY INSTALLATION
# ============================================================================

install_docker() {
    echo -e "${BLUE}🐳 Installing Docker...${NC}"
    
    if command -v docker &> /dev/null; then
        echo -e "  ✅ Docker already installed: $(docker --version)"
        return 0
    fi
    
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        # Linux installation
        if command -v apt-get &> /dev/null; then
            # Ubuntu/Debian
            curl -fsSL https://get.docker.com -o get-docker.sh
            sudo sh get-docker.sh
            sudo usermod -aG docker $USER
            rm get-docker.sh
        elif command -v yum &> /dev/null; then
            # RHEL/CentOS
            sudo yum install -y yum-utils
            sudo yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
            sudo yum install -y docker-ce docker-ce-cli containerd.io
            sudo systemctl start docker
            sudo systemctl enable docker
            sudo usermod -aG docker $USER
        fi
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS installation
        echo -e "  ℹ️ Please install Docker Desktop for Mac from:"
        echo -e "     https://docs.docker.com/desktop/mac/install/"
        echo -e "  ⏳ Waiting for Docker installation..."
        
        while ! command -v docker &> /dev/null; do
            sleep 5
            echo -n "."
        done
        echo ""
    fi
    
    echo -e "  ✅ Docker installed successfully"
}

install_docker_compose() {
    echo -e "${BLUE}🔧 Installing Docker Compose...${NC}"
    
    if docker compose version &> /dev/null; then
        echo -e "  ✅ Docker Compose (plugin) already available"
        return 0
    fi
    
    if command -v docker-compose &> /dev/null; then
        echo -e "  ✅ Docker Compose already installed: $(docker-compose --version)"
        return 0
    fi
    
    # Install Docker Compose
    local compose_version="2.20.2"
    local arch=$(uname -m)
    
    if [[ "$arch" == "aarch64" ]] || [[ "$arch" == "arm64" ]]; then
        arch="aarch64"
    else
        arch="x86_64"
    fi
    
    sudo curl -L "https://github.com/docker/compose/releases/download/v${compose_version}/docker-compose-$(uname -s)-${arch}" -o /usr/local/bin/docker-compose
    sudo chmod +x /usr/local/bin/docker-compose
    
    echo -e "  ✅ Docker Compose installed successfully"
}

install_dependencies() {
    echo -e "${BLUE}📦 Installing system dependencies...${NC}"
    
    local deps_to_install=()
    
    # Check for required tools
    if ! command -v curl &> /dev/null; then
        deps_to_install+=("curl")
    fi
    
    if ! command -v wget &> /dev/null; then
        deps_to_install+=("wget")
    fi
    
    if ! command -v git &> /dev/null; then
        deps_to_install+=("git")
    fi
    
    if ! command -v jq &> /dev/null; then
        deps_to_install+=("jq")
    fi
    
    if [ ${#deps_to_install[@]} -eq 0 ]; then
        echo -e "  ✅ All dependencies already installed"
        return 0
    fi
    
    echo -e "  📥 Installing: ${deps_to_install[*]}"
    
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        if command -v apt-get &> /dev/null; then
            sudo apt-get update
            sudo apt-get install -y "${deps_to_install[@]}"
        elif command -v yum &> /dev/null; then
            sudo yum install -y "${deps_to_install[@]}"
        elif command -v dnf &> /dev/null; then
            sudo dnf install -y "${deps_to_install[@]}"
        fi
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        if command -v brew &> /dev/null; then
            brew install "${deps_to_install[@]}"
        else
            echo -e "  ⚠️ Homebrew not found. Please install manually: ${deps_to_install[*]}"
        fi
    fi
    
    echo -e "  ✅ Dependencies installed"
}

# ============================================================================
# CONFIGURATION
# ============================================================================

configure_environment() {
    echo -e "${BLUE}⚙️ Configuring environment...${NC}"
    
    # Create directories
    mkdir -p "${SCRIPT_DIR}/logs"
    mkdir -p "${SCRIPT_DIR}/backups"
    mkdir -p "${SCRIPT_DIR}/data"
    
    # Generate random passwords if not set
    if [ ! -f "${SCRIPT_DIR}/.env.unified" ]; then
        echo -e "  📝 Creating environment configuration..."
        
        # Generate secure passwords
        local mysql_pass=$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-25)
        local postgres_pass=$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-25)
        local redis_pass=$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-25)
        local minio_pass=$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-25)
        local rpa_key=$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-25)
        local rpa_secret=$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-25)
        
        # Update environment file with generated passwords
        sed -i.bak \
            -e "s/UnifiedRoot123!/${mysql_pass}/g" \
            -e "s/SparkDB123!/${postgres_pass}/g" \
            -e "s/UnifiedRedis123!/${redis_pass}/g" \
            -e "s/UnifiedMinio123!/${minio_pass}/g" \
            -e "s/unified-rpa-api-key-2024/${rpa_key}/g" \
            -e "s/unified-rpa-secret-key-2024/${rpa_secret}/g" \
            "${SCRIPT_DIR}/.env.unified"
        
        echo -e "  ✅ Secure passwords generated"
    else
        echo -e "  ✅ Environment configuration already exists"
    fi
    
    # Generate SSL certificates
    if [ ! -f "${SCRIPT_DIR}/nginx/ssl/cert.pem" ]; then
        echo -e "  🔐 Generating SSL certificates..."
        mkdir -p "${SCRIPT_DIR}/nginx/ssl"
        
        openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
            -keyout "${SCRIPT_DIR}/nginx/ssl/key.pem" \
            -out "${SCRIPT_DIR}/nginx/ssl/cert.pem" \
            -subj "/C=US/ST=State/L=City/O=Astron/CN=localhost" \
            2>/dev/null
        
        echo -e "  ✅ SSL certificates generated"
    else
        echo -e "  ✅ SSL certificates already exist"
    fi
    
    echo ""
}

# ============================================================================
# DEPLOYMENT
# ============================================================================

deploy_system() {
    echo -e "${BLUE}🚀 Deploying unified system...${NC}"
    echo ""
    
    # Make scripts executable
    chmod +x "${SCRIPT_DIR}/deploy.sh"
    chmod +x "${SCRIPT_DIR}/scripts/"*.sh
    
    # Run deployment
    echo -e "${CYAN}Starting deployment process...${NC}"
    "${SCRIPT_DIR}/deploy.sh" --skip-deps
    
    echo ""
}

# ============================================================================
# VERIFICATION
# ============================================================================

verify_deployment() {
    echo -e "${BLUE}✅ Verifying deployment...${NC}"
    
    # Wait for services to start
    echo -e "  ⏳ Waiting for services to initialize..."
    sleep 30
    
    # Run health check
    if "${SCRIPT_DIR}/scripts/health-check.sh" --services > /dev/null 2>&1; then
        echo -e "  ✅ All services are healthy"
    else
        echo -e "  ⚠️ Some services may still be starting"
        echo -e "     Run './scripts/health-check.sh' to check status"
    fi
    
    echo ""
}

# ============================================================================
# SUCCESS MESSAGE
# ============================================================================

show_success() {
    echo -e "${GREEN}"
    echo "============================================================================"
    echo "                    🎉 DEPLOYMENT SUCCESSFUL! 🎉"
    echo "============================================================================"
    echo -e "${NC}"
    echo ""
    echo -e "${CYAN}🌐 Access your platforms:${NC}"
    echo -e "   🤖 RPA Platform:      ${GREEN}http://localhost/rpa/${NC}"
    echo -e "   🧠 Agent Console:     ${GREEN}http://localhost/agent/${NC}"
    echo -e "   🔐 Authentication:    ${GREEN}http://localhost/auth/${NC}"
    echo -e "   💾 MinIO Console:     ${GREEN}http://localhost/minio/${NC}"
    echo ""
    echo -e "${CYAN}🔧 Management commands:${NC}"
    echo -e "   📊 Health check:      ${GREEN}./scripts/health-check.sh${NC}"
    echo -e "   🛠️ Manage services:    ${GREEN}./scripts/manage-services.sh status${NC}"
    echo -e "   📋 View logs:         ${GREEN}./scripts/manage-services.sh logs${NC}"
    echo -e "   ⏹️ Stop services:      ${GREEN}./scripts/manage-services.sh stop${NC}"
    echo ""
    echo -e "${CYAN}📚 Documentation:${NC}"
    echo -e "   📖 Full guide:        ${GREEN}README-deployment.md${NC}"
    echo -e "   🔧 Configuration:     ${GREEN}.env.unified${NC}"
    echo ""
    echo -e "${YELLOW}⚠️ Important notes:${NC}"
    echo -e "   • Default passwords have been generated and saved in .env.unified"
    echo -e "   • Change default passwords for production use"
    echo -e "   • Configure SSL certificates for HTTPS access"
    echo -e "   • Set up regular backups with './scripts/manage-services.sh backup'"
    echo ""
    echo -e "${GREEN}🎊 Happy coding with astron-agent + astron-rpa! 🎊${NC}"
    echo ""
}

# ============================================================================
# ERROR HANDLING
# ============================================================================

handle_error() {
    echo -e "${RED}"
    echo "============================================================================"
    echo "                    ❌ SETUP FAILED ❌"
    echo "============================================================================"
    echo -e "${NC}"
    echo ""
    echo -e "${YELLOW}Something went wrong during setup. Here's what you can do:${NC}"
    echo ""
    echo -e "${CYAN}1. Check the error message above${NC}"
    echo -e "${CYAN}2. Ensure you have sufficient system resources${NC}"
    echo -e "${CYAN}3. Verify internet connectivity${NC}"
    echo -e "${CYAN}4. Try running individual steps manually:${NC}"
    echo -e "   • Check system: Run this script with --check-only"
    echo -e "   • Install deps: Run this script with --deps-only"
    echo -e "   • Deploy: Run ./deploy.sh manually"
    echo ""
    echo -e "${CYAN}5. Get help:${NC}"
    echo -e "   • Check logs: ./scripts/manage-services.sh logs"
    echo -e "   • Health check: ./scripts/health-check.sh"
    echo -e "   • Read documentation: README-deployment.md"
    echo ""
    exit 1
}

# ============================================================================
# COMMAND LINE OPTIONS
# ============================================================================

show_help() {
    echo "Quick Setup Script for astron-agent + astron-rpa"
    echo ""
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -h, --help          Show this help message"
    echo "  --check-only        Only check system requirements"
    echo "  --deps-only         Only install dependencies"
    echo "  --no-verify         Skip deployment verification"
    echo "  --minimal           Minimal installation (skip optional components)"
    echo ""
    echo "Examples:"
    echo "  $0                  # Full setup"
    echo "  $0 --check-only     # Check system requirements only"
    echo "  $0 --deps-only      # Install dependencies only"
}

# ============================================================================
# MAIN EXECUTION
# ============================================================================

main() {
    # Set error handler
    trap handle_error ERR
    
    # Parse arguments
    local check_only=false
    local deps_only=false
    local no_verify=false
    local minimal=false
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_help
                exit 0
                ;;
            --check-only)
                check_only=true
                shift
                ;;
            --deps-only)
                deps_only=true
                shift
                ;;
            --no-verify)
                no_verify=true
                shift
                ;;
            --minimal)
                minimal=true
                shift
                ;;
            *)
                echo "Unknown option: $1"
                show_help
                exit 1
                ;;
        esac
    done
    
    # Show banner
    show_banner
    
    # Get user confirmation
    if [ "$check_only" = false ] && [ "$deps_only" = false ]; then
        read -p "Do you want to proceed with the installation? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            echo "Installation cancelled."
            exit 0
        fi
        echo ""
    fi
    
    # Execute steps
    check_system
    
    if [ "$check_only" = true ]; then
        echo -e "${GREEN}✅ System check completed successfully!${NC}"
        exit 0
    fi
    
    install_docker
    install_docker_compose
    install_dependencies
    
    if [ "$deps_only" = true ]; then
        echo -e "${GREEN}✅ Dependencies installed successfully!${NC}"
        echo -e "${CYAN}Next step: Run '$0' to complete the setup${NC}"
        exit 0
    fi
    
    configure_environment
    deploy_system
    
    if [ "$no_verify" = false ]; then
        verify_deployment
    fi
    
    show_success
}

# Execute main function
main "$@"

