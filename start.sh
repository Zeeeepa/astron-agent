#!/usr/bin/env bash
###############################################################################
# Astron Agent - Service Startup Script
# Purpose: Starts all Astron Agent services in correct order
# Usage: ./start.sh
###############################################################################

set -e  # Exit on error

# Color definitions
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m'

# Configuration
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOCKER_COMPOSE_DIR="${PROJECT_DIR}/docker/astronAgent"
MAX_WAIT_TIME=300  # 5 minutes max wait per service
HEALTH_CHECK_INTERVAL=5  # Check every 5 seconds

###############################################################################
# Helper Functions
###############################################################################

print_header() {
    echo -e "\n${CYAN}╔════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${NC}  ${BLUE}$1${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════════════════════════════╝${NC}\n"
}

print_phase() {
    echo -e "\n${MAGENTA}▶▶▶ Phase: $1${NC}\n"
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

print_progress() {
    echo -ne "${YELLOW}⏳${NC} $1\r"
}

###############################################################################
# Pre-flight Checks
###############################################################################

check_prerequisites() {
    print_header "Checking Prerequisites"
    
    # Check if Docker is running
    if ! docker info > /dev/null 2>&1; then
        print_error "Docker is not running or not accessible"
        print_info "Please ensure Docker is installed and running"
        print_info "If you're not in the docker group, run: newgrp docker"
        exit 1
    fi
    print_success "Docker is running"
    
    # Check if Docker Compose is available
    if ! docker compose version > /dev/null 2>&1; then
        print_error "Docker Compose plugin not found"
        exit 1
    fi
    print_success "Docker Compose is available"
    
    # Check if .env file exists
    if [ ! -f "${DOCKER_COMPOSE_DIR}/.env" ]; then
        print_error ".env file not found"
        print_info "Please run ./setup.sh first"
        exit 1
    fi
    print_success ".env configuration found"
    
    # Check available disk space
    available_gb=$(df -BG "${PROJECT_DIR}" | tail -1 | awk '{print $4}' | sed 's/G//')
    if [ "$available_gb" -lt 20 ]; then
        print_warning "Low disk space: ${available_gb}GB available"
        print_info "Astron Agent requires at least 20GB of free space"
        read -p "Continue anyway? (y/n): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    else
        print_success "Sufficient disk space: ${available_gb}GB available"
    fi
}

###############################################################################
# Service Management Functions
###############################################################################

wait_for_service() {
    local service_name=$1
    local max_wait=${2:-$MAX_WAIT_TIME}
    local elapsed=0
    
    print_info "Waiting for ${service_name} to be healthy..."
    
    while [ $elapsed -lt $max_wait ]; do
        if docker compose ps --format json | jq -r ".[] | select(.Name | contains(\"${service_name}\")) | .Health" | grep -q "healthy"; then
            print_success "${service_name} is healthy (${elapsed}s)"
            return 0
        fi
        
        # Check if service exists but isn't healthy
        if docker compose ps --format json | jq -r ".[] | select(.Name | contains(\"${service_name}\")) | .State" | grep -q "running"; then
            print_progress "${service_name} is starting... (${elapsed}s/${max_wait}s)"
        else
            print_error "${service_name} is not running"
            docker compose logs --tail=20 "$service_name"
            return 1
        fi
        
        sleep $HEALTH_CHECK_INTERVAL
        elapsed=$((elapsed + HEALTH_CHECK_INTERVAL))
    done
    
    print_error "${service_name} did not become healthy within ${max_wait}s"
    docker compose logs --tail=30 "$service_name"
    return 1
}

wait_for_port() {
    local port=$1
    local service_name=$2
    local max_wait=${3:-60}
    local elapsed=0
    
    print_info "Waiting for ${service_name} port ${port}..."
    
    while [ $elapsed -lt $max_wait ]; do
        if nc -z localhost "$port" 2>/dev/null; then
            print_success "${service_name} port ${port} is accessible"
            return 0
        fi
        
        print_progress "Waiting for ${service_name} port ${port}... (${elapsed}s/${max_wait}s)"
        sleep 2
        elapsed=$((elapsed + 2))
    done
    
    print_warning "${service_name} port ${port} not accessible within ${max_wait}s"
    return 1
}

verify_database_ready() {
    local db_type=$1
    
    if [ "$db_type" == "mysql" ]; then
        print_info "Verifying MySQL readiness..."
        docker compose exec -T mysql mysqladmin ping -h localhost --silent > /dev/null 2>&1
        return $?
    elif [ "$db_type" == "postgres" ]; then
        print_info "Verifying PostgreSQL readiness..."
        docker compose exec -T postgres pg_isready -U spark > /dev/null 2>&1
        return $?
    fi
}

###############################################################################
# Image Management
###############################################################################

pull_images() {
    print_header "Pulling Docker Images"
    print_info "This may take several minutes on first run..."
    
    cd "$DOCKER_COMPOSE_DIR"
    
    # Pull images with progress
    if docker compose pull 2>&1 | tee /tmp/docker-pull.log | grep -E "(Pulling|Downloaded|Status:)"; then
        print_success "All images pulled successfully"
    else
        print_warning "Some images may have failed to pull"
        print_info "Check /tmp/docker-pull.log for details"
    fi
}

###############################################################################
# Service Startup Phases
###############################################################################

start_infrastructure() {
    print_phase "Starting Infrastructure Services"
    
    cd "$DOCKER_COMPOSE_DIR"
    
    # Start PostgreSQL
    print_info "Starting PostgreSQL..."
    docker compose up -d postgres
    wait_for_service "postgres" 120
    sleep 3
    verify_database_ready "postgres" && print_success "PostgreSQL is ready"
    
    # Start MySQL
    print_info "Starting MySQL..."
    docker compose up -d mysql
    wait_for_service "mysql" 120
    sleep 3
    verify_database_ready "mysql" && print_success "MySQL is ready"
    
    # Start Redis
    print_info "Starting Redis..."
    docker compose up -d redis
    wait_for_service "redis" 60
    
    # Start Elasticsearch
    print_info "Starting Elasticsearch..."
    print_warning "Elasticsearch may take 2-3 minutes to initialize..."
    docker compose up -d elasticsearch
    wait_for_service "elasticsearch" 180
    
    # Verify Elasticsearch cluster
    sleep 5
    if curl -s http://localhost:9200/_cluster/health | jq -r '.status' | grep -qE "(green|yellow)"; then
        print_success "Elasticsearch cluster is operational"
    else
        print_warning "Elasticsearch cluster status unknown"
    fi
    
    # Start Kafka
    print_info "Starting Kafka..."
    docker compose up -d kafka
    wait_for_service "kafka" 120
    
    # Start MinIO
    print_info "Starting MinIO..."
    docker compose up -d minio
    wait_for_service "minio" 60
    
    # Create MinIO buckets
    sleep 3
    print_info "Configuring MinIO buckets..."
    
    # Get MinIO credentials from .env
    source .env
    
    if command -v docker &> /dev/null; then
        docker compose exec -T minio mc alias set local http://localhost:9000 ${MINIO_ROOT_USER} ${MINIO_ROOT_PASSWORD} > /dev/null 2>&1 || true
        docker compose exec -T minio mc mb local/console --ignore-existing > /dev/null 2>&1 || true
        print_success "MinIO configured"
    fi
    
    print_success "All infrastructure services are running"
}

start_core_services() {
    print_phase "Starting Core Services"
    
    cd "$DOCKER_COMPOSE_DIR"
    
    # Start Tenant Service
    print_info "Starting Tenant Service..."
    docker compose up -d core-tenant
    sleep 10  # Give tenant service time to initialize
    print_success "Tenant service started"
    
    # Start Memory Database Service
    print_info "Starting Memory Database Service..."
    docker compose up -d core-database
    sleep 10
    print_success "Database service started"
    
    # Start RPA Plugin Service
    print_info "Starting RPA Plugin Service..."
    docker compose up -d core-rpa
    sleep 8
    print_success "RPA service started"
    
    # Start Link Plugin Service
    print_info "Starting Link Plugin Service..."
    docker compose up -d core-link
    sleep 10
    print_success "Link service started"
    
    # Start AITools Plugin Service
    print_info "Starting AITools Plugin Service..."
    docker compose up -d core-aitools
    sleep 10
    print_success "AITools service started"
    
    # Start Agent Service
    print_info "Starting Agent Service..."
    docker compose up -d core-agent
    sleep 10
    print_success "Agent service started"
    
    # Start Knowledge Service
    print_info "Starting Knowledge Service..."
    docker compose up -d core-knowledge
    sleep 10
    print_success "Knowledge service started"
    
    # Start Workflow Service
    print_info "Starting Workflow Service..."
    docker compose up -d core-workflow
    sleep 10
    print_success "Workflow service started"
    
    print_success "All core services are running"
}

start_console_services() {
    print_phase "Starting Console Services"
    
    cd "$DOCKER_COMPOSE_DIR"
    
    # Start Console Frontend
    print_info "Starting Console Frontend..."
    docker compose up -d console-frontend
    sleep 8
    print_success "Frontend service started"
    
    # Start Console Hub
    print_info "Starting Console Hub..."
    docker compose up -d console-hub
    sleep 10
    print_success "Hub service started"
    
    # Start Nginx
    print_info "Starting Nginx Reverse Proxy..."
    docker compose up -d nginx
    wait_for_service "nginx" 60
    
    print_success "All console services are running"
}

###############################################################################
# Verification
###############################################################################

verify_deployment() {
    print_header "Verifying Deployment"
    
    # Wait a bit for services to fully initialize
    sleep 5
    
    # Check web interface
    print_info "Checking web interface..."
    if curl -s -o /dev/null -w "%{http_code}" http://localhost | grep -qE "(200|302)"; then
        print_success "Web interface is accessible at http://localhost"
    else
        print_warning "Web interface may not be fully ready yet"
        print_info "Try accessing http://localhost in a few moments"
    fi
    
    # Check service status
    print_info "Service Status:"
    cd "$DOCKER_COMPOSE_DIR"
    docker compose ps --format "table {{.Name}}\t{{.Status}}\t{{.Ports}}" | grep -E "(Up|healthy)" | head -20
    
    # Count healthy services
    local total_services=$(docker compose ps --format json | jq -s 'length')
    local healthy_services=$(docker compose ps --format json | jq -r '.[] | select(.Health == "healthy") | .Name' | wc -l)
    local running_services=$(docker compose ps --format json | jq -r '.[] | select(.State == "running") | .Name' | wc -l)
    
    print_info "Services: ${running_services}/${total_services} running, ${healthy_services} healthy"
    
    if [ "$running_services" -eq "$total_services" ]; then
        print_success "All services are running"
    else
        print_warning "Some services may not have started correctly"
    fi
}

###############################################################################
# Display Access Information
###############################################################################

show_access_info() {
    print_header "Access Information"
    
    cd "$DOCKER_COMPOSE_DIR"
    source .env
    
    echo -e "${CYAN}Web Interface:${NC}"
    echo -e "  URL: ${GREEN}http://localhost${NC}"
    echo -e "  Port: ${GREEN}${EXPOSE_NGINX_PORT:-80}${NC}"
    echo ""
    
    echo -e "${CYAN}MinIO Console:${NC}"
    echo -e "  URL: ${GREEN}http://localhost:${EXPOSE_MINIO_CONSOLE_PORT:-9001}${NC}"
    echo -e "  Username: ${GREEN}${MINIO_ROOT_USER:-minioadmin}${NC}"
    echo -e "  Password: ${GREEN}[Check .env file]${NC}"
    echo ""
    
    echo -e "${CYAN}Service Ports:${NC}"
    echo -e "  Nginx (Web): ${GREEN}${EXPOSE_NGINX_PORT:-80}${NC}"
    echo -e "  Kafka: ${GREEN}${EXPOSE_KAFKA_PORT:-9092}${NC}"
    echo -e "  MinIO API: ${GREEN}${EXPOSE_MINIO_PORT:-9000}${NC}"
    echo ""
    
    echo -e "${CYAN}Database Credentials:${NC}"
    echo -e "  PostgreSQL: postgres:5432 (user: ${POSTGRES_USER:-spark})"
    echo -e "  MySQL: mysql:3306 (user: ${MYSQL_USER:-root})"
    echo -e "  Redis: redis:6379"
    echo -e "  ${YELLOW}Note: Passwords are stored in .env file${NC}"
    echo ""
    
    echo -e "${CYAN}Useful Commands:${NC}"
    echo -e "  View status: ${YELLOW}./status.sh${NC}"
    echo -e "  View logs: ${YELLOW}./logs.sh [service]${NC}"
    echo -e "  Stop services: ${YELLOW}./stop.sh${NC}"
    echo -e "  Restart: ${YELLOW}./start.sh${NC}"
    echo ""
    
    echo -e "${CYAN}Configuration:${NC}"
    echo -e "  Location: ${YELLOW}${DOCKER_COMPOSE_DIR}/.env${NC}"
    echo -e "  Backup: ${YELLOW}${DOCKER_COMPOSE_DIR}/.env.backup.*${NC}"
    echo ""
}

###############################################################################
# Error Handling
###############################################################################

handle_error() {
    local exit_code=$?
    local line_number=$1
    
    print_header "Deployment Error"
    print_error "An error occurred during deployment (exit code: ${exit_code})"
    print_info "Error at line: ${line_number}"
    echo ""
    print_info "Troubleshooting steps:"
    echo "  1. Check service logs: ./logs.sh"
    echo "  2. Check specific service: docker compose logs [service-name]"
    echo "  3. Verify .env configuration"
    echo "  4. Check disk space: df -h"
    echo "  5. Check Docker status: docker info"
    echo ""
    print_info "To retry deployment:"
    echo "  1. Stop services: ./stop.sh"
    echo "  2. Review error messages above"
    echo "  3. Fix configuration if needed"
    echo "  4. Run: ./start.sh"
    echo ""
    
    cd "$DOCKER_COMPOSE_DIR"
    print_info "Current service status:"
    docker compose ps
    
    exit "$exit_code"
}

trap 'handle_error ${LINENO}' ERR

###############################################################################
# Main Execution
###############################################################################

main() {
    clear
    echo -e "${CYAN}"
    cat << "EOF"
    ╔═══════════════════════════════════════════════════════════╗
    ║                                                           ║
    ║           Astron Agent - Deployment Script               ║
    ║                                                           ║
    ║         Starting Enterprise AI Agent Platform            ║
    ║                                                           ║
    ╚═══════════════════════════════════════════════════════════╝
EOF
    echo -e "${NC}"
    
    local start_time=$(date +%s)
    
    check_prerequisites
    pull_images
    start_infrastructure
    start_core_services
    start_console_services
    verify_deployment
    show_access_info
    
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    local minutes=$((duration / 60))
    local seconds=$((duration % 60))
    
    print_header "Deployment Complete! 🎉"
    print_success "Total deployment time: ${minutes}m ${seconds}s"
    echo ""
    echo -e "${GREEN}Astron Agent is now running!${NC}"
    echo -e "Access the console at: ${CYAN}http://localhost${NC}"
    echo ""
}

# Run main function
main "$@"

