#!/usr/bin/env bash
###############################################################################
# Astron Agent - WSL2 Setup Script
# Purpose: Prepares WSL2 environment for Astron Agent deployment
# Usage: ./setup.sh
###############################################################################

set -e  # Exit on error

# Color definitions for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Configuration
MIN_RAM_GB=8
MIN_DISK_GB=30
REQUIRED_PORTS=(80 3306 5432 6379 9092 9200 9000)
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOCKER_COMPOSE_DIR="${PROJECT_DIR}/docker/astronAgent"

###############################################################################
# Helper Functions
###############################################################################

print_header() {
    echo -e "\n${CYAN}╔════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${NC}  ${BLUE}$1${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════════════════════════════╝${NC}\n"
}

print_success() {
    echo -e "${GREEN}✓${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

print_info() {
    echo -e "${BLUE}ℹ${NC} $1"
}

prompt_continue() {
    read -p "Continue? (y/n): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_error "Setup cancelled by user"
        exit 1
    fi
}

###############################################################################
# Pre-flight Checks
###############################################################################

check_wsl2() {
    print_header "Checking WSL2 Environment"
    
    if [ ! -f /proc/sys/fs/binfmt_misc/WSLInterop ]; then
        print_error "This script must be run inside WSL2"
        exit 1
    fi
    print_success "Running in WSL2"
    
    # Get WSL version info
    if command -v wsl.exe &> /dev/null; then
        print_info "WSL Version: $(wsl.exe --version 2>/dev/null | grep 'WSL version' || echo 'WSL2')"
    fi
}

check_distro() {
    print_header "Checking Linux Distribution"
    
    if [ ! -f /etc/os-release ]; then
        print_error "Cannot determine Linux distribution"
        exit 1
    fi
    
    source /etc/os-release
    print_success "Distribution: ${NAME} ${VERSION}"
    
    if [[ ! "$ID" =~ ^(ubuntu|debian)$ ]]; then
        print_warning "This script is tested on Ubuntu/Debian. Your distro: ${ID}"
        print_info "Installation may require manual adjustments"
        prompt_continue
    fi
}

check_system_resources() {
    print_header "Checking System Resources"
    
    # Check RAM
    total_ram_kb=$(grep MemTotal /proc/meminfo | awk '{print $2}')
    total_ram_gb=$((total_ram_kb / 1024 / 1024))
    
    if [ $total_ram_gb -lt $MIN_RAM_GB ]; then
        print_warning "RAM: ${total_ram_gb}GB (Recommended: ≥${MIN_RAM_GB}GB)"
        print_info "Astron Agent may run slowly with limited RAM"
    else
        print_success "RAM: ${total_ram_gb}GB"
    fi
    
    # Check disk space
    available_disk_gb=$(df -BG "${PROJECT_DIR}" | tail -1 | awk '{print $4}' | sed 's/G//')
    
    if [ $available_disk_gb -lt $MIN_DISK_GB ]; then
        print_error "Disk Space: ${available_disk_gb}GB available (Required: ≥${MIN_DISK_GB}GB)"
        exit 1
    else
        print_success "Disk Space: ${available_disk_gb}GB available"
    fi
}

check_systemd() {
    print_header "Checking systemd"
    
    if ! ps -p 1 -o comm= | grep -q systemd; then
        print_warning "systemd is not running as PID 1"
        print_info "Enabling systemd in WSL2..."
        
        # Create or update /etc/wsl.conf
        if [ ! -f /etc/wsl.conf ]; then
            sudo tee /etc/wsl.conf > /dev/null <<EOF
[boot]
systemd=true
EOF
            print_success "Created /etc/wsl.conf with systemd enabled"
        else
            if ! grep -q "systemd=true" /etc/wsl.conf; then
                sudo bash -c 'echo -e "\n[boot]\nsystemd=true" >> /etc/wsl.conf'
                print_success "Added systemd to /etc/wsl.conf"
            fi
        fi
        
        print_warning "Please restart WSL2 to enable systemd:"
        print_info "1. Open PowerShell as Administrator"
        print_info "2. Run: wsl --shutdown"
        print_info "3. Restart your WSL2 terminal"
        print_info "4. Run this script again"
        exit 0
    else
        print_success "systemd is running"
    fi
}

###############################################################################
# Docker Installation
###############################################################################

install_docker() {
    print_header "Installing Docker"
    
    # Check if Docker is already installed
    if command -v docker &> /dev/null; then
        docker_version=$(docker --version | awk '{print $3}' | tr -d ',')
        print_success "Docker is already installed (version: ${docker_version})"
        return 0
    fi
    
    print_info "Installing Docker Engine..."
    
    # Update package index
    sudo apt-get update -qq
    
    # Install prerequisites
    sudo apt-get install -y -qq \
        ca-certificates \
        curl \
        gnupg \
        lsb-release
    
    # Add Docker's official GPG key
    sudo mkdir -p /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | \
        sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    
    # Set up the repository
    echo \
      "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
      $(lsb_release -cs) stable" | \
      sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
    
    # Install Docker Engine
    sudo apt-get update -qq
    sudo apt-get install -y -qq \
        docker-ce \
        docker-ce-cli \
        containerd.io \
        docker-buildx-plugin \
        docker-compose-plugin
    
    print_success "Docker Engine installed successfully"
}

configure_docker() {
    print_header "Configuring Docker"
    
    # Start Docker service
    sudo systemctl enable docker --now
    sleep 2
    
    if ! sudo systemctl is-active --quiet docker; then
        print_error "Failed to start Docker service"
        exit 1
    fi
    print_success "Docker service is running"
    
    # Add user to docker group
    if ! groups | grep -q docker; then
        sudo usermod -aG docker "$USER"
        print_success "Added $USER to docker group"
        print_warning "You need to log out and log back in for group changes to take effect"
        print_info "Or run: newgrp docker"
    else
        print_success "User already in docker group"
    fi
    
    # Configure Docker daemon
    sudo mkdir -p /etc/docker
    if [ ! -f /etc/docker/daemon.json ]; then
        sudo tee /etc/docker/daemon.json > /dev/null <<EOF
{
    "log-driver": "json-file",
    "log-opts": {
        "max-size": "10m",
        "max-file": "3"
    },
    "storage-driver": "overlay2"
}
EOF
        sudo systemctl restart docker
        print_success "Configured Docker daemon"
    fi
}

verify_docker() {
    print_header "Verifying Docker Installation"
    
    # Test Docker with hello-world
    print_info "Running test container..."
    
    if docker run --rm hello-world > /dev/null 2>&1; then
        print_success "Docker is working correctly"
    else
        if sudo docker run --rm hello-world > /dev/null 2>&1; then
            print_warning "Docker works with sudo, but not without"
            print_info "Please run: newgrp docker"
            print_info "Or log out and log back in"
        else
            print_error "Docker test failed"
            exit 1
        fi
    fi
    
    # Check Docker Compose
    if docker compose version &> /dev/null; then
        compose_version=$(docker compose version --short)
        print_success "Docker Compose installed (version: ${compose_version})"
    else
        print_error "Docker Compose plugin not found"
        exit 1
    fi
}

###############################################################################
# Port Checks
###############################################################################

check_ports() {
    print_header "Checking Port Availability"
    
    local ports_in_use=()
    
    for port in "${REQUIRED_PORTS[@]}"; do
        if netstat -tuln 2>/dev/null | grep -q ":${port} "; then
            print_warning "Port ${port} is already in use"
            ports_in_use+=("$port")
        else
            print_success "Port ${port} is available"
        fi
    done
    
    if [ ${#ports_in_use[@]} -gt 0 ]; then
        print_error "The following ports are in use: ${ports_in_use[*]}"
        print_info "Stop services using these ports or modify .env configuration"
        prompt_continue
    fi
}

###############################################################################
# Environment Configuration
###############################################################################

setup_environment() {
    print_header "Setting Up Environment Configuration"
    
    cd "$DOCKER_COMPOSE_DIR"
    
    if [ -f .env ]; then
        print_warning ".env file already exists"
        read -p "Overwrite existing .env? (y/n): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            print_info "Keeping existing .env file"
            return 0
        fi
        cp .env .env.backup.$(date +%Y%m%d_%H%M%S)
        print_info "Backed up existing .env"
    fi
    
    print_info "Creating .env from .env.example..."
    cp .env.example .env
    
    # Generate secure passwords
    print_info "Generating secure passwords..."
    
    local postgres_pass=$(openssl rand -base64 16 | tr -d "=+/" | cut -c1-16)
    local mysql_pass=$(openssl rand -base64 16 | tr -d "=+/" | cut -c1-16)
    local redis_pass=$(openssl rand -base64 16 | tr -d "=+/" | cut -c1-16)
    local minio_pass=$(openssl rand -base64 16 | tr -d "=+/" | cut -c1-16)
    
    sed -i "s/POSTGRES_PASSWORD=spark123/POSTGRES_PASSWORD=${postgres_pass}/" .env
    sed -i "s/MYSQL_ROOT_PASSWORD=root123/MYSQL_ROOT_PASSWORD=${mysql_pass}/" .env
    sed -i "s/MYSQL_PASSWORD=\${MYSQL_ROOT_PASSWORD:-root123}/MYSQL_PASSWORD=${mysql_pass}/" .env
    sed -i "s/# REDIS_PASSWORD=/REDIS_PASSWORD=${redis_pass}/" .env
    sed -i "s/MINIO_ROOT_PASSWORD=minioadmin123/MINIO_ROOT_PASSWORD=${minio_pass}/" .env
    
    # Set English locale explicitly
    sed -i "s/SERVICE_LOCATION=hf/SERVICE_LOCATION=en/" .env
    
    # Configure for localhost access
    sed -i "s/EXPOSE_NGINX_PORT=80/EXPOSE_NGINX_PORT=80/" .env
    sed -i "s#CONSOLE_DOMAIN=https://your.deployment.domain#CONSOLE_DOMAIN=http://localhost#" .env
    
    print_success "Environment configuration created"
    
    # Prompt for iFLYTEK API keys (optional)
    print_info "\nOptional: Configure iFLYTEK API Keys"
    print_info "You can skip this and configure later in the console"
    read -p "Configure iFLYTEK API keys now? (y/n): " -n 1 -r
    echo
    
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        read -p "Enter PLATFORM_APP_ID: " app_id
        read -p "Enter PLATFORM_API_KEY: " api_key
        read -s -p "Enter PLATFORM_API_SECRET: " api_secret
        echo
        read -s -p "Enter SPARK_API_PASSWORD: " api_password
        echo
        
        if [ -n "$app_id" ] && [ -n "$api_key" ]; then
            sed -i "s/PLATFORM_APP_ID=your-app-id/PLATFORM_APP_ID=${app_id}/" .env
            sed -i "s/PLATFORM_API_KEY=your-api-key/PLATFORM_API_KEY=${api_key}/" .env
            sed -i "s/PLATFORM_API_SECRET=your-api-secret/PLATFORM_API_SECRET=${api_secret}/" .env
            sed -i "s/SPARK_API_PASSWORD=your-api-password/SPARK_API_PASSWORD=${api_password}/" .env
            print_success "API keys configured"
        fi
    fi
    
    print_success "Configuration completed"
    print_info "Configuration file: ${DOCKER_COMPOSE_DIR}/.env"
}

###############################################################################
# Install Additional Tools
###############################################################################

install_tools() {
    print_header "Installing Additional Tools"
    
    local tools=(net-tools curl wget jq openssl)
    local missing_tools=()
    
    for tool in "${tools[@]}"; do
        if ! command -v "$tool" &> /dev/null; then
            missing_tools+=("$tool")
        fi
    done
    
    if [ ${#missing_tools[@]} -gt 0 ]; then
        print_info "Installing: ${missing_tools[*]}"
        sudo apt-get install -y -qq "${missing_tools[@]}"
        print_success "Tools installed"
    else
        print_success "All required tools already installed"
    fi
}

###############################################################################
# Create Helper Scripts
###############################################################################

create_helper_scripts() {
    print_header "Creating Helper Scripts"
    
    cd "$PROJECT_DIR"
    
    # Create status check script
    cat > status.sh <<'EOF'
#!/usr/bin/env bash
# Quick status check for all services
cd "$(dirname "$0")/docker/astronAgent"
docker compose ps
EOF
    chmod +x status.sh
    print_success "Created status.sh"
    
    # Create logs viewer script
    cat > logs.sh <<'EOF'
#!/usr/bin/env bash
# View logs from all services
cd "$(dirname "$0")/docker/astronAgent"
if [ -z "$1" ]; then
    docker compose logs -f --tail=50
else
    docker compose logs -f --tail=50 "$@"
fi
EOF
    chmod +x logs.sh
    print_success "Created logs.sh"
    
    # Create stop script
    cat > stop.sh <<'EOF'
#!/usr/bin/env bash
# Stop all services gracefully
cd "$(dirname "$0")/docker/astronAgent"
echo "Stopping Astron Agent services..."
docker compose stop
echo "Services stopped"
EOF
    chmod +x stop.sh
    print_success "Created stop.sh"
    
    # Create cleanup script
    cat > cleanup.sh <<'EOF'
#!/usr/bin/env bash
# Complete cleanup (removes containers and volumes)
cd "$(dirname "$0")/docker/astronAgent"
read -p "This will DELETE all containers and data. Continue? (yes/no): " confirm
if [ "$confirm" == "yes" ]; then
    echo "Removing services and volumes..."
    docker compose down -v
    echo "Cleanup complete"
else
    echo "Cleanup cancelled"
fi
EOF
    chmod +x cleanup.sh
    print_success "Created cleanup.sh"
}

###############################################################################
# Build Frontend with English Defaults
###############################################################################

build_frontend_english() {
    print_header "🏗️  Building Frontend (English Default)"
    
    # Docker image configuration
    local IMAGE_NAME="astron-agent-console-frontend-en"
    local IMAGE_TAG="latest"
    local FULL_IMAGE_NAME="${IMAGE_NAME}:${IMAGE_TAG}"
    
    # Build metadata
    local VERSION="${IMAGE_TAG}"
    local GIT_COMMIT=$(git rev-parse --short HEAD 2>/dev/null || echo "unknown")
    local BUILD_TIME=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    local PLATFORM="linux/amd64"  # Build for current platform only in setup
    
    print_info "Checking if frontend rebuild is needed..."
    
    # Check if the English-default image already exists locally
    if docker image inspect "${FULL_IMAGE_NAME}" &> /dev/null; then
        print_warning "Frontend image with English defaults already exists"
        echo ""
        read -p "Do you want to rebuild it? (y/N) " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            print_info "Skipping frontend rebuild"
            return 0
        fi
    fi
    
    # Pre-flight checks
    print_info "Running pre-flight checks..."
    
    # Check if Dockerfile exists
    if [ ! -f "console/frontend/Dockerfile" ]; then
        print_error "Dockerfile not found at console/frontend/Dockerfile"
        print_warning "Frontend will use default image (Chinese default)"
        return 1
    fi
    
    # Check if i18n modification was applied
    if ! grep -q "fallbackLng: 'en'" console/frontend/src/i18n/index.ts; then
        print_warning "i18n default language is not set to English"
        print_info "The frontend will still default to Chinese"
        echo ""
        read -p "Do you want to continue anyway? (y/N) " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            print_info "Build cancelled"
            return 1
        fi
    else
        print_success "i18n configured for English default"
    fi
    
    # Enable Docker BuildKit for faster builds
    export DOCKER_BUILDKIT=1
    
    print_info "Building frontend Docker image with English as default language..."
    print_info "Image: ${FULL_IMAGE_NAME}"
    print_info "Version: ${VERSION}"
    print_info "Git commit: ${GIT_COMMIT}"
    print_info "Platform: ${PLATFORM}"
    print_info "This may take 5-10 minutes depending on your system..."
    echo ""
    
    # Build the Docker image
    if docker build \
        --platform "${PLATFORM}" \
        --build-arg VERSION="${VERSION}" \
        --build-arg GIT_COMMIT="${GIT_COMMIT}" \
        --build-arg BUILD_TIME="${BUILD_TIME}" \
        -t "${FULL_IMAGE_NAME}" \
        -f console/frontend/Dockerfile \
        . 2>&1 | tee /tmp/frontend-build.log; then
        
        print_success "Frontend image built successfully"
        
        # Verify build
        if docker image inspect "${FULL_IMAGE_NAME}" &> /dev/null; then
            local IMAGE_SIZE=$(docker image inspect "${FULL_IMAGE_NAME}" --format='{{.Size}}' | awk '{print $1/1024/1024}')
            print_success "Image verified: ${FULL_IMAGE_NAME}"
            print_info "Image size: ${IMAGE_SIZE} MB"
            
            # Create additional tags
            docker tag "${FULL_IMAGE_NAME}" "${IMAGE_NAME}:${GIT_COMMIT}" 2>/dev/null || true
            docker tag "${FULL_IMAGE_NAME}" "${IMAGE_NAME}:$(date +%Y%m%d)" 2>/dev/null || true
            
            return 0
        else
            print_error "Image verification failed"
            return 1
        fi
    else
        print_error "Frontend build failed"
        print_warning "Build log saved to: /tmp/frontend-build.log"
        print_warning "You can:"
        print_warning "  1. Continue with the existing frontend image (Chinese default)"
        print_warning "  2. Review the build log and try again"
        echo ""
        read -p "Continue with existing image? (y/N) " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
        return 1
    fi
}

# Update docker-compose to use English frontend
update_docker_compose() {
    print_header "🔧 Updating Docker Compose Configuration"
    
    cd docker/astronAgent
    
    # Check if English frontend image was built
    if docker image inspect astron-agent-console-frontend-en:latest &> /dev/null; then
        print_info "Updating docker-compose.yaml to use English frontend..."
        
        # Backup original docker-compose.yaml
        if [ ! -f docker-compose.yaml.backup ]; then
            cp docker-compose.yaml docker-compose.yaml.backup
            print_success "Backed up original docker-compose.yaml"
        fi
        
        # Update console-frontend image
        if grep -q "image: astron-agent-console-frontend-en:latest" docker-compose.yaml; then
            print_info "Docker compose already configured for English frontend"
        else
            # Replace the image line for console-frontend
            sed -i.tmp '/console-frontend:/,/environment:/ {
                s|image:.*console.*|image: astron-agent-console-frontend-en:latest|
            }' docker-compose.yaml
            rm -f docker-compose.yaml.tmp
            print_success "Updated docker-compose.yaml to use English frontend"
        fi
    else
        print_warning "English frontend image not found, using default image"
        print_info "The console will default to Chinese language"
        print_info "Users can manually switch to English in the UI"
    fi
    
    cd ../..
}

###############################################################################
# Final Summary
###############################################################################

print_summary() {
    print_header "Setup Complete!"
    
    echo -e "${GREEN}✓ WSL2 environment prepared${NC}"
    echo -e "${GREEN}✓ Docker Engine installed and configured${NC}"
    echo -e "${GREEN}✓ Environment configuration created${NC}"
    
    # Check if English frontend was built
    if docker image inspect astron-agent-console-frontend-en:latest &> /dev/null; then
        echo -e "${GREEN}✓ Frontend built with English as default language${NC}"
    else
        echo -e "${YELLOW}⚠ Frontend using default image (Chinese default)${NC}"
        echo -e "  ${CYAN}To build English version: ${YELLOW}./build-frontend-en.sh${NC}"
    fi
    
    echo -e "${GREEN}✓ Helper scripts generated${NC}"
    echo ""
    echo -e "${CYAN}Next Steps:${NC}"
    echo -e "  1. Review configuration: ${YELLOW}${DOCKER_COMPOSE_DIR}/.env${NC}"
    echo -e "  2. Start services: ${YELLOW}./start.sh${NC}"
    echo -e "  3. Access console: ${YELLOW}http://localhost${NC}"
    echo ""
    
    # Language-specific notes
    if docker image inspect astron-agent-console-frontend-en:latest &> /dev/null; then
        echo -e "${GREEN}✓ Console UI will default to English${NC}"
    else
        echo -e "${CYAN}Language Note:${NC}"
        echo -e "  The console will default to ${YELLOW}Chinese${NC}"
        echo -e "  You can switch to English using the language selector"
        echo -e "  Or build English version: ${YELLOW}./build-frontend-en.sh${NC}"
        echo ""
    fi
    
    echo -e "${CYAN}Helper Commands:${NC}"
    echo -e "  • Check status: ${YELLOW}./status.sh${NC}"
    echo -e "  • View logs: ${YELLOW}./logs.sh [service-name]${NC}"
    echo -e "  • Stop services: ${YELLOW}./stop.sh${NC}"
    echo -e "  • Full cleanup: ${YELLOW}./cleanup.sh${NC}"
    echo ""
    
    if ! groups | grep -q docker; then
        print_warning "Remember to apply docker group membership:"
        echo -e "  ${YELLOW}newgrp docker${NC} or log out and back in"
    fi
}

###############################################################################
# Main Execution
###############################################################################

main() {
    clear
    echo -e "${CYAN}"
    cat << "EOF"
    ╔═══════════════════════════════════════════════════════════╗
    ║                                                           ║
    ║            Astron Agent - WSL2 Setup Script              ║
    ║                                                           ║
    ║         Enterprise AI Agent Development Platform         ║
    ║                                                           ║
    ╚═══════════════════════════════════════════════════════════╝
EOF
    echo -e "${NC}"
    
    check_wsl2
    check_distro
    check_system_resources
    check_systemd
    install_tools
    install_docker
    configure_docker
    verify_docker
    check_ports
    setup_environment
    build_frontend_english
    update_docker_compose
    create_helper_scripts
    print_summary
}

# Run main function
main "$@"
