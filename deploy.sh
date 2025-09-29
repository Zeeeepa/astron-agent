#!/bin/bash

# ============================================================================
# UNIFIED DEPLOYMENT SCRIPT
# astron-agent + astron-rpa Integrated Deployment
# ============================================================================

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="${SCRIPT_DIR}/.env.unified"
COMPOSE_FILE="${SCRIPT_DIR}/docker-compose.unified.yml"
LOG_FILE="${SCRIPT_DIR}/deployment.log"

# Default values
SKIP_DEPS_CHECK=false
SKIP_BUILD=false
FORCE_RECREATE=false
ENABLE_MONITORING=false
PRODUCTION_MODE=false

# ============================================================================
# UTILITY FUNCTIONS
# ============================================================================

log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1" | tee -a "$LOG_FILE"
}

warn() {
    echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')] WARNING:${NC} $1" | tee -a "$LOG_FILE"
}

error() {
    echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')] ERROR:${NC} $1" | tee -a "$LOG_FILE"
    exit 1
}

info() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')] INFO:${NC} $1" | tee -a "$LOG_FILE"
}

success() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] SUCCESS:${NC} $1" | tee -a "$LOG_FILE"
}

# Progress bar function
show_progress() {
    local duration=$1
    local message=$2
    local progress=0
    local bar_length=50
    
    echo -n "$message "
    while [ $progress -le $duration ]; do
        local filled=$((progress * bar_length / duration))
        local empty=$((bar_length - filled))
        
        printf "\r$message ["
        printf "%${filled}s" | tr ' ' '='
        printf "%${empty}s" | tr ' ' '-'
        printf "] %d%%" $((progress * 100 / duration))
        
        sleep 1
        ((progress++))
    done
    echo ""
}

# ============================================================================
# SYSTEM REQUIREMENTS CHECK
# ============================================================================

