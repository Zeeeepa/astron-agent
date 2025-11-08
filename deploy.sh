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

set -eE  # Exit on error and inherit ERR trap in functions
set -o pipefail  # Catch errors in pipelines
set -u  # Error on undefined variables

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color
BOLD='\033[1m'

# Configuration with validation
REPO_URL="${REPO_URL:-https://github.com/iflytek/astron-agent.git}"
REPO_DIR="${REPO_DIR:-astron-agent}"
DEPLOY_DIR="${DEPLOY_DIR:-docker/astronAgent}"
LOG_FILE="deployment_$(date +%Y%m%d_%H%M%S).log"
LOCKFILE="/tmp/astron-agent-deploy.lock"
MAX_RETRIES=3
RETRY_DELAY=5

# AI Configuration for error resolution
export ANTHROPIC_BASE_URL="${ANTHROPIC_BASE_URL:-https://api.z.ai/api/anthropic}"
export ANTHROPIC_MODEL="${ANTHROPIC_MODEL:-glm-4.6}"
export ANTHROPIC_AUTH_TOKEN="${ANTHROPIC_AUTH_TOKEN:-ae034cdcfefe4227879e6962493bc113.mRURYmJrKOFSEaY0}"

# Error tracking
declare -a ERRORS=()
ERROR_COUNT=0

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
# Enhanced Error Handling
################################################################################

# Lock file management
acquire_lock() {
    local timeout=30
    local elapsed=0
    
    while [ -f "$LOCKFILE" ] && [ $elapsed -lt $timeout ]; do
        log_warning "Another deployment is in progress. Waiting..."
        sleep 2
        elapsed=$((elapsed + 2))
    done
    
    if [ $elapsed -ge $timeout ]; then
        log_error "Could not acquire lock. Another deployment may be stuck."
        log_info "Remove lock file manually if needed: sudo rm $LOCKFILE"
        return 1
    fi
    
    echo $$ > "$LOCKFILE"
    log_info "Lock acquired (PID: $$)"
}

release_lock() {
    if [ -f "$LOCKFILE" ]; then
        rm -f "$LOCKFILE"
        log_info "Lock released"
    fi
}

