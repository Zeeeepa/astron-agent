#!/usr/bin/env bash

#############################################################################
# Astron Agent - WSL2 Setup Script (Enhanced for Docker Deployment)
#############################################################################
# This script prepares and configures the Astron Agent platform for deployment
# Usage: ./setup.sh
#############################################################################

set -e  # Exit on error
set -o pipefail  # Catch pipe errors

# Color output helpers
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m' # No Color

# Helper functions
print_header() {
    echo -e "\n${CYAN}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${NC}  ${BLUE}$1${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${NC}\n"
}

print_success() {
    echo -e "${GREEN}✓${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
}

print_info() {
    echo -e "${CYAN}ℹ${NC} $1"
}

print_step() {
    echo -e "${MAGENTA}➜${NC} $1"
}

# Show banner
clear
echo -e "${CYAN}"
echo "    ╔═══════════════════════════════════════════════════════════╗"
echo "    ║                                                           ║"
echo "    ║            Astron Agent - Setup Script                   ║"
echo "    ║                                                           ║"
echo "    ║         Enterprise AI Agent Development Platform          ║"
echo "    ║                                                           ║"
echo "    ╚═══════════════════════════════════════════════════════════╝"
echo -e "${NC}\n"

#############################################################################
# Detect repository root
#############################################################################

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
REPO_ROOT="${SCRIPT_DIR}"
DOCKER_DIR="${REPO_ROOT}/docker/astronAgent"

print_info "Script directory: ${SCRIPT_DIR}"
print_info "Repository root: ${REPO_ROOT}"
print_info "Docker directory: ${DOCKER_DIR}"

if [ ! -d "${DOCKER_DIR}" ]; then
    print_error "Docker directory not found: ${DOCKER_DIR}"
    print_info "Please run this script from the repository root"
    exit 1
fi

#############################################################################
# Check WSL2 Environment
#############################################################################

check_wsl2() {
    print_header "Checking WSL2 Environment"
    
    if [ ! -f /proc/sys/fs/binfmt_misc/WSLInterop ]; then
        print_warning "Not running in WSL2 environment"
        print_info "This script is optimized for WSL2 but can work in other Linux environments"
        echo ""
        read -p "Do you want to continue? (y/N) " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            print_info "Setup cancelled"
            exit 0
        fi
    else
        print_success "Running in WSL2"
    fi
}

#############################################################################
# Check System Requirements
#############################################################################

check_system_resources() {
    print_header "Checking System Resources"
    
    # Check RAM
    TOTAL_RAM=$(free -g | awk '/^Mem:/{print $2}')
    print_info "Total RAM: ${TOTAL_RAM} GB"
    
    if [ "${TOTAL_RAM}" -lt 8 ]; then
        print_warning "Recommended RAM: 8GB+, Available: ${TOTAL_RAM}GB"
        print_warning "The system may experience performance issues with all services running"
    else
        print_success "RAM: ${TOTAL_RAM}GB (Sufficient)"
    fi
    
    # Check CPU
    CPU_CORES=$(nproc)
    print_info "CPU cores: ${CPU_CORES}"
    
    if [ "${CPU_CORES}" -lt 4 ]; then
        print_warning "Recommended CPU: 4+ cores, Available: ${CPU_CORES} cores"
    else
        print_success "CPU cores: ${CPU_CORES} (Sufficient)"
    fi
    
    # Check disk space
    AVAILABLE_DISK=$(df -BG "${DOCKER_DIR}" | awk 'NR==2 {print $4}' | sed 's/G//')
    print_info "Available disk space: ${AVAILABLE_DISK}GB"
    
    if [ "${AVAILABLE_DISK}" -lt 50 ]; then
        print_warning "Recommended disk: 50GB+, Available: ${AVAILABLE_DISK}GB"
    else
        print_success "Disk space: ${AVAILABLE_DISK}GB (Sufficient)"
    fi
}

#############################################################################
# Check Docker Installation
#############################################################################

check_docker() {
    print_header "Checking Docker Installation"
    
    if ! command -v docker &> /dev/null; then
        print_error "Docker is not installed"
        print_info "Please install Docker first: https://docs.docker.com/engine/install/"
        exit 1
    fi
    print_success "Docker found: $(docker --version)"
    
    # Check Docker Compose
    if ! command -v docker-compose &> /dev/null && ! docker compose version &> /dev/null; then
        print_error "Docker Compose is not installed"
        print_info "Please install Docker Compose: https://docs.docker.com/compose/install/"
        exit 1
    fi
    
    if command -v docker-compose &> /dev/null; then
        print_success "Docker Compose found: $(docker-compose --version)"
        COMPOSE_CMD="docker-compose"
    else
        print_success "Docker Compose found: $(docker compose version)"
        COMPOSE_CMD="docker compose"
    fi
    export COMPOSE_CMD
    
    # Check Docker daemon
    if ! docker info &> /dev/null; then
        print_error "Docker daemon is not running"
        print_info "Please start Docker service"
        exit 1
    fi
    print_success "Docker daemon is running"
    
    # Check Docker permissions
    if ! docker ps &> /dev/null 2>&1; then
        print_warning "Current user may not have Docker permissions"
        print_info "You might need to run: sudo usermod -aG docker $USER"
        print_info "Then log out and log back in"
    else
        print_success "Docker permissions OK"
    fi
}