check_system_requirements() {
    log "🔍 Checking system requirements..."
    
    # Check if running as root
    if [[ $EUID -eq 0 ]]; then
        warn "Running as root. Consider using a non-root user with docker group membership."
    fi
    
    # Check Docker
    if ! command -v docker &> /dev/null; then
        error "Docker is not installed. Please install Docker first."
    fi
    
    # Check Docker Compose
    if ! command -v docker-compose &> /dev/null && ! docker compose version &> /dev/null; then
        error "Docker Compose is not installed. Please install Docker Compose first."
    fi
    
    # Check Docker daemon
    if ! docker info &> /dev/null; then
        error "Docker daemon is not running. Please start Docker first."
    fi
    
    # Check available disk space (minimum 10GB)
    local available_space=$(df / | awk 'NR==2 {print $4}')
    local required_space=10485760  # 10GB in KB
    
    if [ "$available_space" -lt "$required_space" ]; then
        warn "Available disk space is less than 10GB. Deployment may fail."
    fi
    
    # Check available memory (minimum 8GB)
    local available_memory=$(free -k | awk 'NR==2{print $2}')
    local required_memory=8388608  # 8GB in KB
    
    if [ "$available_memory" -lt "$required_memory" ]; then
        warn "Available memory is less than 8GB. Performance may be affected."
    fi
    
    # Check required ports
    local required_ports=(80 443 3306 5432 6379 9000 9001 9200 9092 8000 8010 8020 8030 8040 8003 8080 1881 17870 32742)
    local occupied_ports=()
    
    for port in "${required_ports[@]}"; do
        if netstat -tuln 2>/dev/null | grep -q ":$port "; then
            occupied_ports+=($port)
        fi
    done
    
    if [ ${#occupied_ports[@]} -gt 0 ]; then
        warn "The following ports are already in use: ${occupied_ports[*]}"
        warn "This may cause conflicts during deployment."
    fi
    
    success "✅ System requirements check completed"
}

# ============================================================================
# DEPENDENCY INSTALLATION
# ============================================================================

install_dependencies() {
    log "📦 Installing system dependencies..."
    
    # Detect OS
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        # Linux
        if command -v apt-get &> /dev/null; then
            # Debian/Ubuntu
            sudo apt-get update
            sudo apt-get install -y curl wget git jq netstat-nat
        elif command -v yum &> /dev/null; then
            # RHEL/CentOS
            sudo yum update -y
            sudo yum install -y curl wget git jq net-tools
        elif command -v dnf &> /dev/null; then
            # Fedora
            sudo dnf update -y
            sudo dnf install -y curl wget git jq net-tools
        fi
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS
        if command -v brew &> /dev/null; then
            brew update
            brew install curl wget git jq
        else
            warn "Homebrew not found. Please install dependencies manually."
        fi
    fi
    
    success "✅ Dependencies installed"
}

# ============================================================================
# ENVIRONMENT SETUP
# ============================================================================

setup_environment() {
    log "🔧 Setting up environment..."
    
    # Create necessary directories
    mkdir -p "${SCRIPT_DIR}/logs"
    mkdir -p "${SCRIPT_DIR}/backups"
    mkdir -p "${SCRIPT_DIR}/data"
    mkdir -p "${SCRIPT_DIR}/nginx/ssl"
    
    # Set proper permissions
    chmod 755 "${SCRIPT_DIR}/logs"
    chmod 755 "${SCRIPT_DIR}/backups"
    chmod 755 "${SCRIPT_DIR}/data"
    
    # Copy environment file if it doesn't exist
    if [ ! -f "$ENV_FILE" ]; then
        warn "Environment file not found. Creating default configuration..."
        cp "${SCRIPT_DIR}/.env.unified" "$ENV_FILE" 2>/dev/null || true
    fi
    
    # Generate SSL certificates for development (self-signed)
    if [ ! -f "${SCRIPT_DIR}/nginx/ssl/cert.pem" ]; then
        log "🔐 Generating self-signed SSL certificates for development..."
        openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
            -keyout "${SCRIPT_DIR}/nginx/ssl/key.pem" \
            -out "${SCRIPT_DIR}/nginx/ssl/cert.pem" \
            -subj "/C=US/ST=State/L=City/O=Organization/CN=localhost" \
            2>/dev/null || warn "Failed to generate SSL certificates"
    fi
    
    success "✅ Environment setup completed"
}

# ============================================================================
# DOCKER NETWORK SETUP
# ============================================================================

setup_docker_network() {
    log "🌐 Setting up Docker networks..."
    
    # Create custom network if it doesn't exist
    if ! docker network ls | grep -q "astron-unified-network"; then
        docker network create astron-unified-network \
            --driver bridge \
            --subnet=172.50.0.0/16 \
            --ip-range=172.50.1.0/24 \
            --gateway=172.50.0.1
        success "✅ Created Docker network: astron-unified-network"
    else
        info "Docker network already exists: astron-unified-network"
    fi
}

# ============================================================================
# SERVICE HEALTH CHECKS
# ============================================================================

wait_for_service() {
    local service_name=$1
    local health_url=$2
    local max_attempts=${3:-60}
    local attempt=1
    
    log "⏳ Waiting for $service_name to be healthy..."
    
    while [ $attempt -le $max_attempts ]; do
        if curl -f -s "$health_url" > /dev/null 2>&1; then
            success "✅ $service_name is healthy"
            return 0
        fi
        
        echo -n "."
        sleep 5
        ((attempt++))
    done
    
    error "❌ $service_name failed to become healthy after $((max_attempts * 5)) seconds"
}

check_all_services() {
    log "🏥 Performing health checks on all services..."
    
    # Infrastructure services
    wait_for_service "MySQL" "http://localhost:3306" 30
    wait_for_service "Redis" "http://localhost:6379" 30
    wait_for_service "MinIO" "http://localhost:9000/minio/health/live" 30
    wait_for_service "PostgreSQL" "http://localhost:5432" 30
    wait_for_service "Elasticsearch" "http://localhost:9200/_cluster/health" 30
    
    # RPA services
    wait_for_service "RPA AI Service" "http://localhost:8010/health" 60
    wait_for_service "RPA OpenAPI Service" "http://localhost:8020/health" 60
    wait_for_service "RPA Resource Service" "http://localhost:8030/health" 60
    wait_for_service "RPA Robot Service" "http://localhost:8040/health" 60
    wait_for_service "RPA Frontend" "http://localhost:32742" 60
    
    # Agent services
    wait_for_service "Agent Core" "http://localhost:17870/health" 60
    wait_for_service "Agent RPA Plugin" "http://localhost:8003/health" 60
    wait_for_service "Agent Console" "http://localhost:8080/health" 60
    wait_for_service "Agent Frontend" "http://localhost:1881" 60
    
    # Reverse proxy
    wait_for_service "Nginx Proxy" "http://localhost:80/health" 30
    
    success "✅ All services are healthy!"
}

# ============================================================================
# DEPLOYMENT FUNCTIONS
# ============================================================================

pull_images() {
    log "📥 Pulling Docker images..."
    
    if [ "$SKIP_BUILD" = false ]; then
        docker-compose -f "$COMPOSE_FILE" --env-file "$ENV_FILE" pull --ignore-pull-failures
    fi
    
    success "✅ Docker images pulled"
}

build_services() {
    log "🔨 Building services..."
    
    if [ "$SKIP_BUILD" = false ]; then
        local build_args=""
        if [ "$FORCE_RECREATE" = true ]; then
            build_args="--no-cache --force-rm"
        fi
        
        docker-compose -f "$COMPOSE_FILE" --env-file "$ENV_FILE" build $build_args
    fi
    
    success "✅ Services built"
}

start_infrastructure() {
    log "🏗️ Starting infrastructure services..."
    
    # Start infrastructure services first
    docker-compose -f "$COMPOSE_FILE" --env-file "$ENV_FILE" up -d \
        mysql redis minio postgres elasticsearch kafka
    
    # Wait for infrastructure to be ready
    sleep 30
    
    success "✅ Infrastructure services started"
}

start_rpa_services() {
    log "🤖 Starting RPA services..."
    
    docker-compose -f "$COMPOSE_FILE" --env-file "$ENV_FILE" up -d \
        casdoor rpa-ai-service rpa-openapi-service rpa-resource-service rpa-robot-service rpa-frontend
    
    success "✅ RPA services started"
}

start_agent_services() {
    log "🧠 Starting Agent services..."
    
    docker-compose -f "$COMPOSE_FILE" --env-file "$ENV_FILE" up -d \
        agent-core-agent agent-core-rpa agent-core-knowledge agent-core-memory \
        agent-core-tenant agent-core-workflow agent-console-frontend agent-console-hub
    
    success "✅ Agent services started"
}

start_proxy() {
    log "🌐 Starting reverse proxy..."
    
    docker-compose -f "$COMPOSE_FILE" --env-file "$ENV_FILE" up -d nginx
    
    success "✅ Reverse proxy started"
}

# ============================================================================
# MONITORING SETUP
# ============================================================================

setup_monitoring() {
    if [ "$ENABLE_MONITORING" = true ]; then
        log "📊 Setting up monitoring..."
        
        # Add Prometheus and Grafana services
        cat >> "$COMPOSE_FILE" << 'EOF'

  # Prometheus monitoring
  prometheus:
    image: prom/prometheus:latest
    container_name: unified-prometheus
    ports:
      - "9090:9090"
    volumes:
      - ./monitoring/prometheus.yml:/etc/prometheus/prometheus.yml:ro
      - prometheus_data:/prometheus
    networks:
      - astron-unified-network
    restart: always

  # Grafana dashboards
  grafana:
    image: grafana/grafana:latest
    container_name: unified-grafana
    ports:
      - "3000:3000"
    environment:
      - GF_SECURITY_ADMIN_PASSWORD=admin123
    volumes:
      - grafana_data:/var/lib/grafana
      - ./monitoring/grafana:/etc/grafana/provisioning
    networks:
      - astron-unified-network
    restart: always
    depends_on:
      - prometheus

volumes:
  prometheus_data:
    driver: local
  grafana_data:
    driver: local
EOF
        
        # Create monitoring configuration
        mkdir -p "${SCRIPT_DIR}/monitoring"
        
        # Create Prometheus configuration
        cat > "${SCRIPT_DIR}/monitoring/prometheus.yml" << 'EOF'
global:
  scrape_interval: 15s

scrape_configs:
  - job_name: 'nginx'
    static_configs:
      - targets: ['nginx:8090']
  
  - job_name: 'rpa-services'
    static_configs:
      - targets: ['rpa-ai-service:8010', 'rpa-openapi-service:8020', 'rpa-resource-service:8030', 'rpa-robot-service:8040']
  
  - job_name: 'agent-services'
    static_configs:
      - targets: ['agent-core-agent:17870', 'agent-core-rpa:8003', 'agent-console-hub:8080']
EOF
        
        success "✅ Monitoring setup completed"
    fi
}

# ============================================================================
# BACKUP FUNCTIONS
# ============================================================================

create_backup() {
    log "💾 Creating backup..."
    
    local backup_dir="${SCRIPT_DIR}/backups/backup-$(date +%Y%m%d-%H%M%S)"
    mkdir -p "$backup_dir"
    
    # Backup databases
    docker exec unified-mysql mysqldump --all-databases -u root -p"${MYSQL_ROOT_PASSWORD:-root123}" > "$backup_dir/mysql-backup.sql"
    docker exec unified-postgres pg_dumpall -U "${POSTGRES_USER:-spark}" > "$backup_dir/postgres-backup.sql"
    
    # Backup volumes
    docker run --rm -v mysql_data:/data -v "$backup_dir":/backup alpine tar czf /backup/mysql-data.tar.gz -C /data .
    docker run --rm -v postgres_data:/data -v "$backup_dir":/backup alpine tar czf /backup/postgres-data.tar.gz -C /data .
    docker run --rm -v minio_data:/data -v "$backup_dir":/backup alpine tar czf /backup/minio-data.tar.gz -C /data .
    
    success "✅ Backup created: $backup_dir"
}

# ============================================================================
# MAIN DEPLOYMENT FUNCTION
# ============================================================================

deploy() {
    log "🚀 Starting unified deployment of astron-agent + astron-rpa..."
    
    # Pre-deployment checks
    if [ "$SKIP_DEPS_CHECK" = false ]; then
        check_system_requirements
        install_dependencies
    fi
    
    # Environment setup
    setup_environment
    setup_docker_network
    
    # Monitoring setup
    setup_monitoring
    
    # Build and pull images
    pull_images
    build_services
    
    # Start services in order
    start_infrastructure
    start_rpa_services
    start_agent_services
    start_proxy
    
    # Health checks
    check_all_services
    
    # Create initial backup
    create_backup
    
    # Display access information
    display_access_info
    
    success "🎉 Deployment completed successfully!"
}

# ============================================================================
# ACCESS INFORMATION
# ============================================================================

display_access_info() {
    echo ""
    echo -e "${PURPLE}============================================================================${NC}"
    echo -e "${PURPLE}                    🎉 DEPLOYMENT SUCCESSFUL! 🎉${NC}"
    echo -e "${PURPLE}============================================================================${NC}"
    echo ""
    echo -e "${CYAN}📱 WEB INTERFACES:${NC}"
    echo -e "   🤖 RPA Platform:      ${GREEN}http://localhost/rpa/${NC}"
    echo -e "   🧠 Agent Console:     ${GREEN}http://localhost/agent/${NC}"
    echo -e "   🔐 Authentication:    ${GREEN}http://localhost/auth/${NC}"
    echo -e "   💾 MinIO Console:     ${GREEN}http://localhost/minio/${NC}"
    if [ "$ENABLE_MONITORING" = true ]; then
        echo -e "   📊 Grafana:           ${GREEN}http://localhost:3000${NC} (admin/admin123)"
        echo -e "   📈 Prometheus:        ${GREEN}http://localhost:9090${NC}"
    fi
    echo ""
    echo -e "${CYAN}🔌 API ENDPOINTS:${NC}"
    echo -e "   🤖 RPA API:           ${GREEN}http://localhost/rpa/api/${NC}"
    echo -e "   🧠 Agent API:         ${GREEN}http://localhost/agent/api/${NC}"
    echo -e "   🔗 Agent Core:        ${GREEN}http://localhost/agent/core/${NC}"
    echo -e "   🔧 RPA Plugin:        ${GREEN}http://localhost/agent/rpa/${NC}"
    echo ""
    echo -e "${CYAN}🗄️ DATABASE ACCESS:${NC}"
    echo -e "   🐬 MySQL:             ${GREEN}localhost:3306${NC} (root/UnifiedRoot123!)"
    echo -e "   🐘 PostgreSQL:        ${GREEN}localhost:5432${NC} (spark/SparkDB123!)"
    echo -e "   🔍 Elasticsearch:     ${GREEN}localhost:9200${NC}"
    echo -e "   📨 Kafka:             ${GREEN}localhost:9092${NC}"
    echo -e "   🗃️ Redis:             ${GREEN}localhost:6379${NC}"
    echo ""
    echo -e "${CYAN}📋 MANAGEMENT COMMANDS:${NC}"
    echo -e "   📊 View logs:         ${GREEN}docker-compose -f docker-compose.unified.yml logs -f${NC}"
    echo -e "   🔄 Restart services:  ${GREEN}docker-compose -f docker-compose.unified.yml restart${NC}"
    echo -e "   ⏹️ Stop services:      ${GREEN}docker-compose -f docker-compose.unified.yml down${NC}"
    echo -e "   🏥 Health check:      ${GREEN}curl http://localhost/health${NC}"
    echo ""
    echo -e "${YELLOW}⚠️ IMPORTANT NOTES:${NC}"
    echo -e "   • Change default passwords in production"
    echo -e "   • Configure SSL certificates for HTTPS"
    echo -e "   • Set up regular backups"
    echo -e "   • Monitor resource usage"
    echo ""
    echo -e "${PURPLE}============================================================================${NC}"
}

# ============================================================================
# COMMAND LINE ARGUMENT PARSING
# ============================================================================

show_help() {
    echo "Unified Deployment Script for astron-agent + astron-rpa"
    echo ""
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -h, --help              Show this help message"
    echo "  --skip-deps             Skip dependency checks and installation"
    echo "  --skip-build            Skip building Docker images"
    echo "  --force-recreate        Force recreate all containers"
    echo "  --enable-monitoring     Enable Prometheus and Grafana monitoring"
    echo "  --production            Enable production mode optimizations"
    echo "  --backup                Create backup before deployment"
    echo "  --restore BACKUP_DIR    Restore from backup directory"
    echo ""
    echo "Examples:"
    echo "  $0                      # Standard deployment"
    echo "  $0 --skip-deps          # Skip dependency installation"
    echo "  $0 --enable-monitoring  # Deploy with monitoring"
    echo "  $0 --production         # Production deployment"
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_help
            exit 0
            ;;
        --skip-deps)
            SKIP_DEPS_CHECK=true
            shift
            ;;
        --skip-build)
            SKIP_BUILD=true
            shift
            ;;
        --force-recreate)
            FORCE_RECREATE=true
            shift
            ;;
        --enable-monitoring)
            ENABLE_MONITORING=true
            shift
            ;;
        --production)
            PRODUCTION_MODE=true
            shift
            ;;
        --backup)
            create_backup
            exit 0
            ;;
        --restore)
            RESTORE_DIR="$2"
            if [ -z "$RESTORE_DIR" ]; then
                error "Backup directory not specified"
            fi
            # TODO: Implement restore functionality
            shift 2
            ;;
        *)
            error "Unknown option: $1"
            ;;
    esac
done

# ============================================================================
# MAIN EXECUTION
# ============================================================================

# Trap to cleanup on exit
trap 'echo -e "\n${RED}Deployment interrupted!${NC}"; exit 1' INT TERM

# Start deployment
main() {
    # Clear log file
    > "$LOG_FILE"
    
    # Show banner
    echo -e "${PURPLE}"
    echo "============================================================================"
    echo "                    ASTRON UNIFIED DEPLOYMENT"
    echo "                   astron-agent + astron-rpa"
    echo "============================================================================"
    echo -e "${NC}"
    
    # Run deployment
    deploy
}

# Execute main function
main "$@"

