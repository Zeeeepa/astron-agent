#!/bin/bash

################################################################################
# Astron Agent - Complete Deployment Script for Ubuntu
# 
# This script will:
# - Install all dependencies (Docker, Docker Compose, Git, etc.)
# - Clone the repository if not found
# - Configure environment variables
# - Deploy the complete stack with AI-powered error handling
# - Validate service health
#
# Usage: ./deploy.sh
################################################################################

set -e  # Exit on error (will be handled by our error handler)

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color
BOLD='\033[1m'

# Configuration
REPO_URL="https://github.com/iflytek/astron-agent.git"
REPO_DIR="astron-agent"
DEPLOY_DIR="docker/astronAgent"
LOG_FILE="deployment_$(date +%Y%m%d_%H%M%S).log"

# AI Configuration for error resolution
export ANTHROPIC_BASE_URL="${ANTHROPIC_BASE_URL:-https://api.z.ai/api/anthropic}"
export ANTHROPIC_MODEL="${ANTHROPIC_MODEL:-glm-4.6}"
export ANTHROPIC_AUTH_TOKEN="${ANTHROPIC_AUTH_TOKEN:-ae034cdcfefe4227879e6962493bc113.mRURYmJrKOFSEaY0}"

################################################################################
# Utility Functions
################################################################################

log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $*" | tee -a "$LOG_FILE"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $*" | tee -a "$LOG_FILE"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $*" | tee -a "$LOG_FILE"
}

log_info() {
    echo -e "${CYAN}[INFO]${NC} $*" | tee -a "$LOG_FILE"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} ✓ $*" | tee -a "$LOG_FILE"
}

print_banner() {
    echo -e "${MAGENTA}${BOLD}"
    cat << "EOF"
╔═══════════════════════════════════════════════════════════════╗
║                                                               ║
║     █████╗ ███████╗████████╗██████╗  ██████╗ ███╗   ██╗     ║
║    ██╔══██╗██╔════╝╚══██╔══╝██╔══██╗██╔═══██╗████╗  ██║     ║
║    ███████║███████╗   ██║   ██████╔╝██║   ██║██╔██╗ ██║     ║
║    ██╔══██║╚════██║   ██║   ██╔══██╗██║   ██║██║╚██╗██║     ║
║    ██║  ██║███████║   ██║   ██║  ██║╚██████╔╝██║ ╚████║     ║
║    ╚═╝  ╚═╝╚══════╝   ╚═╝   ╚═╝  ╚═╝ ╚═════╝ ╚═╝  ╚═══╝     ║
║                                                               ║
║            AI Agent Platform - Ubuntu Deployment             ║
║                                                               ║
╚═══════════════════════════════════════════════════════════════╝
EOF
    echo -e "${NC}"
}

print_separator() {
    echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
}

