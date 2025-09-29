#!/bin/bash

# ============================================================================
# SERVICE MANAGEMENT SCRIPT
# Manage astron-agent + astron-rpa services
# ============================================================================

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m'

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PARENT_DIR="$(dirname "$SCRIPT_DIR")"
ENV_FILE="${PARENT_DIR}/.env.unified"
COMPOSE_FILE="${PARENT_DIR}/docker-compose.unified.yml"

# Service groups
INFRASTRUCTURE_SERVICES="mysql redis minio postgres elasticsearch kafka"
RPA_SERVICES="casdoor rpa-ai-service rpa-openapi-service rpa-resource-service rpa-robot-service rpa-frontend"
AGENT_SERVICES="agent-core-agent agent-core-rpa agent-core-knowledge agent-core-memory agent-core-tenant agent-core-workflow agent-console-frontend agent-console-hub"
PROXY_SERVICES="nginx"

ALL_SERVICES="$INFRASTRUCTURE_SERVICES $RPA_SERVICES $AGENT_SERVICES $PROXY_SERVICES"

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

info() {
    echo -e "${BLUE}[$(date +'%H:%M:%S')] INFO:${NC} $1"
}

# ============================================================================
# DOCKER COMPOSE WRAPPER
# ============================================================================

dc() {
    docker-compose -f "$COMPOSE_FILE" --env-file "$ENV_FILE" "$@"
}

# ============================================================================
# SERVICE MANAGEMENT FUNCTIONS
# ============================================================================

start_services() {
    local services="$1"
    local group_name="$2"
    
    if [ -z "$services" ]; then
        services="$ALL_SERVICES"
        group_name="all"
    fi
    
    log "🚀 Starting $group_name services..."
    
    for service in $services; do
        info "Starting $service..."
        dc up -d "$service"
    done
    
    success "✅ $group_name services started"
}

stop_services() {
    local services="$1"
    local group_name="$2"
    
    if [ -z "$services" ]; then
        services="$ALL_SERVICES"
        group_name="all"
    fi
    
    log "⏹️ Stopping $group_name services..."
    
    for service in $services; do
        info "Stopping $service..."
        dc stop "$service"
    done
    
    success "✅ $group_name services stopped"
}

restart_services() {
    local services="$1"
    local group_name="$2"
    
    if [ -z "$services" ]; then
        services="$ALL_SERVICES"
        group_name="all"
    fi
    
    log "🔄 Restarting $group_name services..."
    
    for service in $services; do
        info "Restarting $service..."
        dc restart "$service"
    done
    
    success "✅ $group_name services restarted"
}

remove_services() {
    local services="$1"
    local group_name="$2"
    local force="$3"
    
    if [ -z "$services" ]; then
        services="$ALL_SERVICES"
        group_name="all"
    fi
    
    if [ "$force" != "--force" ]; then
        echo -e "${YELLOW}⚠️ This will remove containers and their data!${NC}"
        read -p "Are you sure? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            info "Operation cancelled"
            return 0
        fi
    fi
    
    log "🗑️ Removing $group_name services..."
    
    for service in $services; do
        info "Removing $service..."
        dc rm -f -s "$service" 2>/dev/null || true
    done
    
    success "✅ $group_name services removed"
}

scale_service() {
    local service="$1"
    local replicas="$2"
    
    if [ -z "$service" ] || [ -z "$replicas" ]; then
        error "Usage: scale <service> <replicas>"
        return 1
    fi
    
    log "📈 Scaling $service to $replicas replicas..."
    dc up -d --scale "$service=$replicas" "$service"
    success "✅ $service scaled to $replicas replicas"
}

# ============================================================================
# STATUS AND MONITORING
# ============================================================================

show_status() {
    log "📊 Service Status Overview"
    echo ""
    
    # Container status
    echo -e "${BLUE}Container Status:${NC}"
    dc ps --format "table {{.Name}}\t{{.State}}\t{{.Status}}\t{{.Ports}}"
    echo ""
    
    # Resource usage
    echo -e "${BLUE}Resource Usage:${NC}"
    docker stats --no-stream --format "table {{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.NetIO}}" $(dc ps -q) 2>/dev/null || echo "No running containers"
    echo ""
    
    # Service health
    echo -e "${BLUE}Service Health:${NC}"
    local healthy=0
    local total=0
    
    for service in $ALL_SERVICES; do
        ((total++))
        local container_name=$(dc ps -q "$service" 2>/dev/null)
        if [ -n "$container_name" ]; then
            local status=$(docker inspect --format='{{.State.Status}}' "$container_name" 2>/dev/null || echo "unknown")
            local health=$(docker inspect --format='{{.State.Health.Status}}' "$container_name" 2>/dev/null || echo "no healthcheck")
            
            if [ "$status" = "running" ] && ([ "$health" = "healthy" ] || [ "$health" = "no healthcheck" ]); then
                echo -e "  ${GREEN}✓${NC} $service"
                ((healthy++))
            else
                echo -e "  ${RED}✗${NC} $service ($status, $health)"
            fi
        else
            echo -e "  ${RED}✗${NC} $service (not running)"
        fi
    done
    
    echo ""
    echo -e "${BLUE}Overall Health: ${healthy}/${total} services healthy${NC}"
}

