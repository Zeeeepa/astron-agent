#!/usr/bin/env bash

#############################################################################
# Astron Agent - Start Script (Enhanced for Docker Services)
#############################################################################
# This script starts all Astron Agent Docker services and displays access URLs
# Usage: ./start.sh
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
echo "    ║            Astron Agent - Start Script                   ║"
echo "    ║                                                           ║"
echo "    ║         Enterprise AI Agent Development Platform          ║"
echo "    ║                                                           ║"
echo "    ╚═══════════════════════════════════════════════════════════╝"
echo -e "${NC}\n"

#############################################################################
# Detect repository root and navigate to Docker directory
#############################################################################

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
REPO_ROOT="${SCRIPT_DIR}"
DOCKER_DIR="${REPO_ROOT}/docker/astronAgent"

if [ ! -d "${DOCKER_DIR}" ]; then
    print_error "Docker directory not found: ${DOCKER_DIR}"
    print_info "Please run this script from the repository root"
    exit 1
fi

cd "${DOCKER_DIR}"

#############################################################################
# Check prerequisites
#############################################################################

check_prerequisites() {
    print_header "Checking Prerequisites"
    
    # Check if .env exists
    if [ ! -f ".env" ]; then
        print_error ".env file not found"
        print_info "Please run ./setup.sh first to configure the environment"
        exit 1
    fi
    print_success ".env file found"
    
    # Check Docker
    if ! command -v docker &> /dev/null; then
        print_error "Docker is not installed"
        exit 1
    fi
    print_success "Docker is available"
    
    # Determine compose command
    if command -v docker-compose &> /dev/null; then
        COMPOSE_CMD="docker-compose"
    elif docker compose version &> /dev/null 2>&1; then
        COMPOSE_CMD="docker compose"
    else
        print_error "Docker Compose is not available"
        exit 1
    fi
    export COMPOSE_CMD
    print_success "Docker Compose: ${COMPOSE_CMD}"
    
    # Check Docker daemon
    if ! docker info &> /dev/null 2>&1; then
        print_error "Docker daemon is not running"
        print_info "Please start Docker first"
        exit 1
    fi
    print_success "Docker daemon is running"
}

#############################################################################
# Start services
#############################################################################

start_services() {
    print_header "Starting Services"
    
    print_info "Starting all Astron Agent services..."
    print_info "This may take 5-10 minutes for first-time startup"
    print_info "Services will start in dependency order with health checks"
    echo ""
    
    # Start all services
    if ${COMPOSE_CMD} up -d; then
        print_success "Services started"
    else
        print_error "Failed to start services"
        print_info "Check logs with: ./logs.sh"
        exit 1
    fi
}

#############################################################################
# Wait for services to be healthy
#############################################################################

wait_for_services() {
    print_header "Waiting for Services"
    
    print_info "Waiting for services to become healthy..."
    print_info "This may take a few minutes..."
    echo ""
    
    # Key services to check
    CRITICAL_SERVICES=(
        "astron-agent-postgres"
        "astron-agent-mysql"
        "astron-agent-redis"
        "astron-agent-nginx"
    )
    
    MAX_WAIT=300  # 5 minutes
    ELAPSED=0
    CHECK_INTERVAL=10
    
    while [ $ELAPSED -lt $MAX_WAIT ]; do
        ALL_HEALTHY=true
        
        for service in "${CRITICAL_SERVICES[@]}"; do
            HEALTH=$(docker inspect --format='{{.State.Health.Status}}' "${service}" 2>/dev/null || echo "no-healthcheck")
            
            if [ "${HEALTH}" == "healthy" ] || [ "${HEALTH}" == "no-healthcheck" ]; then
                STATUS=$(docker inspect --format='{{.State.Status}}' "${service}" 2>/dev/null || echo "unknown")
                if [ "${STATUS}" != "running" ]; then
                    ALL_HEALTHY=false
                    break
                fi
            else
                ALL_HEALTHY=false
                break
            fi
        done
        
        if [ "${ALL_HEALTHY}" = true ]; then
            echo ""
            print_success "All critical services are healthy!"
            return 0
        fi
        
        echo -ne "\r${CYAN}ℹ${NC} Waiting... ${ELAPSED}s / ${MAX_WAIT}s "
        sleep $CHECK_INTERVAL
        ELAPSED=$((ELAPSED + CHECK_INTERVAL))
    done
    
    echo ""
    print_warning "Timeout waiting for services to be healthy"
    print_info "Services may still be starting up"
    print_info "Check status with: ./status.sh"
    print_info "Check logs with: ./logs.sh"
}

#############################################################################
# Get service status
#############################################################################

get_service_status() {
    print_header "Service Status"
    
    # Get all running containers
    RUNNING=$(docker ps --filter "name=astron-agent-" --format "table {{.Names}}\t{{.Status}}" | grep -v NAMES | wc -l)
    TOTAL=$(${COMPOSE_CMD} config --services | wc -l)
    
    print_info "Services running: ${RUNNING} / ${TOTAL}"
    echo ""
    
    # Show service table
    docker ps --filter "name=astron-agent-" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" | head -20
    
    if [ $RUNNING -lt $TOTAL ]; then
        echo ""
        print_warning "Not all services are running"
        print_info "Run './status.sh' for detailed status"
        print_info "Run './logs.sh <service-name>' to check specific service logs"
    fi
}

#############################################################################
# Display access URLs
#############################################################################