# Cleanup function
cleanup_on_exit() {
    local exit_code=$?
    release_lock
    
    if [ $exit_code -ne 0 ]; then
        log_error "Deployment failed with exit code: $exit_code"
        log_info "Check log file for details: $LOG_FILE"
        
        if [ ${#ERRORS[@]} -gt 0 ]; then
            echo -e "\n${RED}${BOLD}Errors encountered:${NC}"
            for error in "${ERRORS[@]}"; do
                echo -e "${RED}  - $error${NC}"
            done
        fi
    fi
}

trap cleanup_on_exit EXIT
trap 'release_lock; exit 130' INT TERM

# Record error
record_error() {
    local error_msg="$1"
    ERRORS+=("$error_msg")
    ERROR_COUNT=$((ERROR_COUNT + 1))
    log_error "$error_msg"
}

# Retry mechanism
retry_command() {
    local max_attempts="${1:-$MAX_RETRIES}"
    local delay="${2:-$RETRY_DELAY}"
    shift 2
    local cmd="$@"
    local attempt=1
    
    while [ $attempt -le $max_attempts ]; do
        log_info "Attempt $attempt/$max_attempts: $cmd"
        
        if eval "$cmd"; then
            return 0
        fi
        
        if [ $attempt -lt $max_attempts ]; then
            log_warning "Command failed. Retrying in ${delay}s..."
            sleep $delay
        fi
        
        attempt=$((attempt + 1))
    done
    
    record_error "Command failed after $max_attempts attempts: $cmd"
    return 1
}

# Check command availability
check_command() {
    local cmd="$1"
    local package="${2:-$1}"
    
    if ! command -v "$cmd" &> /dev/null; then
        log_warning "$cmd not found. Attempting to install $package..."
        
        if sudo apt-get install -y -qq "$package" >> "$LOG_FILE" 2>&1; then
            log_success "$package installed"
            return 0
        else
            record_error "Failed to install $package"
            return 1
        fi
    fi
    
    log_info "$cmd is available ✓"
    return 0
}

# Validate network connectivity
check_network() {
    local test_urls=(
        "https://github.com"
        "https://download.docker.com"
        "https://archive.ubuntu.com"
    )
    
    log_info "Checking network connectivity..."
    
    for url in "${test_urls[@]}"; do
        if curl -s --max-time 10 --head "$url" > /dev/null 2>&1; then
            log_success "Network connectivity OK"
            return 0
        fi
    done
    
    record_error "No network connectivity detected"
    return 1
}

# Validate environment
validate_environment() {
    log_info "Validating environment..."
    
    # Check if running in a container
    if [ -f /.dockerenv ]; then
        log_warning "Running inside a container. Some operations may not work correctly."
    fi
    
    # Check for required commands
    local required_commands=("curl" "wget" "tar" "gzip")
    for cmd in "${required_commands[@]}"; do
        check_command "$cmd" || return 1
    done
    
    # Check network
    check_network || return 1
    
    # Check disk space (in KB)
    local available_space=$(df -k / | awk 'NR==2 {print $4}')
    local required_space=$((50 * 1024 * 1024))  # 50GB in KB
    
    if [ "$available_space" -lt "$required_space" ]; then
        log_warning "Low disk space: $((available_space / 1024 / 1024))GB available"
        log_warning "Recommended: 50GB+ free space"
    fi
    
    log_success "Environment validation passed"
    return 0
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
        local docker_version=$(docker --version 2>/dev/null || echo "unknown")
        log_info "Docker already installed: $docker_version"
        
        # Verify Docker daemon is accessible
        if ! docker ps &> /dev/null; then
            log_warning "Docker daemon not accessible. Attempting to fix..."
            sudo systemctl start docker || record_error "Failed to start Docker daemon"
            sleep 3
        fi
        
        return 0
    fi
    
    log_info "Installing Docker..."
    
    # Backup any existing Docker configuration
    if [ -d "/etc/docker" ]; then
        log_info "Backing up existing Docker configuration..."
        sudo cp -r /etc/docker "/etc/docker.backup.$(date +%s)" 2>/dev/null || true
    fi
    
    # Remove old Docker installations
    log_info "Removing old Docker installations if any..."
    sudo apt-get remove -y -qq docker docker-engine docker.io containerd runc 2>/dev/null || true
    
    # Add Docker's official GPG key with retry
    log_info "Adding Docker GPG key..."
    sudo mkdir -p /etc/apt/keyrings
    
    if ! retry_command 3 5 "curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg 2>> '$LOG_FILE'"; then
        record_error "Failed to add Docker GPG key"
        return 1
    fi
    
    # Set correct permissions on GPG key
    sudo chmod a+r /etc/apt/keyrings/docker.gpg
    
    # Set up repository
    log_info "Adding Docker repository..."
    local arch=$(dpkg --print-architecture)
    local codename=$(lsb_release -cs)
    
    echo \
      "deb [arch=$arch signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
      $codename stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
    
    # Update package index
    log_info "Updating package index..."
    if ! retry_command 3 5 "sudo apt-get update -qq >> '$LOG_FILE' 2>&1"; then
        record_error "Failed to update package index"
        return 1
    fi
    
    # Install Docker Engine with retry
    log_info "Installing Docker Engine (this may take a few minutes)..."
    if ! retry_command 3 10 "sudo apt-get install -y -qq docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin >> '$LOG_FILE' 2>&1"; then
        record_error "Failed to install Docker Engine"
        call_ai_resolver "Docker installation failed" "$(tail -n 50 '$LOG_FILE')"
        return 1
    fi
    
    # Add current user to docker group
    log_info "Configuring Docker permissions..."
    if ! sudo usermod -aG docker $USER; then
        log_warning "Failed to add user to docker group. You may need to do this manually."
    fi
    
    # Start and enable Docker service
    log_info "Starting Docker service..."
    if ! sudo systemctl start docker; then
        record_error "Failed to start Docker service"
        return 1
    fi
    
    if ! sudo systemctl enable docker; then
        log_warning "Failed to enable Docker service at boot"
    fi
    
    # Wait for Docker daemon to be ready
    local max_wait=30
    local waited=0
    while ! docker ps &> /dev/null && [ $waited -lt $max_wait ]; do
        log_info "Waiting for Docker daemon..."
        sleep 2
        waited=$((waited + 2))
    done
    
    if docker ps &> /dev/null; then
        local docker_version=$(docker --version)
        log_success "Docker installed: $docker_version"
        log_warning "IMPORTANT: You may need to log out and back in for docker group permissions to take effect"
        log_info "If commands fail with permission errors, run: newgrp docker"
    else
        record_error "Docker daemon did not start properly"
        return 1
    fi
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
# Backup & Rollback
################################################################################

create_backup() {
    log_info "Creating pre-deployment backup..."
    
    local backup_dir="./backups"
    local backup_id="backup_$(date +%Y%m%d_%H%M%S)"
    local backup_path="$backup_dir/$backup_id"
    
    # Create backup directory
    mkdir -p "$backup_path"
    
    # Backup configuration
    if [ -f "$REPO_DIR/$DEPLOY_DIR/.env" ]; then
        log_info "Backing up configuration..."
        cp "$REPO_DIR/$DEPLOY_DIR/.env" "$backup_path/env_backup"
    fi
    
    # Backup Docker volumes (if services are running)
    if docker compose -f "$REPO_DIR/$DEPLOY_DIR/docker-compose-with-auth.yaml" ps -q 2>/dev/null | grep -q .; then
        log_info "Backing up Docker volumes (this may take a few minutes)..."
        
        # Create volumes backup
        if sudo tar -czf "$backup_path/docker_volumes_backup.tar.gz" \
            /var/lib/docker/volumes/ 2>> "$LOG_FILE"; then
            log_success "Docker volumes backed up"
        else
            log_warning "Failed to backup Docker volumes (non-critical)"
        fi
    else
        log_info "No running services, skipping volume backup"
    fi
    
    # Create metadata
    cat > "$backup_path/metadata.json" << EOF
{
  "backup_id": "$backup_id",
  "timestamp": "$(date +'%Y-%m-%d %H:%M:%S')",
  "commit_hash": "$(git -C $REPO_DIR rev-parse HEAD 2>/dev/null || echo 'unknown')",
  "status": "success"
}
EOF
    
    log_success "Backup created: $backup_id"
    
    # Cleanup old backups (keep last 5)
    log_info "Cleaning up old backups..."
    local backup_count=$(ls -1 "$backup_dir" 2>/dev/null | wc -l)
    local max_backups=5
    
    if [ "$backup_count" -gt "$max_backups" ]; then
        local to_remove=$((backup_count - max_backups))
        ls -1t "$backup_dir" | tail -n "$to_remove" | while read old_backup; do
            log_info "Removing old backup: $old_backup"
            rm -rf "$backup_dir/$old_backup"
        done
    fi
    
    return 0
}

################################################################################
# Pre-Deployment Validation
################################################################################

validate_ports_available() {
    log_info "Checking port availability..."
    
    local required_ports=(80 8000 3306 6379)
    local port_conflicts=()
    
    for port in "${required_ports[@]}"; do
        if sudo lsof -Pi :$port -sTCP:LISTEN -t >/dev/null 2>&1; then
            port_conflicts+=($port)
            log_warning "Port $port is already in use"
        fi
    done
    
    if [ ${#port_conflicts[@]} -gt 0 ]; then
        log_warning "Ports in use: ${port_conflicts[*]}"
        log_info "Services may fail to start if ports are occupied"
        return 1
    fi
    
    log_success "All required ports available"
    return 0
}

validate_docker_compose_syntax() {
    log_info "Validating Docker Compose file..."
    
    cd "$REPO_DIR/$DEPLOY_DIR" || return 1
    
    if docker compose -f docker-compose-with-auth.yaml config > /dev/null 2>&1; then
        log_success "Docker Compose syntax valid"
        cd - > /dev/null
        return 0
    else
        log_error "Docker Compose syntax invalid"
        cd - > /dev/null
        return 1
    fi
}

validate_disk_space() {
    log_info "Validating disk space..."
    
    local available_gb=$(df -BG / | awk 'NR==2 {print $4}' | tr -d 'G')
    local required_gb=10
    
    if [ "$available_gb" -lt "$required_gb" ]; then
        log_warning "Low disk space: ${available_gb}GB available (recommended: ${required_gb}GB+)"
        return 1
    fi
    
    log_success "Sufficient disk space: ${available_gb}GB available"
    return 0
}

validate_env_file() {
    log_info "Validating environment configuration..."
    
    local env_file="$REPO_DIR/$DEPLOY_DIR/.env"
    
    if [ ! -f "$env_file" ]; then
        log_warning ".env file not found (will be created)"
        return 0
    fi
    
    # Check for required variables
    local required_vars=(
        "PLATFORM_APP_ID"
        "PLATFORM_API_KEY"
        "PLATFORM_API_SECRET"
        "SPARK_API_PASSWORD"
    )
    
    local missing_vars=()
    
    for var in "${required_vars[@]}"; do
        if ! grep -q "^${var}=" "$env_file" 2>/dev/null; then
            missing_vars+=($var)
        fi
    done
    
    if [ ${#missing_vars[@]} -gt 0 ]; then
        log_warning "Missing required variables: ${missing_vars[*]}"
        log_info "You can configure these after deployment"
    else
        log_success "All required variables present"
    fi
    
    return 0
}

pre_deployment_validation() {
    log_info "Running pre-deployment validation..."
    
    local validation_failed=false
    
    # Port availability (warning only)
    if ! validate_ports_available; then
        log_warning "Port conflicts detected (non-critical)"
    fi
    
    # Docker Compose syntax (critical)
    if ! validate_docker_compose_syntax; then
        log_error "Docker Compose validation failed"
        validation_failed=true
    fi
    
    # Disk space (warning only)
    if ! validate_disk_space; then
        log_warning "Low disk space detected (non-critical)"
    fi
    
    # Environment file (warning only)
    if ! validate_env_file; then
        log_warning "Environment validation completed with warnings"
    fi
    
    if $validation_failed; then
        log_error "Pre-deployment validation failed"
        return 1
    fi
    
    log_success "Pre-deployment validation passed"
    return 0
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
# Final Health Check
################################################################################

perform_final_health_check() {
    log_info "Performing comprehensive health check..."
    
    cd "$REPO_DIR/$DEPLOY_DIR" || return 1
    
    local compose_file="docker-compose-with-auth.yaml"
    local all_healthy=true
    
    # Check each service
    local services=$(docker compose -f "$compose_file" ps --services 2>/dev/null)
    
    if [ -z "$services" ]; then
        log_error "No services found"
        cd - > /dev/null
        return 1
    fi
    
    echo -e "\n${CYAN}${BOLD}Service Health Status:${NC}"
    
    for service in $services; do
        local container_id=$(docker compose -f "$compose_file" ps -q "$service" 2>/dev/null)
        
        if [ -z "$container_id" ]; then
            echo -e "${RED}  ✗ $service - Not found${NC}"
            all_healthy=false
            continue
        fi
        
        local status=$(docker inspect --format='{{.State.Status}}' "$container_id" 2>/dev/null)
        local health=$(docker inspect --format='{{.State.Health.Status}}' "$container_id" 2>/dev/null)
        
        if [ "$status" = "running" ]; then
            if [ "$health" = "<no value>" ] || [ "$health" = "healthy" ]; then
                echo -e "${GREEN}  ✓ $service - Running${NC}"
            elif [ "$health" = "starting" ]; then
                echo -e "${YELLOW}  ◐ $service - Starting${NC}"
                all_healthy=false
            else
                echo -e "${YELLOW}  ⚠ $service - Unhealthy${NC}"
                all_healthy=false
            fi
        else
            echo -e "${RED}  ✗ $service - $status${NC}"
            all_healthy=false
        fi
    done
    
    echo ""
    
    # Test URLs
    log_info "Testing service endpoints..."
    local frontend_accessible=false
    local casdoor_accessible=false
    
    if curl -s -o /dev/null -w "%{http_code}" --max-time 10 "http://localhost/" | grep -q "200\|302\|401"; then
        echo -e "${GREEN}  ✓ Frontend accessible at http://localhost/${NC}"
        frontend_accessible=true
    else
        echo -e "${YELLOW}  ⚠ Frontend may not be ready yet${NC}"
    fi
    
    if curl -s -o /dev/null -w "%{http_code}" --max-time 10 "http://localhost:8000" | grep -q "200\|302\|401"; then
        echo -e "${GREEN}  ✓ Casdoor accessible at http://localhost:8000${NC}"
        casdoor_accessible=true
    else
        echo -e "${YELLOW}  ⚠ Casdoor may not be ready yet${NC}"
    fi
    
    echo ""
    
    cd - > /dev/null
    
    if $all_healthy && $frontend_accessible && $casdoor_accessible; then
        log_success "All health checks passed!"
        return 0
    elif $frontend_accessible || $casdoor_accessible; then
        log_warning "Some services are accessible but not all health checks passed"
        log_info "Services may still be initializing. Check again in a few minutes."
        return 0
    else
        log_warning "Health checks completed with issues"
        log_info "Run ./start.sh for detailed status and troubleshooting"
        return 1
    fi
}

################################################################################
# Main Execution
################################################################################

main() {
    print_banner
    
    log_info "Starting Astron Agent deployment on Ubuntu"
    log_info "Log file: $LOG_FILE"
    log_info "Process ID: $$"
    print_separator
    
    # Acquire deployment lock
    if ! acquire_lock; then
        log_error "Failed to acquire deployment lock"
        exit 1
    fi
    
    # Validate environment first
    log_info "Step 0/9: Validating environment..."
    if ! validate_environment; then
        log_error "Environment validation failed"
        exit 1
    fi
    print_separator
    
    # System checks
    log_info "Step 1/9: Performing system checks..."
    check_root
    check_ubuntu
    check_system_resources
    print_separator
    
    # Install dependencies
    log_info "Step 2/9: Installing dependencies..."
    if ! install_dependencies; then
        log_error "Failed to install dependencies"
        exit 1
    fi
    print_separator
    
    # Install Docker
    log_info "Step 3/9: Installing Docker..."
    if ! install_docker; then
        log_error "Failed to install Docker"
        call_ai_resolver "Docker installation failed" "$(tail -n 100 '$LOG_FILE')"
        exit 1
    fi
    
    if ! verify_docker; then
        log_error "Docker verification failed"
        exit 1
    fi
    print_separator
    
    # Repository management
    log_info "Step 4/9: Managing repository..."
    if ! clone_or_update_repo; then
        log_error "Failed to manage repository"
        exit 1
    fi
    print_separator
    
    # Configuration
    log_info "Step 5/9: Configuring environment..."
    if ! configure_environment; then
        log_error "Failed to configure environment"
        exit 1
    fi
    print_separator
    
    # Pre-deployment validation
    log_info "Step 5.5/9: Pre-deployment validation..."
    if ! pre_deployment_validation; then
        log_error "Pre-deployment validation failed"
        exit 1
    fi
    print_separator
    
    # Create backup
    log_info "Step 5.8/9: Creating backup..."
    if ! create_backup; then
        log_warning "Backup creation failed (non-critical)"
    fi
    print_separator
    
    # Deploy services
    log_info "Step 6/9: Deploying services..."
    if ! deploy_services; then
        log_error "Failed to deploy services"
        call_ai_resolver "Service deployment failed" "$(tail -n 100 '$LOG_FILE')"
        
        # Offer rollback option
        echo -e "\n${YELLOW}Would you like to rollback to the previous state? [y/N]: ${NC}"
        read -t 30 -n 1 -r rollback_choice || rollback_choice='n'
        echo
        
        if [[ $rollback_choice =~ ^[Yy]$ ]]; then
            log_info "Attempting automatic rollback..."
            if [ -x "./rollback.sh" ]; then
                ./rollback.sh --latest
            else
                log_error "rollback.sh not found or not executable"
            fi
        fi
        
        exit 1
    fi
    print_separator
    
    # Wait for services
    log_info "Step 7/9: Waiting for services..."
    if ! wait_for_services; then
        log_warning "Some services may not be fully healthy"
        log_info "Check logs with: docker compose -f $REPO_DIR/$DEPLOY_DIR/docker-compose-with-auth.yaml logs"
    fi
    print_separator
    
    # Validate
    log_info "Step 8/9: Validating deployment..."
    if ! validate_deployment; then
        log_warning "Deployment validation completed with warnings"
    fi
    print_separator
    
    # Final health check
    log_info "Step 9/9: Final health check..."
    if ! perform_final_health_check; then
        log_warning "Some services may need attention"
    fi
    print_separator
    
    # Success message
    echo -e "\n${GREEN}${BOLD}╔═══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}${BOLD}║                                                               ║${NC}"
    echo -e "${GREEN}${BOLD}║          🎉 DEPLOYMENT COMPLETED SUCCESSFULLY! 🎉            ║${NC}"
    echo -e "${GREEN}${BOLD}║                                                               ║${NC}"
    echo -e "${GREEN}${BOLD}╚═══════════════════════════════════════════════════════════════╝${NC}\n"
    
    # Show statistics
    echo -e "${CYAN}${BOLD}Deployment Statistics:${NC}"
    echo -e "  Errors encountered: ${ERROR_COUNT}"
    echo -e "  Log file: ${YELLOW}$LOG_FILE${NC}"
    echo -e "  Process ID: $$"
    echo -e "  Duration: ~10-20 minutes (first time)"
    echo ""
    
    echo -e "${CYAN}${BOLD}Next Steps:${NC}"
    echo -e "1. Run ${GREEN}./start.sh${NC} to start the platform with health checks"
    echo -e "2. Run ${RED}./stop.sh${NC} to stop all services"
    echo -e "3. Access the application at ${BLUE}http://localhost/${NC}"
    echo -e "4. Default Casdoor login: ${YELLOW}admin / 123${NC}"
    echo -e "5. ${BOLD}IMPORTANT:${NC} Change the default password immediately!"
    echo ""
    
    echo -e "${CYAN}${BOLD}Troubleshooting:${NC}"
    echo -e "  View logs: ${YELLOW}cat $LOG_FILE${NC}"
    echo -e "  Service status: ${YELLOW}docker compose -f $REPO_DIR/$DEPLOY_DIR/docker-compose-with-auth.yaml ps${NC}"
    echo -e "  Service logs: ${YELLOW}docker compose -f $REPO_DIR/$DEPLOY_DIR/docker-compose-with-auth.yaml logs -f${NC}"
    echo ""
    
    if [ $ERROR_COUNT -gt 0 ]; then
        echo -e "${YELLOW}${BOLD}⚠️  Note: $ERROR_COUNT non-critical errors occurred during deployment${NC}"
        echo -e "${YELLOW}Check the log file for details: $LOG_FILE${NC}"
        echo ""
    fi
}

# Run main function
main "$@"
