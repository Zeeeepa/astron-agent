#!/bin/bash

################################################################################
# Astron Agent - Smart Stop Script
# 
# Features:
# - Graceful shutdown of all services
# - Cleanup of resources
# - Health status verification
# - Colored output with progress indicators
#
# Usage: ./stop.sh [--clean]
#        --clean: Also remove volumes and orphan containers
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
CLEAN_MODE=false

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --clean)
            CLEAN_MODE=true
            shift
            ;;
        *)
            echo "Unknown option: $1"
            echo "Usage: $0 [--clean]"
            exit 1
            ;;
    esac
done

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
    echo -e "${RED}${BOLD}"
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
║                  Stopping AI Agent Platform                   ║
║                                                               ║
╚═══════════════════════════════════════════════════════════════╝
EOF
    echo -e "${NC}\n"
}

print_separator() {
    echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
}

# Progress spinner
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
# Pre-stop Checks
################################################################################

check_prerequisites() {
    log_info "Checking prerequisites..."
    
    # Check if Docker is installed
    if ! command -v docker &> /dev/null; then
        log_error "Docker is not installed."
        exit 1
    fi
    
    # Check if Docker daemon is running
    if ! docker info &> /dev/null; then
        log_error "Docker daemon is not running."
        exit 1
    fi
    log_success "Docker is running"
    
    # Check if repository exists
    if [ ! -d "$REPO_DIR" ]; then
        log_error "Repository not found: $REPO_DIR"
        exit 1
    fi
    log_success "Repository found"
    
    # Check if in deployment directory
    if [ ! -f "$REPO_DIR/$DEPLOY_DIR/$COMPOSE_FILE" ]; then
        log_error "Docker Compose file not found: $COMPOSE_FILE"
        exit 1
    fi
    log_success "Compose file found"
}

################################################################################
# Service Status
################################################################################

show_current_status() {
    log_info "Current service status..."
    echo ""
    
    cd "$REPO_DIR/$DEPLOY_DIR"
    
    # Get running containers
    local containers=$(docker compose -f "$COMPOSE_FILE" ps -q 2>/dev/null)
    
    if [ -z "$containers" ]; then
        log_info "No services are currently running"
        return
    fi
    
    # Show container status with colors
    echo -e "${CYAN}${BOLD}Running Services:${NC}\n"
    docker compose -f "$COMPOSE_FILE" ps --format "table {{.Name}}\t{{.Status}}\t{{.Ports}}" | while read line; do
        if echo "$line" | grep -q "Up"; then
            echo -e "${GREEN}  ➜ $line${NC}"
        elif echo "$line" | grep -q "NAME"; then
            echo -e "${BOLD}  $line${NC}"
        else
            echo -e "${YELLOW}  ➜ $line${NC}"
        fi
    done
    
    echo ""
    cd - > /dev/null
}

################################################################################
# Shutdown Process
################################################################################

stop_services() {
    cd "$REPO_DIR/$DEPLOY_DIR"
    
    # Check if any services are running
    local containers=$(docker compose -f "$COMPOSE_FILE" ps -q 2>/dev/null)
    
    if [ -z "$containers" ]; then
        log_info "No services to stop"
        cd - > /dev/null
        return
    fi
    
    log_info "Stopping services gracefully..."
    
    # Get list of services for progress tracking
    local services=$(docker compose -f "$COMPOSE_FILE" ps --services)
    local total_services=$(echo "$services" | wc -l)
    local stopped=0
    
    # Stop services with timeout
    docker compose -f "$COMPOSE_FILE" stop --timeout 30 2>&1 | while read line; do
        if echo "$line" | grep -q "Stopping\|Stopped"; then
            stopped=$((stopped + 1))
            local service_name=$(echo "$line" | awk '{print $2}')
            echo -e "${YELLOW}  ⏸  Stopping: $service_name${NC}"
        fi
    done
    
    log_success "All services stopped"
    cd - > /dev/null
}

remove_containers() {
    cd "$REPO_DIR/$DEPLOY_DIR"
    
    log_info "Removing containers..."
    
    if $CLEAN_MODE; then
        # Remove containers, networks, and orphans
        docker compose -f "$COMPOSE_FILE" down --remove-orphans 2>&1 | while read line; do
            echo -e "${CYAN}  ➜ $line${NC}"
        done
    else
        # Just remove containers
        docker compose -f "$COMPOSE_FILE" down 2>&1 | while read line; do
            echo -e "${CYAN}  ➜ $line${NC}"
        done
    fi
    
    log_success "Containers removed"
    cd - > /dev/null
}