display_urls() {
    print_header "Access Information"
    
    # Get host IP for URLs
    if command -v hostname &> /dev/null; then
        HOSTNAME=$(hostname -I 2>/dev/null | awk '{print $1}' || echo "localhost")
    else
        HOSTNAME="localhost"
    fi
    
    # Read ports from .env
    source .env 2>/dev/null || true
    
    NGINX_PORT=${EXPOSE_NGINX_PORT:-80}
    MINIO_PORT=${EXPOSE_MINIO_PORT:-19000}
    MINIO_CONSOLE_PORT=${EXPOSE_MINIO_CONSOLE_PORT:-19001}
    KAFKA_PORT=${EXPOSE_KAFKA_PORT:-9092}
    
    echo -e "${GREEN}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}  🎉 Astron Agent is Ready!${NC}"
    echo -e "${GREEN}═══════════════════════════════════════════════════════════════${NC}"
    echo ""
    
    echo -e "${CYAN}🌐 Main Console:${NC}"
    if [ "${NGINX_PORT}" == "80" ]; then
        echo -e "   ${GREEN}➜${NC} ${BLUE}http://${HOSTNAME}${NC}"
        echo -e "   ${GREEN}➜${NC} ${BLUE}http://localhost${NC}"
    else
        echo -e "   ${GREEN}➜${NC} ${BLUE}http://${HOSTNAME}:${NGINX_PORT}${NC}"
        echo -e "   ${GREEN}➜${NC} ${BLUE}http://localhost:${NGINX_PORT}${NC}"
    fi
    echo ""
    
    echo -e "${CYAN}🗄️  MinIO Console (Object Storage):${NC}"
    echo -e "   ${GREEN}➜${NC} ${BLUE}http://${HOSTNAME}:${MINIO_CONSOLE_PORT}${NC}"
    echo -e "   ${GREEN}➜${NC} ${BLUE}http://localhost:${MINIO_CONSOLE_PORT}${NC}"
    echo -e "   ${YELLOW}📝${NC} Username: ${MINIO_ROOT_USER:-minioadmin}"
    echo -e "   ${YELLOW}📝${NC} Password: ${MINIO_ROOT_PASSWORD:-minioadmin123}"
    echo ""
    
    echo -e "${CYAN}📊 Service Endpoints:${NC}"
    echo -e "   ${BLUE}•${NC} Kafka: ${BLUE}localhost:${KAFKA_PORT}${NC}"
    echo -e "   ${BLUE}•${NC} MySQL: ${BLUE}localhost:3306${NC}"
    echo -e "   ${BLUE}•${NC} PostgreSQL: ${BLUE}localhost:5432${NC}"
    echo -e "   ${BLUE}•${NC} Redis: ${BLUE}localhost:6379${NC}"
    echo -e "   ${BLUE}•${NC} Elasticsearch: ${BLUE}localhost:9200${NC}"
    echo -e "   ${BLUE}•${NC} MinIO API: ${BLUE}localhost:${MINIO_PORT}${NC}"
    echo ""
    
    echo -e "${CYAN}🔧 Management Commands:${NC}"
    echo -e "   ${BLUE}•${NC} Check status: ${YELLOW}./status.sh${NC}"
    echo -e "   ${BLUE}•${NC} View logs: ${YELLOW}./logs.sh${NC}"
    echo -e "   ${BLUE}•${NC} View specific service: ${YELLOW}./logs.sh <service-name>${NC}"
    echo -e "   ${BLUE}•${NC} Stop services: ${YELLOW}./stop.sh${NC}"
    echo -e "   ${BLUE}•${NC} Restart services: ${YELLOW}./start.sh${NC}"
    echo ""
    
    echo -e "${CYAN}📚 Documentation:${NC}"
    echo -e "   ${BLUE}•${NC} Deployment Guide: ${YELLOW}DEPLOYMENT_WSL2.md${NC}"
    echo -e "   ${BLUE}•${NC} Chinese Guide: ${YELLOW}docker/DEPLOYMENT_GUIDE_zh.md${NC}"
    echo -e "   ${BLUE}•${NC} Verification Report: ${YELLOW}VERIFICATION_REPORT.md${NC}"
    echo ""
    
    echo -e "${CYAN}💡 Tips:${NC}"
    echo -e "   ${BLUE}•${NC} First-time login may require account creation"
    echo -e "   ${BLUE}•${NC} Console UI defaults to ${GREEN}English${NC}"
    echo -e "   ${BLUE}•${NC} Use language selector to switch to Chinese"
    echo -e "   ${BLUE}•${NC} Check ${YELLOW}.env${NC} file for service credentials"
    echo ""
    
    echo -e "${YELLOW}⚠${NC}  ${CYAN}Important:${NC}"
    echo -e "   ${BLUE}•${NC} Services run in background - use ${YELLOW}./stop.sh${NC} to stop"
    echo -e "   ${BLUE}•${NC} Data persists in Docker volumes"
    echo -e "   ${BLUE}•${NC} Run ${YELLOW}./start.sh${NC} after WSL2 restart"
    echo ""
}

#############################################################################
# WSL2 Auto-start Helper
#############################################################################

suggest_autostart() {
    if [ -f /proc/sys/fs/binfmt_misc/WSLInterop ]; then
        echo -e "${CYAN}💡 WSL2 Auto-Start Tip:${NC}"
        echo ""
        echo -e "To automatically start services when WSL2 starts, add this to your ${YELLOW}~/.bashrc${NC}:"
        echo ""
        echo -e "${BLUE}  # Auto-start Astron Agent"
        echo -e "  if [ -f \"${REPO_ROOT}/start.sh\" ]; then"
        echo -e "    cd \"${REPO_ROOT}\" && ./start.sh"
        echo -e "  fi${NC}"
        echo ""
        echo -e "Or manually run ${YELLOW}./start.sh${NC} each time you start WSL2"
        echo ""
    fi
}

#############################################################################
# Main Execution
#############################################################################

main() {
    check_prerequisites
    start_services
    wait_for_services
    get_service_status
    display_urls
    suggest_autostart
}

# Run main function
main

exit 0

