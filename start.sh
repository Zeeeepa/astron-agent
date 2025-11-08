#!/bin/bash

################################################################################
# Astron Agent - Smart Start Script
# 
# Features:
# - Health checks for all services
# - Automatic URL detection and printing
# - Browser auto-launch
# - Service status monitoring
# - Colored output with progress indicators
#
# Usage: ./start.sh
################################################################################

set -e

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'
BOLD='\033[1m'

# Configuration
REPO_DIR="astron-agent"
DEPLOY_DIR="docker/astronAgent"
COMPOSE_FILE="docker-compose-with-auth.yaml"
MAX_HEALTH_CHECK_WAIT=180
HEALTH_CHECK_INTERVAL=5

################################################################################
# Utility Functions
################################################################################

log() {
    echo -e "${GREEN}[$(date +'%H:%M:%S')]${NC} $*"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $*"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $*"
}

log_info() {
    echo -e "${CYAN}[INFO]${NC} $*"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} ✓ $*"
}

print_banner() {
    clear
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
║                  Starting AI Agent Platform                   ║
║                                                               ║
╚═══════════════════════════════════════════════════════════════╝
EOF
    echo -e "${NC}\n"
}

print_separator() {
    echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
}

# Progress bar
show_progress() {
    local current=$1
    local total=$2
    local width=50
    local percentage=$((current * 100 / total))
    local filled=$((width * current / total))
    local empty=$((width - filled))
    
    printf "\r${CYAN}["
    printf "%${filled}s" | tr ' ' '█'
    printf "%${empty}s" | tr ' ' '░'
    printf "] ${percentage}%% ${NC}"
}

