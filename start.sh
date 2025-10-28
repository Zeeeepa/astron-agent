#!/usr/bin/env bash

#############################################################################
# Astron Agent - Start Script (Enhanced with Health Monitoring)
#############################################################################
# This script starts all Astron Agent Docker services with continuous monitoring
# Usage: ./start.sh [--watch]
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
GRAY='\033[0;90m'
NC='\033[0m' # No Color

# Watch mode flag
WATCH_MODE=false
if [[ "$1" == "--watch" ]]; then
    WATCH_MODE=true
fi

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
echo "    ║         with Real-Time Health Monitoring                  ║"
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
    if ${COMPOSE_CMD} up -d 2>&1 | grep -v "variable is not set" | grep -v "attribute.*version.*is obsolete"; then
        print_success "Services started"
    else
        print_error "Failed to start services"
        print_info "Check logs with: ./logs.sh"
        exit 1
    fi
    
    echo ""
    print_info "Monitoring service startup..."
    echo ""
    
    # Show startup progress
    show_startup_progress
}

#############################################################################
# Show startup progress
#############################################################################

show_startup_progress() {
    local ALL_SERVICES=(
        "astron-agent-postgres:PostgreSQL"
        "astron-agent-mysql:MySQL"
        "astron-agent-redis:Redis"
        "astron-agent-elasticsearch:Elasticsearch"
        "astron-agent-kafka:Kafka"
        "astron-agent-minio:MinIO"
        "astron-agent-core-tenant:Tenant Service"
        "astron-agent-core-database:Database Service"
        "astron-agent-core-rpa:RPA Service"
        "astron-agent-core-link:Link Service"
        "astron-agent-core-aitools:AI Tools Service"
        "astron-agent-core-agent:Agent Service"
        "astron-agent-core-knowledge:Knowledge Service"
        "astron-agent-core-workflow:Workflow Service"
        "astron-agent-nginx:Nginx Gateway"
        "astron-agent-console-frontend:Frontend"
        "astron-agent-console-hub:Hub"
    )
    
    local MAX_WAIT=60  # Wait up to 60 seconds for initial startup
    local ELAPSED=0
    
    while [ $ELAPSED -lt $MAX_WAIT ]; do
        local ALL_STARTED=true
        
        for service_info in "${ALL_SERVICES[@]}"; do
            local CONTAINER_NAME="${service_info%%:*}"
            local DISPLAY_NAME="${service_info##*:}"
            
            if docker ps --format "{{.Names}}" | grep -q "^${CONTAINER_NAME}$"; then
                local STATUS=$(docker inspect --format='{{.State.Status}}' "${CONTAINER_NAME}" 2>/dev/null)
                local HEALTH=$(docker inspect --format='{{.State.Health.Status}}' "${CONTAINER_NAME}" 2>/dev/null || echo "no-check")
                
                if [ "${STATUS}" == "running" ]; then
                    if [ "${HEALTH}" == "healthy" ]; then
                        echo -e "  ${GREEN}✓${NC} ${DISPLAY_NAME} - ${GREEN}Healthy${NC}"
                    elif [ "${HEALTH}" == "starting" ]; then
                        echo -e "  ${YELLOW}◐${NC} ${DISPLAY_NAME} - ${YELLOW}Starting...${NC}"
                        ALL_STARTED=false
                    elif [ "${HEALTH}" == "no-check" ]; then
                        echo -e "  ${GREEN}✓${NC} ${DISPLAY_NAME} - ${GREEN}Running${NC}"
                    else
                        echo -e "  ${CYAN}○${NC} ${DISPLAY_NAME} - ${GRAY}${STATUS}${NC}"
                        ALL_STARTED=false
                    fi
                else
                    echo -e "  ${GRAY}○${NC} ${DISPLAY_NAME} - ${GRAY}${STATUS}${NC}"
                    ALL_STARTED=false
                fi
            else
                echo -e "  ${GRAY}○${NC} ${DISPLAY_NAME} - ${GRAY}Starting...${NC}"
                ALL_STARTED=false
            fi
        done
        
        if [ "${ALL_STARTED}" = true ]; then
            echo ""
            print_success "All services are starting up!"
            return 0
        fi
        
        sleep 3
        ELAPSED=$((ELAPSED + 3))
        
        if [ $ELAPSED -lt $MAX_WAIT ]; then
            # Clear previous output and redraw (simple refresh)
            echo ""
            echo -ne "${GRAY}Refreshing status...${NC}\r"
            sleep 1
            echo ""
        fi
    done
    
    echo ""
    print_warning "Some services are still starting up"
    print_info "This is normal - health checks continue in background"
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
    print_info "Check status with: status-agent or ./status.sh"
    print_info "Check logs with: logs-agent or ./logs.sh"
}