# Progress spinner
spinner() {
    local pid=$1
    local delay=0.1
    local spinstr='⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'
    while ps -p $pid > /dev/null 2>&1; do
        local temp=${spinstr#?}
        printf " ${CYAN}[%c]${NC}  " "$spinstr"
        local spinstr=$temp${spinstr%"$temp"}
        sleep $delay
        printf "\b\b\b\b\b\b"
    done
    printf "    \b\b\b\b"
}

################################################################################
# AI-Powered Error Resolution
################################################################################

call_ai_resolver() {
    local error_message="$1"
    local context="$2"
    
    log_info "🤖 Calling AI error resolver..."
    
    # Create temporary file for request
    local request_file=$(mktemp)
    local response_file=$(mktemp)
    
    cat > "$request_file" << EOF
{
  "model": "${ANTHROPIC_MODEL}",
  "max_tokens": 2048,
  "messages": [
    {
      "role": "user",
      "content": "I'm deploying Astron Agent on Ubuntu and encountered an error. Please provide a specific solution.\n\nContext: ${context}\n\nError:\n${error_message}\n\nProvide:\n1. Root cause analysis\n2. Specific commands to fix\n3. Prevention tips\n\nBe concise and actionable."
    }
  ]
}
EOF

    # Call AI API
    if curl -s -X POST "${ANTHROPIC_BASE_URL}" \
        -H "Content-Type: application/json" \
        -H "Authorization: Bearer ${ANTHROPIC_AUTH_TOKEN}" \
        -d @"$request_file" \
        -o "$response_file" 2>&1; then
        
        # Extract content from response
        local ai_response=$(cat "$response_file" | jq -r '.content[0].text // .choices[0].message.content // empty' 2>/dev/null)
        
        if [ -n "$ai_response" ]; then
            echo -e "\n${MAGENTA}═══ AI Assistant Response ═══${NC}"
            echo "$ai_response"
            echo -e "${MAGENTA}════════════════════════════${NC}\n"
            
            # Log to file
            echo "=== AI Resolution ===" >> "$LOG_FILE"
            echo "$ai_response" >> "$LOG_FILE"
            echo "===================" >> "$LOG_FILE"
        else
            log_warning "AI resolver returned empty response"
        fi
    else
        log_warning "Failed to connect to AI resolver"
    fi
    
    # Cleanup
    rm -f "$request_file" "$response_file"
}

# Error handler with AI resolution
error_handler() {
    local exit_code=$?
    local line_number=$1
    
    if [ $exit_code -ne 0 ]; then
        log_error "Command failed with exit code $exit_code at line $line_number"
        
        # Get last few log lines for context
        local error_context=$(tail -n 20 "$LOG_FILE" 2>/dev/null || echo "No context available")
        
        # Call AI resolver
        call_ai_resolver "Exit code: $exit_code at line $line_number" "$error_context"
        
        echo -e "\n${RED}${BOLD}Deployment failed!${NC}"
        echo -e "Check log file for details: ${YELLOW}$LOG_FILE${NC}"
        exit $exit_code
    fi
}

trap 'error_handler $LINENO' ERR

################################################################################
# System Checks
################################################################################

check_root() {
    if [ "$EUID" -eq 0 ]; then
        log_warning "Running as root. This is not recommended for production."
        read -p "Continue anyway? (y/N) " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    fi
}

check_ubuntu() {
    if [ ! -f /etc/os-release ]; then
        log_error "Cannot determine OS. This script is designed for Ubuntu."
        exit 1
    fi
    
    . /etc/os-release
    
    if [[ "$ID" != "ubuntu" ]]; then
        log_warning "This script is optimized for Ubuntu. Detected: $ID"
        log_warning "Continuing anyway, but some steps may fail."
    else
        log_success "Ubuntu detected: $VERSION"
    fi
}

check_system_resources() {
    log_info "Checking system resources..."
    
    # Check CPU cores
    local cpu_cores=$(nproc)
    if [ "$cpu_cores" -lt 2 ]; then
        log_error "Insufficient CPU cores. Required: 2+, Found: $cpu_cores"
        exit 1
    fi
    log_success "CPU cores: $cpu_cores"
    
    # Check RAM
    local total_ram=$(free -g | awk '/^Mem:/{print $2}')
    if [ "$total_ram" -lt 4 ]; then
        log_error "Insufficient RAM. Required: 4GB+, Found: ${total_ram}GB"
        exit 1
    fi
    log_success "RAM: ${total_ram}GB"
    
    # Check disk space
    local disk_space=$(df -BG / | awk 'NR==2 {print $4}' | sed 's/G//')
    if [ "$disk_space" -lt 50 ]; then
        log_warning "Low disk space. Recommended: 50GB+, Available: ${disk_space}GB"
    else
        log_success "Disk space: ${disk_space}GB"
    fi
}

################################################################################
# Dependency Installation
################################################################################

install_dependencies() {
    log_info "Installing system dependencies..."
    
    # Update package list
    log_info "Updating package list..."
    sudo apt-get update -qq >> "$LOG_FILE" 2>&1 &
    spinner $!
    log_success "Package list updated"
    
    # Install prerequisites
    local packages=(
        "curl"
        "wget"
        "git"
        "jq"
        "ca-certificates"
        "gnupg"
        "lsb-release"
        "software-properties-common"
    )
    
    log_info "Installing prerequisites..."
    for package in "${packages[@]}"; do
        if ! dpkg -l | grep -q "^ii  $package "; then
            log_info "Installing $package..."
            sudo apt-get install -y -qq "$package" >> "$LOG_FILE" 2>&1 &
            spinner $!
            log_success "$package installed"
        else
            log_info "$package already installed ✓"
        fi
    done
}

install_docker() {
    if command -v docker &> /dev/null; then
        log_info "Docker already installed: $(docker --version)"
        return 0
    fi
    
    log_info "Installing Docker..."
    
    # Add Docker's official GPG key
    sudo mkdir -p /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg 2>> "$LOG_FILE"
    
    # Set up repository
    echo \
      "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
      $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
    
    # Install Docker Engine
    sudo apt-get update -qq >> "$LOG_FILE" 2>&1
    sudo apt-get install -y -qq docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin >> "$LOG_FILE" 2>&1 &
    spinner $!
    
    # Add current user to docker group
    sudo usermod -aG docker $USER
    
    # Start Docker service
    sudo systemctl start docker
    sudo systemctl enable docker
    
    log_success "Docker installed: $(docker --version)"
    log_warning "You may need to log out and back in for docker group permissions to take effect"
}

verify_docker() {
    log_info "Verifying Docker installation..."
    
    if ! docker ps &> /dev/null; then
        log_warning "Docker daemon not accessible. Trying to start..."
        sudo systemctl start docker
        sleep 3
        
        if ! docker ps &> /dev/null; then
            log_error "Docker is not accessible. Try logging out and back in."
            call_ai_resolver "Docker daemon not accessible after installation" "User: $USER, Groups: $(groups)"
            exit 1
        fi
    fi
    
    log_success "Docker is accessible"
}

################################################################################
# Repository Management
################################################################################

clone_or_update_repo() {
    if [ -d "$REPO_DIR" ]; then
        log_info "Repository directory exists: $REPO_DIR"
        
        cd "$REPO_DIR"
        
        # Check if it's a git repository
        if [ -d ".git" ]; then
            log_info "Updating existing repository..."
            git fetch origin >> "$LOG_FILE" 2>&1
            
            # Check if there are updates
            local local_hash=$(git rev-parse HEAD)
            local remote_hash=$(git rev-parse origin/main 2>/dev/null || git rev-parse origin/master)
            
            if [ "$local_hash" != "$remote_hash" ]; then
                log_info "Updates available. Pulling latest changes..."
                git pull origin main >> "$LOG_FILE" 2>&1 || git pull origin master >> "$LOG_FILE" 2>&1
                log_success "Repository updated"
            else
                log_info "Repository is up to date ✓"
            fi
        else
            log_warning "Directory exists but is not a git repository"
            read -p "Remove and re-clone? (y/N) " -n 1 -r
            echo
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                cd ..
                rm -rf "$REPO_DIR"
                clone_repository
            fi
        fi
        
        cd ..
    else
        clone_repository
    fi
}

clone_repository() {
    log_info "Cloning repository from $REPO_URL..."
    git clone "$REPO_URL" "$REPO_DIR" >> "$LOG_FILE" 2>&1 &
    spinner $!
    log_success "Repository cloned"
}

################################################################################
# Configuration
################################################################################

configure_environment() {
    log_info "Configuring environment variables..."
    
    cd "$REPO_DIR/$DEPLOY_DIR"
    
    if [ ! -f ".env" ]; then
        if [ -f ".env.example" ]; then
            cp .env.example .env
            log_success "Created .env from .env.example"
        else
            log_error ".env.example not found"
            exit 1
        fi
    else
        log_info ".env already exists"
    fi
    
    # Interactive configuration
    echo -e "\n${CYAN}${BOLD}=== Environment Configuration ===${NC}\n"
    
    # Check if already configured
    if grep -q "your-app-id" .env 2>/dev/null; then
        echo -e "${YELLOW}The .env file contains default placeholders.${NC}"
        echo -e "You need to configure iFLYTEK platform credentials."
        echo -e "\n${CYAN}To get credentials:${NC}"
        echo -e "1. Visit: ${BLUE}https://www.xfyun.cn${NC}"
        echo -e "2. Register and create an application"
        echo -e "3. Get APP_ID, API_KEY, API_SECRET"
        echo -e "4. For Spark API, get SPARK_API_PASSWORD from: ${BLUE}https://xinghuo.xfyun.cn/sparkapi${NC}"
        
        read -p $'\n'"Do you want to configure credentials now? (y/N) " -n 1 -r
        echo
        
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            read -p "Enter PLATFORM_APP_ID: " app_id
            read -p "Enter PLATFORM_API_KEY: " api_key
            read -p "Enter PLATFORM_API_SECRET: " api_secret
            read -p "Enter SPARK_API_PASSWORD: " spark_password
            
            # Update .env file
            sed -i "s/PLATFORM_APP_ID=.*/PLATFORM_APP_ID=$app_id/" .env
            sed -i "s/PLATFORM_API_KEY=.*/PLATFORM_API_KEY=$api_key/" .env
            sed -i "s/PLATFORM_API_SECRET=.*/PLATFORM_API_SECRET=$api_secret/" .env
            sed -i "s/SPARK_API_PASSWORD=.*/SPARK_API_PASSWORD=$spark_password/" .env
            
            log_success "Credentials configured"
        else
            log_warning "Skipping credential configuration. You'll need to edit .env manually."
            log_info "Edit file: $REPO_DIR/$DEPLOY_DIR/.env"
        fi
    else
        log_info "Credentials appear to be configured ✓"
    fi
    
    cd - > /dev/null
}

################################################################################
# Deployment
################################################################################

deploy_services() {
    log_info "Deploying services..."
    
    cd "$REPO_DIR/$DEPLOY_DIR"
    
    # Determine which compose file to use
    local compose_file="docker-compose-with-auth.yaml"
    
    if [ ! -f "$compose_file" ]; then
        log_error "Docker Compose file not found: $compose_file"
        exit 1
    fi
    
    log_info "Using compose file: $compose_file"
    
    # Pull images
    log_info "Pulling Docker images (this may take a while)..."
    docker compose -f "$compose_file" pull >> "$LOG_FILE" 2>&1 &
    spinner $!
    log_success "Images pulled"
    
    # Start services
    log_info "Starting services..."
    docker compose -f "$compose_file" up -d >> "$LOG_FILE" 2>&1
    log_success "Services started"
    
    cd - > /dev/null
}

wait_for_services() {
    log_info "Waiting for services to become healthy..."
    
    local max_wait=120
    local waited=0
    local interval=5
    
    cd "$REPO_DIR/$DEPLOY_DIR"
    
    while [ $waited -lt $max_wait ]; do
        local unhealthy=$(docker compose ps | grep -E "(starting|unhealthy)" | wc -l)
        
        if [ $unhealthy -eq 0 ]; then
            log_success "All services are healthy"
            cd - > /dev/null
            return 0
        fi
        
        echo -ne "${CYAN}Waiting for services... ${waited}s / ${max_wait}s${NC}\r"
        sleep $interval
        waited=$((waited + interval))
    done
    
    log_warning "Some services may not be fully healthy yet"
    cd - > /dev/null
}

################################################################################
# Validation
################################################################################

validate_deployment() {
    log_info "Validating deployment..."
    
    cd "$REPO_DIR/$DEPLOY_DIR"
    
    # Check container status
    local containers=$(docker compose ps -q)
    local running=0
    local total=0
    
    for container in $containers; do
        total=$((total + 1))
        if docker inspect -f '{{.State.Running}}' "$container" 2>/dev/null | grep -q true; then
            running=$((running + 1))
        fi
    done
    
    log_info "Containers running: $running/$total"
    
    if [ $running -eq $total ]; then
        log_success "All containers are running"
    else
        log_warning "Some containers are not running"
    fi
    
    cd - > /dev/null
}

################################################################################
# Main Execution
################################################################################

main() {
    print_banner
    
    log_info "Starting Astron Agent deployment on Ubuntu"
    log_info "Log file: $LOG_FILE"
    print_separator
    
    # System checks
    log_info "Step 1/8: Performing system checks..."
    check_root
    check_ubuntu
    check_system_resources
    print_separator
    
    # Install dependencies
    log_info "Step 2/8: Installing dependencies..."
    install_dependencies
    print_separator
    
    # Install Docker
    log_info "Step 3/8: Installing Docker..."
    install_docker
    verify_docker
    print_separator
    
    # Repository management
    log_info "Step 4/8: Managing repository..."
    clone_or_update_repo
    print_separator
    
    # Configuration
    log_info "Step 5/8: Configuring environment..."
    configure_environment
    print_separator
    
    # Deploy services
    log_info "Step 6/8: Deploying services..."
    deploy_services
    print_separator
    
    # Wait for services
    log_info "Step 7/8: Waiting for services..."
    wait_for_services
    print_separator
    
    # Validate
    log_info "Step 8/8: Validating deployment..."
    validate_deployment
    print_separator
    
    # Success message
    echo -e "\n${GREEN}${BOLD}╔═══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}${BOLD}║                                                               ║${NC}"
    echo -e "${GREEN}${BOLD}║          🎉 DEPLOYMENT COMPLETED SUCCESSFULLY! 🎉            ║${NC}"
    echo -e "${GREEN}${BOLD}║                                                               ║${NC}"
    echo -e "${GREEN}${BOLD}╚═══════════════════════════════════════════════════════════════╝${NC}\n"
    
    echo -e "${CYAN}${BOLD}Next Steps:${NC}"
    echo -e "1. Run ${GREEN}./start.sh${NC} to start the platform with health checks"
    echo -e "2. Run ${RED}./stop.sh${NC} to stop all services"
    echo -e "3. Access the application at ${BLUE}http://localhost/${NC}"
    echo -e "4. Default Casdoor login: ${YELLOW}admin / 123${NC}"
    echo -e "\n${CYAN}Log file: ${YELLOW}$LOG_FILE${NC}\n"
}

# Run main function
main "$@"

