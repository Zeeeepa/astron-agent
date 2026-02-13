#!/bin/bash

# ============================================================================
# HEALTH CHECK SCRIPT
# Comprehensive health monitoring for astron-agent + astron-rpa
# ============================================================================

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PARENT_DIR="$(dirname "$SCRIPT_DIR")"
ENV_FILE="${PARENT_DIR}/.env.unified"

# Load environment variables
if [ -f "$ENV_FILE" ]; then
    source "$ENV_FILE"
fi

# Service endpoints
declare -A SERVICES=(
    ["MySQL"]="localhost:3306"
    ["PostgreSQL"]="localhost:5432"
    ["Redis"]="localhost:6379"
    ["MinIO"]="http://localhost:9000/minio/health/live"
    ["Elasticsearch"]="http://localhost:9200/_cluster/health"
    ["Kafka"]="localhost:9092"
    ["Casdoor"]="http://localhost:8000/api/get-global-providers"
    ["RPA AI Service"]="http://localhost:8010/health"
    ["RPA OpenAPI Service"]="http://localhost:8020/health"
    ["RPA Resource Service"]="http://localhost:8030/health"
    ["RPA Robot Service"]="http://localhost:8040/health"
    ["RPA Frontend"]="http://localhost:32742"
    ["Agent Core"]="http://localhost:17870/health"
    ["Agent RPA Plugin"]="http://localhost:8003/health"
    ["Agent Knowledge"]="http://localhost:7881/health"
    ["Agent Memory"]="http://localhost:7882/health"
    ["Agent Tenant"]="http://localhost:7883/health"
    ["Agent Workflow"]="http://localhost:7880/health"
    ["Agent Console Hub"]="http://localhost:8080/health"
    ["Agent Console Frontend"]="http://localhost:1881"
    ["Nginx Proxy"]="http://localhost:80/health"
)

# Docker containers
declare -A CONTAINERS=(
    ["unified-mysql"]="MySQL Database"
    ["unified-postgres"]="PostgreSQL Database"
    ["unified-redis"]="Redis Cache"
    ["unified-minio"]="MinIO Storage"
    ["unified-elasticsearch"]="Elasticsearch"
    ["unified-kafka"]="Kafka Broker"
    ["astron-rpa-casdoor"]="Casdoor Auth"
    ["astron-rpa-ai-service"]="RPA AI Service"
    ["astron-rpa-openapi-service"]="RPA OpenAPI Service"
    ["astron-rpa-resource-service"]="RPA Resource Service"
    ["astron-rpa-robot-service"]="RPA Robot Service"
    ["astron-rpa-frontend"]="RPA Frontend"
    ["astron-agent-core-agent"]="Agent Core"
    ["astron-agent-core-rpa"]="Agent RPA Plugin"
    ["astron-agent-core-knowledge"]="Agent Knowledge"
    ["astron-agent-core-memory"]="Agent Memory"
    ["astron-agent-core-tenant"]="Agent Tenant"
    ["astron-agent-core-workflow"]="Agent Workflow"
    ["astron-agent-console-hub"]="Agent Console Hub"
    ["astron-agent-console-frontend"]="Agent Console Frontend"
    ["unified-nginx"]="Nginx Proxy"
)

# ============================================================================
# UTILITY FUNCTIONS
# ============================================================================

log() {
    echo -e "${GREEN}[$(date +'%H:%M:%S')]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[$(date +'%H:%M:%S')] WARNING:${NC} $1"
}

error() {
    echo -e "${RED}[$(date +'%H:%M:%S')] ERROR:${NC} $1"
}

success() {
    echo -e "${GREEN}[$(date +'%H:%M:%S')] SUCCESS:${NC} $1"
}

# ============================================================================
# HEALTH CHECK FUNCTIONS
# ============================================================================