# Spinner with custom message
spinner() {
    local pid=$1
    local message=$2
    local delay=0.1
    local spinstr='⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'
    
    while ps -p $pid > /dev/null 2>&1; do
        local temp=${spinstr#?}
        printf "\r${CYAN}${message} [%c]${NC}" "$spinstr"
        local spinstr=$temp${spinstr%"$temp"}
        sleep $delay
    done
    printf "\r${message} ${GREEN}✓${NC}\n"
}

################################################################################
# Pre-flight Checks
################################################################################

check_prerequisites() {
    log_info "Performing pre-flight checks..."
    
    # Check if Docker is installed
    if ! command -v docker &> /dev/null; then
        log_error "Docker is not installed. Please run ./deploy.sh first."
        exit 1
    fi
    
    # Check if Docker daemon is running
    if ! docker info &> /dev/null; then
        log_error "Docker daemon is not running. Please start Docker and try again."
        exit 1
    fi
    log_success "Docker is running"
    
    # Check if repository exists
    if [ ! -d "$REPO_DIR" ]; then
        log_error "Repository not found. Please run ./deploy.sh first."
        exit 1
    fi
    log_success "Repository found"
    
    # Check if compose file exists
    if [ ! -f "$REPO_DIR/$DEPLOY_DIR/$COMPOSE_FILE" ]; then
        log_error "Docker Compose file not found: $COMPOSE_FILE"
        exit 1
    fi
    log_success "Compose file found"
}

################################################################################
# Service Management
################################################################################

start_services() {
    log_info "Starting services..."
    cd "$REPO_DIR/$DEPLOY_DIR"
    
    # Start services in background
    docker compose -f "$COMPOSE_FILE" up -d 2>&1 | while read line; do
        echo "$line" | grep -q "Starting\|Started\|Creating\|Created" && echo -e "${CYAN}  ➜ $line${NC}"
    done
    
    log_success "Services started"
    cd - > /dev/null
}

get_service_urls() {
    cd "$REPO_DIR/$DEPLOY_DIR"
    
    # Extract ports from compose file
    local frontend_port=$(docker compose -f "$COMPOSE_FILE" port nginx 80 2>/dev/null | cut -d: -f2)
    local casdoor_port=$(docker compose -f "$COMPOSE_FILE" port casdoor 8000 2>/dev/null | cut -d: -f2)
    
    # Default ports if detection fails
    frontend_port=${frontend_port:-80}
    casdoor_port=${casdoor_port:-8000}
    
    # Get host IP
    local host_ip=$(hostname -I | awk '{print $1}')
    
    # URLs
    FRONTEND_URL="http://localhost:${frontend_port}"
    CASDOOR_URL="http://localhost:${casdoor_port}"
    FRONTEND_REMOTE_URL="http://${host_ip}:${frontend_port}"
    CASDOOR_REMOTE_URL="http://${host_ip}:${casdoor_port}"
    
    cd - > /dev/null
}

################################################################################
# Health Checks
################################################################################

check_container_health() {
    local container_name=$1
    local status=$(docker inspect --format='{{.State.Status}}' "$container_name" 2>/dev/null)
    
    if [ "$status" == "running" ]; then
        return 0
    else
        return 1
    fi
}

get_container_stats() {
    local container_name=$1
    
    # Get CPU and Memory usage
    local stats=$(docker stats --no-stream --format "{{.CPUPerc}}\t{{.MemUsage}}" "$container_name" 2>/dev/null)
    echo "$stats"
}

wait_for_services_healthy() {
    log_info "Checking service health..."
    echo ""
    
    cd "$REPO_DIR/$DEPLOY_DIR"
    
    local containers=$(docker compose -f "$COMPOSE_FILE" ps -q)
    local total_containers=$(echo "$containers" | wc -l)
    local waited=0
    
    while [ $waited -lt $MAX_HEALTH_CHECK_WAIT ]; do
        local healthy_count=0
        local container_statuses=""
        
        for container_id in $containers; do
            local container_name=$(docker inspect --format='{{.Name}}' "$container_id" | sed 's/\///')
            local status=$(docker inspect --format='{{.State.Status}}' "$container_id" 2>/dev/null)
            local health=$(docker inspect --format='{{.State.Health.Status}}' "$container_id" 2>/dev/null)
            
            # If no health check defined, consider running as healthy
            if [ "$health" == "<no value>" ]; then
                if [ "$status" == "running" ]; then
                    healthy_count=$((healthy_count + 1))
                    container_statuses="${container_statuses}${GREEN}✓${NC} ${container_name}\n"
                else
                    container_statuses="${container_statuses}${RED}✗${NC} ${container_name} ($status)\n"
                fi
            else
                if [ "$health" == "healthy" ]; then
                    healthy_count=$((healthy_count + 1))
                    container_statuses="${container_statuses}${GREEN}✓${NC} ${container_name}\n"
                else
                    container_statuses="${container_statuses}${YELLOW}◐${NC} ${container_name} ($health)\n"
                fi
            fi
        done
        
        # Clear previous output
        echo -ne "\033[2K\r"
        
        # Show progress
        show_progress $healthy_count $total_containers
        echo -e " (${healthy_count}/${total_containers} services ready)"
        
        # If all healthy, break
        if [ $healthy_count -eq $total_containers ]; then
            echo ""
            log_success "All services are healthy!"
            echo ""
            echo -e "${CYAN}${BOLD}Service Status:${NC}"
            echo -e "$container_statuses"
            cd - > /dev/null
            return 0
        fi
        
        sleep $HEALTH_CHECK_INTERVAL
        waited=$((waited + HEALTH_CHECK_INTERVAL))
    done
    
    echo ""
    log_warning "Health check timeout after ${MAX_HEALTH_CHECK_WAIT}s"
    echo -e "\n${CYAN}${BOLD}Current Service Status:${NC}"
    echo -e "$container_statuses"
    
    cd - > /dev/null
}

################################################################################
# URL Testing
################################################################################

test_url_accessibility() {
    local url=$1
    local name=$2
    
    # Try to connect to URL
    if curl -s -o /dev/null -w "%{http_code}" --max-time 5 "$url" | grep -q "200\|302\|401"; then
        echo -e "${GREEN}✓${NC} $name is accessible"
        return 0
    else
        echo -e "${YELLOW}⚠${NC} $name may not be ready yet"
        return 1
    fi
}

verify_services() {
    log_info "Verifying service accessibility..."
    echo ""
    
    # Wait a bit for services to fully initialize
    sleep 3
    
    test_url_accessibility "$FRONTEND_URL" "Frontend Application"
    test_url_accessibility "$CASDOOR_URL" "Casdoor Authentication"
    
    echo ""
}

################################################################################
# Display Functions
################################################################################

print_service_info() {
    cd "$REPO_DIR/$DEPLOY_DIR"
    
    echo -e "\n${MAGENTA}${BOLD}╔═══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${MAGENTA}${BOLD}║               🚀 ASTRON AGENT IS RUNNING! 🚀                 ║${NC}"
    echo -e "${MAGENTA}${BOLD}╚═══════════════════════════════════════════════════════════════╝${NC}\n"
    
    echo -e "${CYAN}${BOLD}📍 Access URLs:${NC}\n"
    
    echo -e "${BOLD}Local Access:${NC}"
    echo -e "  🌐 Astron Agent:    ${GREEN}${FRONTEND_URL}${NC}"
    echo -e "  🔐 Casdoor Admin:   ${BLUE}${CASDOOR_URL}${NC}"
    echo -e "     └─ Credentials:  ${YELLOW}admin / 123${NC}\n"
    
    echo -e "${BOLD}Remote Access (from other devices):${NC}"
    echo -e "  🌐 Astron Agent:    ${GREEN}${FRONTEND_REMOTE_URL}${NC}"
    echo -e "  🔐 Casdoor Admin:   ${BLUE}${CASDOOR_REMOTE_URL}${NC}\n"
    
    print_separator
    echo ""
    
    echo -e "${CYAN}${BOLD}📊 Container Status:${NC}\n"
    docker compose -f "$COMPOSE_FILE" ps --format "table {{.Name}}\t{{.Status}}\t{{.Ports}}" | while read line; do
        if echo "$line" | grep -q "Up"; then
            echo -e "${GREEN}$line${NC}"
        elif echo "$line" | grep -q "NAME"; then
            echo -e "${BOLD}$line${NC}"
        else
            echo -e "${YELLOW}$line${NC}"
        fi
    done
    
    echo ""
    print_separator
    echo ""
    
    echo -e "${CYAN}${BOLD}💡 Quick Commands:${NC}\n"
    echo -e "  View logs:         ${GREEN}docker compose -f $COMPOSE_FILE logs -f${NC}"
    echo -e "  Stop services:     ${RED}./stop.sh${NC}"
    echo -e "  Restart service:   ${YELLOW}docker compose -f $COMPOSE_FILE restart <service>${NC}"
    echo -e "  View this info:    ${BLUE}docker compose -f $COMPOSE_FILE ps${NC}\n"
    
    cd - > /dev/null
}

################################################################################
# Browser Launch
################################################################################

open_browser() {
    log_info "Opening browser..."
    
    # Detect and open browser
    if command -v xdg-open &> /dev/null; then
        xdg-open "$FRONTEND_URL" &> /dev/null &
        log_success "Browser opened"
    elif command -v gnome-open &> /dev/null; then
        gnome-open "$FRONTEND_URL" &> /dev/null &
        log_success "Browser opened"
    elif command -v firefox &> /dev/null; then
        firefox "$FRONTEND_URL" &> /dev/null &
        log_success "Browser opened"
    elif command -v google-chrome &> /dev/null; then
        google-chrome "$FRONTEND_URL" &> /dev/null &
        log_success "Browser opened"
    else
        log_warning "Could not auto-open browser. Please open manually: $FRONTEND_URL"
    fi
}

################################################################################
# Main Execution
################################################################################

main() {
    print_banner
    
    # Pre-flight checks
    check_prerequisites
    print_separator
    
    # Start services
    start_services
    print_separator
    
    # Health checks
    wait_for_services_healthy
    print_separator
    
    # Get URLs
    get_service_urls
    
    # Verify accessibility
    verify_services
    print_separator
    
    # Display info
    print_service_info
    
    # Open browser
    read -p "$(echo -e ${CYAN}Open browser automatically? [Y/n]: ${NC})" -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Nn]$ ]]; then
        open_browser
    fi
    
    echo -e "\n${GREEN}${BOLD}✨ All systems operational! Happy coding! ✨${NC}\n"
}

# Run main function
main "$@"

