#!/bin/bash

# Astron-RPA Integration Deployment Script
# Comprehensive deployment automation for the complete RPA integration

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
DOCKER_COMPOSE_FILE="$PROJECT_ROOT/docker/integration/docker-compose.yml"
ENV_FILE="$PROJECT_ROOT/.env"
LOG_FILE="$PROJECT_ROOT/logs/deployment.log"

# Create logs directory
mkdir -p "$PROJECT_ROOT/logs"

# Logging function
log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1" | tee -a "$LOG_FILE"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1" | tee -a "$LOG_FILE"
}

warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1" | tee -a "$LOG_FILE"
}

info() {
    echo -e "${BLUE}[INFO]${NC} $1" | tee -a "$LOG_FILE"
}

# Function to check prerequisites
check_prerequisites() {
    log "🔍 Checking prerequisites..."
    
    # Check Docker
    if ! command -v docker &> /dev/null; then
        error "Docker is not installed. Please install Docker first."
        exit 1
    fi
    
    # Check Docker Compose
    if ! command -v docker-compose &> /dev/null; then
        error "Docker Compose is not installed. Please install Docker Compose first."
        exit 1
    fi
    
    # Check if Docker daemon is running
    if ! docker info &> /dev/null; then
        error "Docker daemon is not running. Please start Docker first."
        exit 1
    fi
    
    # Check Python (for testing)
    if ! command -v python3 &> /dev/null; then
        warning "Python 3 is not installed. Some testing features may not work."
    fi
    
    # Check Node.js (for web UI)
    if ! command -v node &> /dev/null; then
        warning "Node.js is not installed. Web UI features may not work."
    fi
    
    log "✅ Prerequisites check completed"
}

# Function to setup environment
setup_environment() {
    log "🔧 Setting up environment..."
    
    # Create .env file if it doesn't exist
    if [ ! -f "$ENV_FILE" ]; then
        log "Creating .env file from template..."
        cp "$PROJECT_ROOT/core/agent/config.rpa.example" "$ENV_FILE"
        
        # Generate secure passwords
        MYSQL_PASSWORD=$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-25)
        REDIS_PASSWORD=$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-25)
        JWT_SECRET=$(openssl rand -base64 64 | tr -d "=+/" | cut -c1-50)
        
        # Update .env with generated passwords
        sed -i "s/MYSQL_ROOT_PASSWORD=root123/MYSQL_ROOT_PASSWORD=$MYSQL_PASSWORD/" "$ENV_FILE"
        sed -i "s/MYSQL_PASSWORD=astron123/MYSQL_PASSWORD=$MYSQL_PASSWORD/" "$ENV_FILE"
        sed -i "s/JWT_SECRET_KEY=your-super-secret-jwt-key-here/JWT_SECRET_KEY=$JWT_SECRET/" "$ENV_FILE"
        
        log "✅ Environment file created with secure passwords"
    else
        log "✅ Environment file already exists"
    fi
    
    # Create necessary directories
    mkdir -p "$PROJECT_ROOT/logs"
    mkdir -p "$PROJECT_ROOT/data/mysql"
    mkdir -p "$PROJECT_ROOT/data/redis"
    mkdir -p "$PROJECT_ROOT/data/rpa-components"
    mkdir -p "$PROJECT_ROOT/data/rpa-screenshots"
    mkdir -p "$PROJECT_ROOT/data/rpa-logs"
    
    log "✅ Environment setup completed"
}

# Function to build Docker images
build_images() {
    log "🏗️ Building Docker images..."
    
    cd "$PROJECT_ROOT"
    
    # Build Astron-Agent image
    log "Building Astron-Agent image..."
    docker build -t astron-agent:latest -f core/agent/Dockerfile core/agent/
    
    # Note: Astron-RPA images would be built separately or pulled from registry
    log "✅ Docker images built successfully"
}

# Function to start services
start_services() {
    log "🚀 Starting services..."
    
    cd "$PROJECT_ROOT"
    
    # Start core services
    log "Starting core services..."
    docker-compose -f "$DOCKER_COMPOSE_FILE" up -d
    
    # Wait for services to be healthy
    log "Waiting for services to be healthy..."
    sleep 30
    
    # Check service health
    check_service_health
    
    log "✅ Services started successfully"
}

# Function to start services with monitoring
start_with_monitoring() {
    log "🚀 Starting services with monitoring..."
    
    cd "$PROJECT_ROOT"
    
    # Start with monitoring profile
    docker-compose -f "$DOCKER_COMPOSE_FILE" --profile monitoring up -d
    
    # Wait for services to be healthy
    log "Waiting for services to be healthy..."
    sleep 45
    
    # Check service health
    check_service_health
    
    log "✅ Services with monitoring started successfully"
    log "📊 Grafana dashboard: http://localhost:3000 (admin/admin123)"
    log "📈 Prometheus: http://localhost:9090"
}