check_docker_status() {
    log "🐳 Checking Docker status..."
    
    if ! docker info &> /dev/null; then
        error "Docker daemon is not running"
        return 1
    fi
    
    success "Docker daemon is running"
    return 0
}

check_container_status() {
    log "📦 Checking container status..."
    
    local failed_containers=()
    local total_containers=${#CONTAINERS[@]}
    local healthy_containers=0
    
    echo ""
    printf "%-35s %-20s %-15s %s\n" "CONTAINER" "SERVICE" "STATUS" "HEALTH"
    printf "%-35s %-20s %-15s %s\n" "$(printf '%*s' 35 | tr ' ' '-')" "$(printf '%*s' 20 | tr ' ' '-')" "$(printf '%*s' 15 | tr ' ' '-')" "$(printf '%*s' 10 | tr ' ' '-')"
    
    for container in "${!CONTAINERS[@]}"; do
        local service_name="${CONTAINERS[$container]}"
        local status=$(docker inspect --format='{{.State.Status}}' "$container" 2>/dev/null || echo "not found")
        local health=$(docker inspect --format='{{.State.Health.Status}}' "$container" 2>/dev/null || echo "no healthcheck")
        
        if [ "$status" = "running" ]; then
            if [ "$health" = "healthy" ] || [ "$health" = "no healthcheck" ]; then
                printf "%-35s %-20s ${GREEN}%-15s${NC} %s\n" "$container" "$service_name" "$status" "$health"
                ((healthy_containers++))
            else
                printf "%-35s %-20s ${YELLOW}%-15s${NC} ${RED}%s${NC}\n" "$container" "$service_name" "$status" "$health"
                failed_containers+=("$container")
            fi
        else
            printf "%-35s %-20s ${RED}%-15s${NC} %s\n" "$container" "$service_name" "$status" "$health"
            failed_containers+=("$container")
        fi
    done
    
    echo ""
    
    if [ ${#failed_containers[@]} -eq 0 ]; then
        success "All $total_containers containers are healthy"
        return 0
    else
        error "${#failed_containers[@]} containers have issues: ${failed_containers[*]}"
        return 1
    fi
}

check_service_endpoints() {
    log "🌐 Checking service endpoints..."
    
    local failed_services=()
    local total_services=${#SERVICES[@]}
    local healthy_services=0
    
    echo ""
    printf "%-25s %-45s %-15s %s\n" "SERVICE" "ENDPOINT" "STATUS" "RESPONSE TIME"
    printf "%-25s %-45s %-15s %s\n" "$(printf '%*s' 25 | tr ' ' '-')" "$(printf '%*s' 45 | tr ' ' '-')" "$(printf '%*s' 15 | tr ' ' '-')" "$(printf '%*s' 15 | tr ' ' '-')"
    
    for service in "${!SERVICES[@]}"; do
        local endpoint="${SERVICES[$service]}"
        local start_time=$(date +%s%N)
        
        if [[ "$endpoint" == http* ]]; then
            # HTTP endpoint
            if curl -f -s --max-time 10 "$endpoint" > /dev/null 2>&1; then
                local end_time=$(date +%s%N)
                local response_time=$(( (end_time - start_time) / 1000000 ))
                printf "%-25s %-45s ${GREEN}%-15s${NC} %s ms\n" "$service" "$endpoint" "healthy" "$response_time"
                ((healthy_services++))
            else
                printf "%-25s %-45s ${RED}%-15s${NC} %s\n" "$service" "$endpoint" "unhealthy" "timeout"
                failed_services+=("$service")
            fi
        else
            # TCP endpoint
            local host=$(echo "$endpoint" | cut -d: -f1)
            local port=$(echo "$endpoint" | cut -d: -f2)
            
            if timeout 5 bash -c "</dev/tcp/$host/$port" 2>/dev/null; then
                local end_time=$(date +%s%N)
                local response_time=$(( (end_time - start_time) / 1000000 ))
                printf "%-25s %-45s ${GREEN}%-15s${NC} %s ms\n" "$service" "$endpoint" "healthy" "$response_time"
                ((healthy_services++))
            else
                printf "%-25s %-45s ${RED}%-15s${NC} %s\n" "$service" "$endpoint" "unhealthy" "timeout"
                failed_services+=("$service")
            fi
        fi
    done
    
    echo ""
    
    if [ ${#failed_services[@]} -eq 0 ]; then
        success "All $total_services services are healthy"
        return 0
    else
        error "${#failed_services[@]} services are unhealthy: ${failed_services[*]}"
        return 1
    fi
}

check_resource_usage() {
    log "📊 Checking resource usage..."
    
    echo ""
    echo "System Resources:"
    echo "=================="
    
    # CPU usage
    local cpu_usage=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | cut -d'%' -f1)
    echo -e "CPU Usage: ${cpu_usage}%"
    
    # Memory usage
    local memory_info=$(free -h | awk 'NR==2{printf "Memory Usage: %s/%s (%.2f%%)", $3,$2,$3*100/$2}')
    echo -e "$memory_info"
    
    # Disk usage
    local disk_usage=$(df -h / | awk 'NR==2{printf "Disk Usage: %s/%s (%s)", $3,$2,$5}')
    echo -e "$disk_usage"
    
    echo ""
    echo "Docker Resources:"
    echo "=================="
    
    # Docker system info
    docker system df --format "table {{.Type}}\t{{.TotalCount}}\t{{.Size}}\t{{.Reclaimable}}"
    
    echo ""
    
    # Container resource usage
    echo "Container Resource Usage:"
    echo "========================="
    docker stats --no-stream --format "table {{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.NetIO}}\t{{.BlockIO}}"
}

check_logs_for_errors() {
    log "📋 Checking recent logs for errors..."
    
    local error_count=0
    local containers_with_errors=()
    
    echo ""
    echo "Recent Error Summary:"
    echo "===================="
    
    for container in "${!CONTAINERS[@]}"; do
        if docker ps --format '{{.Names}}' | grep -q "^${container}$"; then
            local recent_errors=$(docker logs --since=10m "$container" 2>&1 | grep -i -E "(error|exception|failed|fatal)" | wc -l)
            
            if [ "$recent_errors" -gt 0 ]; then
                echo -e "${RED}$container${NC}: $recent_errors errors in last 10 minutes"
                containers_with_errors+=("$container")
                ((error_count += recent_errors))
            fi
        fi
    done
    
    if [ $error_count -eq 0 ]; then
        success "No recent errors found in logs"
    else
        warn "Found $error_count errors across ${#containers_with_errors[@]} containers"
        
        echo ""
        echo "Containers with errors: ${containers_with_errors[*]}"
        echo "Use 'docker logs <container_name>' to investigate further"
    fi
    
    echo ""
}

check_integration_status() {
    log "🔗 Checking service integration..."
    
    echo ""
    echo "Integration Tests:"
    echo "=================="
    
    # Test RPA integration
    echo -n "RPA Plugin → RPA Services: "
    if curl -f -s --max-time 10 "http://localhost:8003/health" > /dev/null && \
       curl -f -s --max-time 10 "http://localhost:8020/health" > /dev/null; then
        echo -e "${GREEN}✓ Connected${NC}"
    else
        echo -e "${RED}✗ Failed${NC}"
    fi
    
    # Test Agent Console → Agent Core
    echo -n "Agent Console → Agent Core: "
    if curl -f -s --max-time 10 "http://localhost:8080/health" > /dev/null && \
       curl -f -s --max-time 10 "http://localhost:17870/health" > /dev/null; then
        echo -e "${GREEN}✓ Connected${NC}"
    else
        echo -e "${RED}✗ Failed${NC}"
    fi
    
    # Test Nginx → Services
    echo -n "Nginx Proxy → Services: "
    if curl -f -s --max-time 10 "http://localhost/health" > /dev/null; then
        echo -e "${GREEN}✓ Connected${NC}"
    else
        echo -e "${RED}✗ Failed${NC}"
    fi
    
    # Test Database connections
    echo -n "Services → Databases: "
    local db_connections=0
    
    # Check MySQL connections
    if docker exec unified-mysql mysql -u root -p"${MYSQL_ROOT_PASSWORD:-root123}" -e "SHOW PROCESSLIST;" &>/dev/null; then
        ((db_connections++))
    fi
    
    # Check PostgreSQL connections
    if docker exec unified-postgres psql -U "${POSTGRES_USER:-spark}" -d "${POSTGRES_DB:-sparkdb_manager}" -c "SELECT 1;" &>/dev/null; then
        ((db_connections++))
    fi
    
    if [ $db_connections -eq 2 ]; then
        echo -e "${GREEN}✓ Connected${NC}"
    else
        echo -e "${YELLOW}⚠ Partial (${db_connections}/2)${NC}"
    fi
    
    echo ""
}

# ============================================================================
# MAIN HEALTH CHECK FUNCTION
# ============================================================================

run_health_check() {
    echo -e "${BLUE}"
    echo "============================================================================"
    echo "                    ASTRON UNIFIED HEALTH CHECK"
    echo "                      $(date +'%Y-%m-%d %H:%M:%S')"
    echo "============================================================================"
    echo -e "${NC}"
    
    local checks_passed=0
    local total_checks=6
    
    # Run all health checks
    if check_docker_status; then ((checks_passed++)); fi
    if check_container_status; then ((checks_passed++)); fi
    if check_service_endpoints; then ((checks_passed++)); fi
    if check_integration_status; then ((checks_passed++)); fi
    check_resource_usage  # Always runs, doesn't affect pass/fail
    check_logs_for_errors  # Always runs, doesn't affect pass/fail
    
    # Summary
    echo -e "${BLUE}"
    echo "============================================================================"
    echo "                           HEALTH CHECK SUMMARY"
    echo "============================================================================"
    echo -e "${NC}"
    
    if [ $checks_passed -eq $total_checks ]; then
        success "🎉 All systems are healthy! ($checks_passed/$total_checks checks passed)"
        echo ""
        echo -e "${GREEN}✅ System Status: HEALTHY${NC}"
        echo -e "${GREEN}✅ All services are operational${NC}"
        echo -e "${GREEN}✅ Integration tests passed${NC}"
        exit 0
    else
        error "⚠️ Some issues detected ($checks_passed/$total_checks checks passed)"
        echo ""
        echo -e "${RED}❌ System Status: DEGRADED${NC}"
        echo -e "${YELLOW}⚠️ Some services may not be fully operational${NC}"
        echo -e "${YELLOW}⚠️ Check the details above for specific issues${NC}"
        exit 1
    fi
}

# ============================================================================
# COMMAND LINE OPTIONS
# ============================================================================

show_help() {
    echo "Health Check Script for astron-agent + astron-rpa"
    echo ""
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -h, --help          Show this help message"
    echo "  --containers        Check only container status"
    echo "  --services          Check only service endpoints"
    echo "  --resources         Check only resource usage"
    echo "  --logs              Check only recent logs"
    echo "  --integration       Check only service integration"
    echo "  --json              Output results in JSON format"
    echo "  --watch             Continuous monitoring mode"
    echo ""
}

# Parse command line arguments
case "${1:-}" in
    -h|--help)
        show_help
        exit 0
        ;;
    --containers)
        check_docker_status && check_container_status
        ;;
    --services)
        check_service_endpoints
        ;;
    --resources)
        check_resource_usage
        ;;
    --logs)
        check_logs_for_errors
        ;;
    --integration)
        check_integration_status
        ;;
    --watch)
        while true; do
            clear
            run_health_check
            sleep 30
        done
        ;;
    *)
        run_health_check
        ;;
esac