#############################################################################
# Check Port Availability
#############################################################################

check_ports() {
    print_header "Checking Port Availability"
    
    PORTS_TO_CHECK=(80 3306 5432 6379 9000 9001 9092 9200)
    PORT_NAMES=("HTTP/Nginx" "MySQL" "PostgreSQL" "Redis" "MinIO" "MinIO Console" "Kafka" "Elasticsearch")
    
    PORTS_IN_USE=()
    
    for i in "${!PORTS_TO_CHECK[@]}"; do
        PORT="${PORTS_TO_CHECK[$i]}"
        NAME="${PORT_NAMES[$i]}"
        
        if lsof -Pi :${PORT} -sTCP:LISTEN -t >/dev/null 2>&1 || netstat -tuln 2>/dev/null | grep -q ":${PORT} "; then
            print_warning "Port ${PORT} (${NAME}) is already in use"
            PORTS_IN_USE+=("${PORT}")
        else
            print_success "Port ${PORT} (${NAME}) is available"
        fi
    done
    
    if [ ${#PORTS_IN_USE[@]} -gt 0 ]; then
        echo ""
        print_warning "Some ports are already in use. This may cause conflicts."
        print_info "You can either:"
        print_info "  1. Stop services using those ports"
        print_info "  2. Modify port mappings in .env file"
        echo ""
        read -p "Do you want to continue anyway? (y/N) " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            print_info "Setup cancelled"
            exit 0
        fi
    fi
}

#############################################################################
# Configure Environment
#############################################################################

setup_environment() {
    print_header "Configuring Environment"
    
    cd "${DOCKER_DIR}"
    
    # Check if .env exists
    if [ -f ".env" ]; then
        print_warning ".env file already exists"
        echo ""
        read -p "Do you want to recreate it? (will backup existing) (y/N) " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            BACKUP_NAME=".env.backup.$(date +%Y%m%d_%H%M%S)"
            cp .env "${BACKUP_NAME}"
            print_success "Backed up existing .env to ${BACKUP_NAME}"
            cp .env.example .env
            print_success "Created new .env from .env.example"
        else
            print_info "Keeping existing .env file"
        fi
    else
        cp .env.example .env
        print_success "Created .env from .env.example"
    fi
    
    print_info "Please review and customize the .env file with your settings:"
    print_info "  - Database passwords"
    print_info "  - MinIO credentials"
    print_info "  - Casdoor configuration (if using)"
    print_info "  - API keys and secrets"
    echo ""
}

#############################################################################
# Build English Frontend
#############################################################################

build_frontend_english() {
    print_header "Building Frontend (English Default)"
    
    # Check if i18n is configured for English
    if [ -f "${REPO_ROOT}/console/frontend/src/i18n/index.ts" ]; then
        if grep -q "fallbackLng: 'en'" "${REPO_ROOT}/console/frontend/src/i18n/index.ts"; then
            print_success "i18n configured for English default"
        else
            print_warning "i18n not configured for English - UI will default to Chinese"
            print_info "To enable English default, modify console/frontend/src/i18n/index.ts"
        fi
    fi
    
    print_info "Frontend will be built as part of the Docker image"
    print_success "Frontend configuration complete"
}

#############################################################################
# Pull Docker Images
#############################################################################

pull_images() {
    print_header "Pulling Docker Images"
    
    cd "${DOCKER_DIR}"
    
    print_info "This may take 10-15 minutes depending on your connection..."
    echo ""
    
    if ${COMPOSE_CMD} pull 2>&1 | tee /tmp/docker-pull.log; then
        print_success "All images pulled successfully"
    else
        print_error "Failed to pull some images"
        print_info "Check log: /tmp/docker-pull.log"
        print_warning "You can continue, but some services may not start"
        echo ""
        read -p "Do you want to continue? (y/N) " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    fi
}

#############################################################################
# Create Required Directories
#############################################################################

create_directories() {
    print_header "Creating Required Directories"
    
    cd "${DOCKER_DIR}"
    
    # Create log directories
    DIRS=(
        "config/tenant/logs"
        "config/database/logs"
        "config/rpa/logs"
        "config/link/logs"
        "config/aitools/logs"
        "config/agent/logs"
        "config/knowledge/logs"
        "config/workflow/logs"
        "nginx/logs"
    )
    
    for dir in "${DIRS[@]}"; do
        if [ ! -d "${dir}" ]; then
            mkdir -p "${dir}"
            print_success "Created directory: ${dir}"
        else
            print_info "Directory exists: ${dir}"
        fi
    done
}

#############################################################################
# Create Helper Scripts
#############################################################################

create_helper_scripts() {
    print_header "Creating Helper Scripts"
    
    # Note: start.sh is maintained as a separate file at repo root
    # We'll just verify it exists
    
    if [ -f "${REPO_ROOT}/start.sh" ]; then
        chmod +x "${REPO_ROOT}/start.sh"
        print_success "start.sh is ready"
    else
        print_warning "start.sh not found at repository root"
    fi
    
    # Create stop.sh
    cat > "${REPO_ROOT}/stop.sh" << 'EOF'
#!/usr/bin/env bash
cd "$(dirname "$0")/docker/astronAgent"
COMPOSE_CMD="docker-compose"
if ! command -v docker-compose &> /dev/null; then
    COMPOSE_CMD="docker compose"
fi
echo "Stopping all Astron Agent services..."
${COMPOSE_CMD} down
echo "✓ All services stopped"
EOF
    chmod +x "${REPO_ROOT}/stop.sh"
    print_success "Created stop.sh"
    
    # Create status.sh
    cat > "${REPO_ROOT}/status.sh" << 'EOF'
#!/usr/bin/env bash
cd "$(dirname "$0")/docker/astronAgent"
COMPOSE_CMD="docker-compose"
if ! command -v docker-compose &> /dev/null; then
    COMPOSE_CMD="docker compose"
fi
${COMPOSE_CMD} ps
EOF
    chmod +x "${REPO_ROOT}/status.sh"
    print_success "Created status.sh"
    
    # Create logs.sh
    cat > "${REPO_ROOT}/logs.sh" << 'EOF'
#!/usr/bin/env bash
cd "$(dirname "$0")/docker/astronAgent"
COMPOSE_CMD="docker-compose"
if ! command -v docker-compose &> /dev/null; then
    COMPOSE_CMD="docker compose"
fi
if [ -z "$1" ]; then
    ${COMPOSE_CMD} logs -f --tail=100
else
    ${COMPOSE_CMD} logs -f --tail=100 "$@"
fi
EOF
    chmod +x "${REPO_ROOT}/logs.sh"
    print_success "Created logs.sh"
}

#############################################################################
# Print Summary
#############################################################################

print_summary() {
    echo ""
    echo -e "${GREEN}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}  ✓ Setup Complete!${NC}"
    echo -e "${GREEN}═══════════════════════════════════════════════════════════════${NC}"
    echo ""
    echo -e "${CYAN}📋 Configuration Summary:${NC}"
    echo -e "   ${BLUE}•${NC} Docker directory: ${DOCKER_DIR}"
    echo -e "   ${BLUE}•${NC} Environment file: ${DOCKER_DIR}/.env"
    echo -e "   ${BLUE}•${NC} Docker Compose: ${COMPOSE_CMD}"
    echo ""
    echo -e "${CYAN}🚀 Next Steps:${NC}"
    echo ""
    echo -e "   ${YELLOW}1.${NC} Review and customize the environment configuration:"
    echo -e "      ${BLUE}vim ${DOCKER_DIR}/.env${NC}"
    echo ""
    echo -e "   ${YELLOW}2.${NC} Start all services:"
    echo -e "      ${BLUE}./start.sh${NC}"
    echo ""
    echo -e "   ${YELLOW}3.${NC} Access the console:"
    echo -e "      ${BLUE}http://localhost${NC}"
    echo ""
    echo -e "${CYAN}📚 Available Commands:${NC}"
    echo -e "   ${BLUE}•${NC} ./start.sh  - Start all services"
    echo -e "   ${BLUE}•${NC} ./stop.sh   - Stop all services"
    echo -e "   ${BLUE}•${NC} ./status.sh - Check service status"
    echo -e "   ${BLUE}•${NC} ./logs.sh   - View service logs"
    echo ""
    echo -e "${CYAN}📖 Documentation:${NC}"
    echo -e "   ${BLUE}•${NC} DEPLOYMENT_WSL2.md - Deployment guide"
    echo -e "   ${BLUE}•${NC} docker/DEPLOYMENT_GUIDE_zh.md - Chinese deployment guide"
    echo ""
    echo -e "${YELLOW}⚠${NC}  ${CYAN}Important Notes:${NC}"
    echo -e "   ${BLUE}•${NC} First startup may take 5-10 minutes"
    echo -e "   ${BLUE}•${NC} Services will wait for dependencies to be healthy"
    echo -e "   ${BLUE}•${NC} Check logs if services don't start: ${BLUE}./logs.sh${NC}"
    echo ""
}

#############################################################################
# Main Execution
#############################################################################

main() {
    check_wsl2
    check_system_resources
    check_docker
    check_ports
    setup_environment
    build_frontend_english
    create_directories
    pull_images
    create_helper_scripts
    print_summary
}

# Run main function
main

exit 0