# Function to start all services (including web UI)
start_full_stack() {
    log "🚀 Starting full stack..."
    
    cd "$PROJECT_ROOT"
    
    # Start all services
    docker-compose -f "$DOCKER_COMPOSE_FILE" --profile monitoring --profile ui up -d
    
    # Wait for services to be healthy
    log "Waiting for services to be healthy..."
    sleep 60
    
    # Check service health
    check_service_health
    
    log "✅ Full stack started successfully"
    log "🌐 Web UI: http://localhost:3001"
    log "📊 Grafana dashboard: http://localhost:3000 (admin/admin123)"
    log "📈 Prometheus: http://localhost:9090"
}

# Function to check service health
check_service_health() {
    log "🏥 Checking service health..."
    
    local max_attempts=30
    local attempt=1
    
    while [ $attempt -le $max_attempts ]; do
        log "Health check attempt $attempt/$max_attempts..."
        
        # Check Astron-Agent health
        if curl -f -s http://localhost:8000/health > /dev/null; then
            log "✅ Astron-Agent is healthy"
            break
        else
            warning "Astron-Agent not ready yet..."
        fi
        
        sleep 10
        ((attempt++))
    done
    
    if [ $attempt -gt $max_attempts ]; then
        error "Services failed to become healthy within timeout"
        show_service_logs
        exit 1
    fi
    
    # Check RPA integration health
    if curl -f -s http://localhost:8000/api/v1/rpa/health > /dev/null; then
        log "✅ RPA Integration is healthy"
    else
        warning "RPA Integration endpoint not responding"
    fi
    
    log "✅ Health check completed"
}

# Function to show service logs
show_service_logs() {
    log "📋 Showing service logs..."
    
    cd "$PROJECT_ROOT"
    
    echo -e "\n${BLUE}=== Astron-Agent Logs ===${NC}"
    docker-compose -f "$DOCKER_COMPOSE_FILE" logs --tail=50 astron-agent-api
    
    echo -e "\n${BLUE}=== RPA OpenAPI Logs ===${NC}"
    docker-compose -f "$DOCKER_COMPOSE_FILE" logs --tail=50 astron-rpa-openapi
    
    echo -e "\n${BLUE}=== RPA Engine Logs ===${NC}"
    docker-compose -f "$DOCKER_COMPOSE_FILE" logs --tail=50 astron-rpa-engine
}

# Function to run tests
run_tests() {
    log "🧪 Running tests..."
    
    cd "$PROJECT_ROOT"
    
    # Install test dependencies
    if command -v python3 &> /dev/null; then
        log "Installing Python test dependencies..."
        python3 -m pip install -r requirements-test.txt || warning "Failed to install test dependencies"
        
        # Run integration tests
        log "Running integration tests..."
        python3 -m pytest tests/integration/test_rpa_integration.py -v || warning "Some integration tests failed"
    else
        warning "Python 3 not available, skipping Python tests"
    fi
    
    # Run Playwright tests if available
    if command -v npx &> /dev/null; then
        log "Running Playwright tests..."
        npx playwright install chromium || warning "Failed to install Playwright browsers"
        python3 -m pytest tests/playwright/test_rpa_ui_interaction.py -v || warning "Some Playwright tests failed"
    else
        warning "Node.js/npx not available, skipping Playwright tests"
    fi
    
    log "✅ Tests completed"
}

# Function to create test project
create_test_project() {
    log "🎯 Creating test project..."
    
    local test_project_data='{
        "name": "Deployment Test Project",
        "prd_content": "Create a simple web application with user authentication, product listing, and basic API endpoints for testing the RPA integration deployment.",
        "project_config": {
            "target_url": "http://localhost:3000",
            "api_endpoints": ["/api/auth", "/api/products", "/api/health"],
            "ui_requirements": ["login_form", "product_list", "navigation"]
        }
    }'
    
    # Create project via API
    local response=$(curl -s -X POST "http://localhost:8000/api/v1/rpa/projects/create" \
        -H "Content-Type: application/json" \
        -d "$test_project_data")
    
    if echo "$response" | grep -q "project_id"; then
        local project_id=$(echo "$response" | python3 -c "import sys, json; print(json.load(sys.stdin)['project_id'])")
        log "✅ Test project created successfully: $project_id"
        
        # Wait for project processing
        log "Waiting for project processing..."
        sleep 10
        
        # Check project status
        local status_response=$(curl -s "http://localhost:8000/api/v1/rpa/projects/$project_id")
        log "Project status: $(echo "$status_response" | python3 -c "import sys, json; print(json.load(sys.stdin)['status'])")"
        
        return 0
    else
        error "Failed to create test project: $response"
        return 1
    fi
}