clean_volumes() {
    if ! $CLEAN_MODE; then
        return
    fi
    
    cd "$REPO_DIR/$DEPLOY_DIR"
    
    log_warning "Cleaning volumes (all data will be lost)..."
    
    read -p "$(echo -e ${RED}Are you sure? This will delete all data! [y/N]: ${NC})" -n 1 -r
    echo
    
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        docker compose -f "$COMPOSE_FILE" down -v 2>&1 | while read line; do
            echo -e "${RED}  ➜ $line${NC}"
        done
        log_success "Volumes removed"
    else
        log_info "Volume cleanup cancelled"
    fi
    
    cd - > /dev/null
}

################################################################################
# Verification
################################################################################

verify_shutdown() {
    log_info "Verifying shutdown..."
    
    cd "$REPO_DIR/$DEPLOY_DIR"
    
    # Check if any containers are still running
    local running_containers=$(docker compose -f "$COMPOSE_FILE" ps -q 2>/dev/null)
    
    if [ -z "$running_containers" ]; then
        log_success "All services have been stopped"
    else
        log_warning "Some containers may still be running"
        docker compose -f "$COMPOSE_FILE" ps
    fi
    
    cd - > /dev/null
}

################################################################################
# Resource Cleanup
################################################################################

show_resource_usage() {
    log_info "Docker resource usage..."
    echo ""
    
    # Show disk usage
    echo -e "${CYAN}${BOLD}Docker Disk Usage:${NC}"
    docker system df
    
    echo ""
    
    # Offer cleanup
    if $CLEAN_MODE; then
        log_info "Clean mode enabled - removing unused resources..."
        docker system prune -f --volumes 2>&1 | while read line; do
            echo -e "${CYAN}  ➜ $line${NC}"
        done
        log_success "Unused resources removed"
    else
        echo -e "${YELLOW}Tip: Run with --clean flag to remove all volumes and unused resources${NC}"
    fi
}

################################################################################
# Main Execution
################################################################################

main() {
    print_banner
    
    if $CLEAN_MODE; then
        echo -e "${RED}${BOLD}⚠️  CLEAN MODE ENABLED - Will remove volumes! ⚠️${NC}\n"
    fi
    
    # Pre-stop checks
    check_prerequisites
    print_separator
    
    # Show current status
    show_current_status
    print_separator
    
    # Confirmation
    if $CLEAN_MODE; then
        echo -e "${RED}${BOLD}WARNING: Clean mode will remove all data!${NC}"
    fi
    
    read -p "$(echo -e ${YELLOW}Proceed with shutdown? [Y/n]: ${NC})" -n 1 -r
    echo
    
    if [[ $REPLY =~ ^[Nn]$ ]]; then
        log_info "Shutdown cancelled"
        exit 0
    fi
    
    print_separator
    
    # Stop services
    stop_services
    print_separator
    
    # Remove containers
    remove_containers
    print_separator
    
    # Clean volumes if requested
    if $CLEAN_MODE; then
        clean_volumes
        print_separator
    fi
    
    # Verify shutdown
    verify_shutdown
    print_separator
    
    # Show resource usage
    show_resource_usage
    print_separator
    
    # Success message
    echo -e "\n${GREEN}${BOLD}╔═══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}${BOLD}║                                                               ║${NC}"
    echo -e "${GREEN}${BOLD}║          🛑 ALL SERVICES STOPPED SUCCESSFULLY! 🛑            ║${NC}"
    echo -e "${GREEN}${BOLD}║                                                               ║${NC}"
    echo -e "${GREEN}${BOLD}╚═══════════════════════════════════════════════════════════════╝${NC}\n"
    
    echo -e "${CYAN}${BOLD}Next Steps:${NC}"
    echo -e "  Start services:    ${GREEN}./start.sh${NC}"
    echo -e "  Full redeployment: ${BLUE}./deploy.sh${NC}"
    
    if ! $CLEAN_MODE; then
        echo -e "  Clean volumes:     ${RED}./stop.sh --clean${NC}"
    fi
    
    echo ""
}

# Run main function
main "$@"