#############################################################################
# Get detailed service status
#############################################################################

get_service_status() {
    print_header "Service Status"
    
    # Source .env for port configuration
    source .env 2>/dev/null || true
    
    # Get all containers
    local ALL_CONTAINERS=$(docker ps -a --filter "name=astron-agent-" --format "{{.Names}}")
    local RUNNING_CONTAINERS=$(docker ps --filter "name=astron-agent-" --format "{{.Names}}")
    
    local TOTAL=$(echo "$ALL_CONTAINERS" | wc -l)
    local RUNNING=$(echo "$RUNNING_CONTAINERS" | wc -l)
    
    echo -e "${CYAN}Overview:${NC} ${GREEN}${RUNNING}${NC} / ${TOTAL} services running"
    echo ""
    
    # Show detailed status for each service
    echo -e "${CYAN}Service Details:${NC}"
    echo ""
    
    # Infrastructure services
    echo -e "${MAGENTA}Infrastructure Services:${NC}"
    check_service_health "astron-agent-postgres" "PostgreSQL"
    check_service_health "astron-agent-mysql" "MySQL"
    check_service_health "astron-agent-redis" "Redis"
    check_service_health "astron-agent-elasticsearch" "Elasticsearch"
    check_service_health "astron-agent-kafka" "Kafka"
    check_service_health "astron-agent-minio" "MinIO"
    echo ""
    
    # Core services
    echo -e "${MAGENTA}Core Services:${NC}"
    check_service_health "astron-agent-core-tenant" "Tenant Service"
    check_service_health "astron-agent-core-database" "Database Service"
    check_service_health "astron-agent-core-rpa" "RPA Service"
    check_service_health "astron-agent-core-link" "Link Service"
    check_service_health "astron-agent-core-aitools" "AI Tools Service"
    check_service_health "astron-agent-core-agent" "Agent Service"
    check_service_health "astron-agent-core-knowledge" "Knowledge Service"
    check_service_health "astron-agent-core-workflow" "Workflow Service"
    echo ""
    
    # Console services
    echo -e "${MAGENTA}Console Services:${NC}"
    check_service_health "astron-agent-nginx" "Nginx Gateway"
    check_service_health "astron-agent-console-frontend" "Frontend"
    check_service_health "astron-agent-console-hub" "Hub"
    echo ""
}

#############################################################################
# Check individual service health
#############################################################################