show_logs() {
    local service="$1"
    local lines="${2:-100}"
    local follow="${3:-false}"
    
    if [ -z "$service" ]; then
        log "📋 Showing logs for all services (last $lines lines)..."
        if [ "$follow" = "true" ]; then
            dc logs -f --tail="$lines"
        else
            dc logs --tail="$lines"
        fi
    else
        log "📋 Showing logs for $service (last $lines lines)..."
        if [ "$follow" = "true" ]; then
            dc logs -f --tail="$lines" "$service"
        else
            dc logs --tail="$lines" "$service"
        fi
    fi
}

exec_service() {
    local service="$1"
    shift
    local command="$@"
    
    if [ -z "$service" ]; then
        error "Service name required"
        return 1
    fi
    
    if [ -z "$command" ]; then
        command="/bin/bash"
    fi
    
    log "🔧 Executing command in $service: $command"
    dc exec "$service" $command
}

# ============================================================================
# BACKUP AND RESTORE
# ============================================================================

backup_data() {
    local backup_dir="${PARENT_DIR}/backups/backup-$(date +%Y%m%d-%H%M%S)"
    
    log "💾 Creating backup..."
    mkdir -p "$backup_dir"
    
    # Backup databases
    info "Backing up MySQL..."
    dc exec -T mysql mysqldump --all-databases -u root -p"${MYSQL_ROOT_PASSWORD:-root123}" > "$backup_dir/mysql-backup.sql" 2>/dev/null || warn "MySQL backup failed"
    
    info "Backing up PostgreSQL..."
    dc exec -T postgres pg_dumpall -U "${POSTGRES_USER:-spark}" > "$backup_dir/postgres-backup.sql" 2>/dev/null || warn "PostgreSQL backup failed"
    
    # Backup volumes
    info "Backing up data volumes..."
    docker run --rm -v mysql_data:/data -v "$backup_dir":/backup alpine tar czf /backup/mysql-data.tar.gz -C /data . 2>/dev/null || warn "MySQL volume backup failed"
    docker run --rm -v postgres_data:/data -v "$backup_dir":/backup alpine tar czf /backup/postgres-data.tar.gz -C /data . 2>/dev/null || warn "PostgreSQL volume backup failed"
    docker run --rm -v minio_data:/data -v "$backup_dir":/backup alpine tar czf /backup/minio-data.tar.gz -C /data . 2>/dev/null || warn "MinIO volume backup failed"
    
    # Backup configuration
    info "Backing up configuration..."
    cp "$ENV_FILE" "$backup_dir/" 2>/dev/null || warn "Environment file backup failed"
    cp "$COMPOSE_FILE" "$backup_dir/" 2>/dev/null || warn "Compose file backup failed"
    
    success "✅ Backup created: $backup_dir"
}

# ============================================================================
# MAINTENANCE FUNCTIONS
# ============================================================================

update_services() {
    log "🔄 Updating services..."
    
    # Pull latest images
    info "Pulling latest images..."
    dc pull
    
    # Rebuild services
    info "Rebuilding services..."
    dc build --no-cache
    
    # Restart services
    info "Restarting services..."
    dc up -d
    
    success "✅ Services updated"
}

cleanup_system() {
    log "🧹 Cleaning up system..."
    
    # Remove unused containers
    info "Removing unused containers..."
    docker container prune -f
    
    # Remove unused images
    info "Removing unused images..."
    docker image prune -f
    
    # Remove unused volumes
    info "Removing unused volumes..."
    docker volume prune -f
    
    # Remove unused networks
    info "Removing unused networks..."
    docker network prune -f
    
    success "✅ System cleanup completed"
}

reset_system() {
    echo -e "${RED}⚠️ WARNING: This will completely reset the system!${NC}"
    echo -e "${RED}⚠️ All data will be lost!${NC}"
    read -p "Are you sure? Type 'RESET' to confirm: " -r
    
    if [ "$REPLY" != "RESET" ]; then
        info "Operation cancelled"
        return 0
    fi
    
    log "🔄 Resetting system..."
    
    # Stop all services
    dc down -v --remove-orphans
    
    # Remove all containers
    docker container prune -f
    
    # Remove all volumes
    docker volume prune -f
    
    # Remove all images
    docker image prune -a -f
    
    # Remove networks
    docker network prune -f
    
    success "✅ System reset completed"
}

# ============================================================================
# HELP AND USAGE
# ============================================================================