# Function to show deployment summary
show_deployment_summary() {
    log "📋 Deployment Summary"
    echo -e "\n${GREEN}🎉 Astron-RPA Integration Deployment Complete! 🎉${NC}\n"
    
    echo -e "${BLUE}📡 Service Endpoints:${NC}"
    echo -e "  • Astron-Agent API: http://localhost:8000"
    echo -e "  • API Documentation: http://localhost:8000/docs"
    echo -e "  • RPA Health Check: http://localhost:8000/api/v1/rpa/health"
    echo -e "  • Component Mapping: http://localhost:8000/api/v1/rpa/components/mapping"
    
    if docker-compose -f "$DOCKER_COMPOSE_FILE" ps | grep -q "grafana"; then
        echo -e "\n${BLUE}📊 Monitoring:${NC}"
        echo -e "  • Grafana Dashboard: http://localhost:3000 (admin/admin123)"
        echo -e "  • Prometheus: http://localhost:9090"
    fi
    
    if docker-compose -f "$DOCKER_COMPOSE_FILE" ps | grep -q "astron-web-ui"; then
        echo -e "\n${BLUE}🌐 Web Interface:${NC}"
        echo -e "  • Web UI: http://localhost:3001"
    fi
    
    echo -e "\n${BLUE}🔧 Management Commands:${NC}"
    echo -e "  • View logs: docker-compose -f $DOCKER_COMPOSE_FILE logs -f"
    echo -e "  • Stop services: docker-compose -f $DOCKER_COMPOSE_FILE down"
    echo -e "  • Restart services: docker-compose -f $DOCKER_COMPOSE_FILE restart"
    
    echo -e "\n${BLUE}🧪 Quick Test:${NC}"
    echo -e "  curl http://localhost:8000/api/v1/rpa/health"
    
    echo -e "\n${GREEN}✅ Ready for autonomous CI/CD workflows!${NC}"
}

# Function to cleanup
cleanup() {
    log "🧹 Cleaning up..."
    
    cd "$PROJECT_ROOT"
    
    # Stop services
    docker-compose -f "$DOCKER_COMPOSE_FILE" down
    
    # Remove volumes (optional)
    if [ "$1" = "--remove-data" ]; then
        warning "Removing all data volumes..."
        docker-compose -f "$DOCKER_COMPOSE_FILE" down -v
        rm -rf "$PROJECT_ROOT/data"
    fi
    
    log "✅ Cleanup completed"
}

# Main deployment function
main() {
    local command=${1:-"deploy"}
    
    case $command in
        "deploy")
            log "🚀 Starting Astron-RPA Integration Deployment..."
            check_prerequisites
            setup_environment
            build_images
            start_services
            sleep 10
            create_test_project
            show_deployment_summary
            ;;
        "deploy-with-monitoring")
            log "🚀 Starting deployment with monitoring..."
            check_prerequisites
            setup_environment
            build_images
            start_with_monitoring
            sleep 10
            create_test_project
            show_deployment_summary
            ;;
        "deploy-full")
            log "🚀 Starting full stack deployment..."
            check_prerequisites
            setup_environment
            build_images
            start_full_stack
            sleep 10
            create_test_project
            show_deployment_summary
            ;;
        "test")
            log "🧪 Running tests..."
            run_tests
            ;;
        "health")
            log "🏥 Checking service health..."
            check_service_health
            ;;
        "logs")
            show_service_logs
            ;;
        "cleanup")
            cleanup
            ;;
        "cleanup-all")
            cleanup --remove-data
            ;;
        "help")
            echo -e "${BLUE}Astron-RPA Integration Deployment Script${NC}"
            echo ""
            echo "Usage: $0 [command]"
            echo ""
            echo "Commands:"
            echo "  deploy              Deploy core services (default)"
            echo "  deploy-with-monitoring  Deploy with Prometheus/Grafana"
            echo "  deploy-full         Deploy everything including Web UI"
            echo "  test                Run integration tests"
            echo "  health              Check service health"
            echo "  logs                Show service logs"
            echo "  cleanup             Stop services and cleanup"
            echo "  cleanup-all         Stop services and remove all data"
            echo "  help                Show this help message"
            echo ""
            echo "Examples:"
            echo "  $0 deploy           # Deploy core services"
            echo "  $0 deploy-full      # Deploy everything"
            echo "  $0 test             # Run tests"
            echo "  $0 cleanup          # Clean shutdown"
            ;;
        *)
            error "Unknown command: $command"
            echo "Use '$0 help' for usage information"
            exit 1
            ;;
    esac
}

# Handle script interruption
trap 'error "Deployment interrupted"; exit 1' INT TERM

# Run main function
main "$@"