check_service_health() {
    local CONTAINER_NAME=$1
    local DISPLAY_NAME=$2
    
    if docker ps --format "{{.Names}}" | grep -q "^${CONTAINER_NAME}$"; then
        local STATUS=$(docker inspect --format='{{.State.Status}}' "${CONTAINER_NAME}" 2>/dev/null)
        local HEALTH=$(docker inspect --format='{{.State.Health.Status}}' "${CONTAINER_NAME}" 2>/dev/null || echo "no-check")
        
        if [ "${STATUS}" == "running" ]; then
            if [ "${HEALTH}" == "healthy" ]; then
                echo -e "  ${GREEN}●${NC} ${DISPLAY_NAME} - ${GREEN}Running (Healthy)${NC}"
            elif [ "${HEALTH}" == "starting" ]; then
                echo -e "  ${YELLOW}◐${NC} ${DISPLAY_NAME} - ${YELLOW}Starting...${NC}"
            elif [ "${HEALTH}" == "unhealthy" ]; then
                echo -e "  ${RED}●${NC} ${DISPLAY_NAME} - ${RED}Unhealthy${NC}"
            else
                echo -e "  ${GREEN}●${NC} ${DISPLAY_NAME} - ${GREEN}Running${NC}"
            fi
        else
            echo -e "  ${RED}○${NC} ${DISPLAY_NAME} - ${GRAY}${STATUS}${NC}"
        fi
    else
        echo -e "  ${GRAY}○${NC} ${DISPLAY_NAME} - ${GRAY}Not Running${NC}"
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
    if command -v start-agent &> /dev/null 2>&1 || alias start-agent &> /dev/null 2>&1; then
        echo -e "   ${BLUE}•${NC} Check status: ${YELLOW}status-agent${NC}"
        echo -e "   ${BLUE}•${NC} View logs: ${YELLOW}logs-agent${NC}"
        echo -e "   ${BLUE}•${NC} View specific service: ${YELLOW}logs-agent <service-name>${NC}"
        echo -e "   ${BLUE}•${NC} Stop services: ${YELLOW}stop-agent${NC}"
        echo -e "   ${BLUE}•${NC} Restart services: ${YELLOW}restart-agent${NC}"
    else
        echo -e "   ${BLUE}•${NC} Check status: ${YELLOW}./status.sh${NC}"
        echo -e "   ${BLUE}•${NC} View logs: ${YELLOW}./logs.sh${NC}"
        echo -e "   ${BLUE}•${NC} View specific service: ${YELLOW}./logs.sh <service-name>${NC}"
        echo -e "   ${BLUE}•${NC} Stop services: ${YELLOW}./stop.sh${NC}"
        echo -e "   ${BLUE}•${NC} Restart services: ${YELLOW}./start.sh${NC}"
    fi
    echo ""
    
    echo -e "${CYAN}📚 Documentation:${NC}"
    echo -e "   ${BLUE}•${NC} Deployment Guide: ${YELLOW}DEPLOYMENT_WSL2.md${NC}"
    echo -e "   ${BLUE}•${NC} Chinese Guide: ${YELLOW}docker/DEPLOYMENT_GUIDE_zh.md${NC}"
    echo ""
    
    echo -e "${CYAN}💡 Tips:${NC}"
    echo -e "   ${BLUE}•${NC} Console UI defaults to ${GREEN}English${NC}"
    echo -e "   ${BLUE}•${NC} Use language selector to switch to Chinese"
    echo -e "   ${BLUE}•${NC} Check ${YELLOW}.env${NC} file for service credentials"
    echo -e "   ${BLUE}•${NC} Services persist after WSL2 restart"
    echo ""
}

#############################################################################
# Continuous health monitoring (watch mode)
#############################################################################

watch_services() {
    print_header "Continuous Health Monitoring"
    
    print_info "Monitoring services in real-time (Press Ctrl+C to exit)"
    echo ""
    
    while true; do
        clear
        echo -e "${CYAN}"
        echo "    ╔═══════════════════════════════════════════════════════════╗"
        echo "    ║         Astron Agent - Real-Time Health Monitor          ║"
        echo "    ║                  Press Ctrl+C to exit                     ║"
        echo "    ╚═══════════════════════════════════════════════════════════╝"
        echo -e "${NC}\n"
        
        # Show timestamp
        echo -e "${GRAY}Last updated: $(date '+%Y-%m-%d %H:%M:%S')${NC}"
        echo ""
        
        # Get service status
        get_service_status
        
        # Show quick stats
        source .env 2>/dev/null || true
        NGINX_PORT=${EXPOSE_NGINX_PORT:-80}
        
        echo -e "${CYAN}Quick Access:${NC}"
        echo -e "   🌐 Console: ${BLUE}http://localhost${NC}"
        echo -e "   📊 Status: ${YELLOW}status-agent${NC} or ${YELLOW}./status.sh${NC}"
        echo -e "   📝 Logs: ${YELLOW}logs-agent${NC} or ${YELLOW}./logs.sh${NC}"
        echo ""
        
        # Wait before refresh
        sleep 5
    done
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
    
    if [ "$WATCH_MODE" = true ]; then
        watch_services
    fi
}

# Run main function
main

exit 0