show_help() {
    echo -e "${PURPLE}Service Management Script for astron-agent + astron-rpa${NC}"
    echo ""
    echo -e "${BLUE}Usage:${NC} $0 <command> [options]"
    echo ""
    echo -e "${BLUE}Service Management:${NC}"
    echo "  start [group]           Start services (all, infra, rpa, agent, proxy)"
    echo "  stop [group]            Stop services"
    echo "  restart [group]         Restart services"
    echo "  remove [group] [--force] Remove services"
    echo "  scale <service> <count> Scale service to specified replicas"
    echo ""
    echo -e "${BLUE}Monitoring:${NC}"
    echo "  status                  Show service status overview"
    echo "  logs [service] [lines]  Show logs (default: all services, 100 lines)"
    echo "  follow [service]        Follow logs in real-time"
    echo "  exec <service> [cmd]    Execute command in service container"
    echo ""
    echo -e "${BLUE}Maintenance:${NC}"
    echo "  backup                  Create backup of data and configuration"
    echo "  update                  Update all services to latest versions"
    echo "  cleanup                 Clean up unused Docker resources"
    echo "  reset                   Reset entire system (WARNING: destroys all data)"
    echo ""
    echo -e "${BLUE}Service Groups:${NC}"
    echo "  infra                   Infrastructure services (mysql, redis, minio, etc.)"
    echo "  rpa                     RPA platform services"
    echo "  agent                   Agent platform services"
    echo "  proxy                   Reverse proxy (nginx)"
    echo "  all                     All services (default)"
    echo ""
    echo -e "${BLUE}Examples:${NC}"
    echo "  $0 start infra          # Start infrastructure services"
    echo "  $0 restart rpa          # Restart RPA services"
    echo "  $0 logs rpa-ai-service  # Show logs for RPA AI service"
    echo "  $0 scale nginx 3        # Scale nginx to 3 replicas"
    echo "  $0 exec mysql bash      # Open bash in MySQL container"
}

# ============================================================================
# MAIN COMMAND PROCESSING
# ============================================================================

main() {
    local command="$1"
    shift || true
    
    case "$command" in
        start)
            local group="$1"
            case "$group" in
                infra|infrastructure)
                    start_services "$INFRASTRUCTURE_SERVICES" "infrastructure"
                    ;;
                rpa)
                    start_services "$RPA_SERVICES" "RPA"
                    ;;
                agent)
                    start_services "$AGENT_SERVICES" "Agent"
                    ;;
                proxy)
                    start_services "$PROXY_SERVICES" "proxy"
                    ;;
                all|"")
                    start_services "$ALL_SERVICES" "all"
                    ;;
                *)
                    start_services "$group" "custom"
                    ;;
            esac
            ;;
        stop)
            local group="$1"
            case "$group" in
                infra|infrastructure)
                    stop_services "$INFRASTRUCTURE_SERVICES" "infrastructure"
                    ;;
                rpa)
                    stop_services "$RPA_SERVICES" "RPA"
                    ;;
                agent)
                    stop_services "$AGENT_SERVICES" "Agent"
                    ;;
                proxy)
                    stop_services "$PROXY_SERVICES" "proxy"
                    ;;
                all|"")
                    stop_services "$ALL_SERVICES" "all"
                    ;;
                *)
                    stop_services "$group" "custom"
                    ;;
            esac
            ;;
        restart)
            local group="$1"
            case "$group" in
                infra|infrastructure)
                    restart_services "$INFRASTRUCTURE_SERVICES" "infrastructure"
                    ;;
                rpa)
                    restart_services "$RPA_SERVICES" "RPA"
                    ;;
                agent)
                    restart_services "$AGENT_SERVICES" "Agent"
                    ;;
                proxy)
                    restart_services "$PROXY_SERVICES" "proxy"
                    ;;
                all|"")
                    restart_services "$ALL_SERVICES" "all"
                    ;;
                *)
                    restart_services "$group" "custom"
                    ;;
            esac
            ;;
        remove)
            local group="$1"
            local force="$2"
            case "$group" in
                infra|infrastructure)
                    remove_services "$INFRASTRUCTURE_SERVICES" "infrastructure" "$force"
                    ;;
                rpa)
                    remove_services "$RPA_SERVICES" "RPA" "$force"
                    ;;
                agent)
                    remove_services "$AGENT_SERVICES" "Agent" "$force"
                    ;;
                proxy)
                    remove_services "$PROXY_SERVICES" "proxy" "$force"
                    ;;
                all|"")
                    remove_services "$ALL_SERVICES" "all" "$force"
                    ;;
                *)
                    remove_services "$group" "custom" "$force"
                    ;;
            esac
            ;;
        scale)
            scale_service "$1" "$2"
            ;;
        status)
            show_status
            ;;
        logs)
            show_logs "$1" "$2" false
            ;;
        follow)
            show_logs "$1" "${2:-100}" true
            ;;
        exec)
            exec_service "$@"
            ;;
        backup)
            backup_data
            ;;
        update)
            update_services
            ;;
        cleanup)
            cleanup_system
            ;;
        reset)
            reset_system
            ;;
        help|--help|-h)
            show_help
            ;;
        "")
            show_help
            ;;
        *)
            error "Unknown command: $command"
            echo ""
            show_help
            exit 1
            ;;
    esac
}

# Execute main function
main "$@"

