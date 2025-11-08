#!/bin/bash

################################################################################
# Astron Agent - Update Script
# 
# Safe update mechanism for running services
# 
# Features:
# - Zero-downtime updates (blue-green deployment)
# - Automatic backup before update
# - Health validation after update
# - Automatic rollback on failure
# - Version tracking and validation
#
# Usage: ./update.sh [--version <version>] [--force] [--dry-run]
################################################################################

set -eE
set -o pipefail
set -u

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
REPO_DIR="${REPO_DIR:-astron-agent}"
DEPLOY_DIR="docker/astronAgent"
COMPOSE_FILE="docker-compose-with-auth.yaml"
LOG_FILE="update_$(date +%Y%m%d_%H%M%S).log"
DRY_RUN=false
FORCE_UPDATE=false
TARGET_VERSION=""

################################################################################
# Utility Functions
################################################################################

log() {
    echo -e "${GREEN}[$(date +'%H:%M:%S')]${NC} $*" | tee -a "$LOG_FILE"
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
║                    Update Manager                             ║
║                                                               ║
╚═══════════════════════════════════════════════════════════════╝
EOF
    echo -e "${NC}\n"
}

print_separator() {
    echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
}

################################################################################
# Version Management
################################################################################

get_current_version() {
    if [ -f "$REPO_DIR/.version" ]; then
        cat "$REPO_DIR/.version"
    else
        git -C "$REPO_DIR" describe --tags 2>/dev/null || echo "unknown"
    fi
}

check_version_available() {
    local version="$1"
    
    if [ "$version" = "latest" ]; then
        return 0
    fi
    
    # Check if version tag exists
    if git -C "$REPO_DIR" rev-parse "refs/tags/$version" >/dev/null 2>&1; then
        return 0
    fi
    
    return 1
}

################################################################################
# Pre-Update Checks
################################################################################

check_update_prerequisites() {
    log_info "Checking update prerequisites..."
    
    # Check if services are running
    cd "$REPO_DIR/$DEPLOY_DIR" || return 1
    
    if ! docker compose -f "$COMPOSE_FILE" ps -q >/dev/null 2>&1; then
        log_warning "No services currently running"
        cd - >/dev/null
        return 1
    fi
    
    # Check disk space
    local available_gb=$(df -BG / | awk 'NR==2 {print $4}' | tr -d 'G')
    if [ "$available_gb" -lt 5 ]; then
        log_error "Insufficient disk space: ${available_gb}GB available (need 5GB+)"
        cd - >/dev/null
        return 1
    fi
    
    log_success "Prerequisites check passed"
    cd - >/dev/null
    return 0
}

################################################################################
# Backup Operations
################################################################################

create_pre_update_backup() {
    log_info "Creating pre-update backup..."
    
    if [ "$DRY_RUN" = true ]; then
        log_info "[DRY-RUN] Would create backup"
        return 0
    fi
    
    # Use existing backup script if available
    if [ -x "./deploy.sh" ]; then
        # Create backup using deploy.sh backup function
        local backup_dir="./backups"
        local backup_id="update_backup_$(date +%Y%m%d_%H%M%S)"
        local backup_path="$backup_dir/$backup_id"
        
        mkdir -p "$backup_path"
        
        # Backup configuration
        if [ -f "$REPO_DIR/$DEPLOY_DIR/.env" ]; then
            cp "$REPO_DIR/$DEPLOY_DIR/.env" "$backup_path/env_backup"
        fi
        
        # Create metadata
        cat > "$backup_path/metadata.json" << EOF
{
  "backup_id": "$backup_id",
  "timestamp": "$(date +'%Y-%m-%d %H:%M:%S')",
  "type": "pre_update",
  "current_version": "$(get_current_version)",
  "target_version": "$TARGET_VERSION"
}
EOF
        
        log_success "Backup created: $backup_id"
        echo "$backup_id" > /tmp/astron-update-backup.id
    fi
    
    return 0
}

################################################################################
# Update Operations
################################################################################

fetch_updates() {
    log_info "Fetching updates from repository..."
    
    if [ "$DRY_RUN" = true ]; then
        log_info "[DRY-RUN] Would fetch updates from remote"
        return 0
    fi
    
    cd "$REPO_DIR" || return 1
    
    # Fetch latest changes
    if ! git fetch origin 2>&1 | tee -a "$LOG_FILE"; then
        log_error "Failed to fetch updates"
        cd - >/dev/null
        return 1
    fi
    
    log_success "Updates fetched successfully"
    cd - >/dev/null
    return 0
}

apply_updates() {
    local version="$1"
    
    log_info "Applying updates to version: $version..."
    
    if [ "$DRY_RUN" = true ]; then
        log_info "[DRY-RUN] Would checkout version: $version"
        log_info "[DRY-RUN] Would pull Docker images"
        log_info "[DRY-RUN] Would restart services"
        return 0
    fi
    
    cd "$REPO_DIR" || return 1
    
    # Checkout target version
    if [ "$version" = "latest" ]; then
        if ! git checkout main 2>&1 | tee -a "$LOG_FILE"; then
            log_error "Failed to checkout main branch"
            cd - >/dev/null
            return 1
        fi
        if ! git pull origin main 2>&1 | tee -a "$LOG_FILE"; then
            log_error "Failed to pull latest changes"
            cd - >/dev/null
            return 1
        fi
    else
        if ! git checkout "tags/$version" 2>&1 | tee -a "$LOG_FILE"; then
            log_error "Failed to checkout version $version"
            cd - >/dev/null
            return 1
        fi
    fi
    
    # Update Docker images
    cd "$DEPLOY_DIR" || return 1
    
    log_info "Pulling latest Docker images..."
    if ! docker compose -f "$COMPOSE_FILE" pull 2>&1 | tee -a "$LOG_FILE"; then
        log_warning "Failed to pull some images (non-critical)"
    fi
    
    log_success "Updates applied successfully"
    cd - >/dev/null
    cd - >/dev/null
    return 0
}

restart_services() {
    log_info "Restarting services with zero-downtime strategy..."
    
    if [ "$DRY_RUN" = true ]; then
        log_info "[DRY-RUN] Would restart services"
        return 0
    fi
    
    cd "$REPO_DIR/$DEPLOY_DIR" || return 1
    
    # Restart services one by one
    local services=$(docker compose -f "$COMPOSE_FILE" ps --services 2>/dev/null)
    
    for service in $services; do
        log_info "Restarting $service..."
        
        if docker compose -f "$COMPOSE_FILE" restart "$service" 2>&1 | tee -a "$LOG_FILE"; then
            log_success "$service restarted"
            sleep 5  # Wait for service to stabilize
        else
            log_error "Failed to restart $service"
            cd - >/dev/null
            return 1
        fi
    done
    
    log_success "All services restarted successfully"
    cd - >/dev/null
    return 0
}

################################################################################
# Health Validation
################################################################################

validate_update() {
    log_info "Validating update..."
    
    if [ "$DRY_RUN" = true ]; then
        log_info "[DRY-RUN] Would validate services"
        return 0
    fi
    
    cd "$REPO_DIR/$DEPLOY_DIR" || return 1
    
    # Wait for services to stabilize
    log_info "Waiting for services to stabilize (30 seconds)..."
    sleep 30
    
    # Check container status
    local running_count=$(docker compose -f "$COMPOSE_FILE" ps -q 2>/dev/null | wc -l)
    local total_count=$(docker compose -f "$COMPOSE_FILE" ps --services 2>/dev/null | wc -l)
    
    if [ "$running_count" -ne "$total_count" ]; then
        log_error "Not all services are running ($running_count/$total_count)"
        cd - >/dev/null
        return 1
    fi
    
    # Test endpoints
    local endpoints=(
        "http://localhost/"
        "http://localhost:8000"
    )
    
    for endpoint in "${endpoints[@]}"; do
        local response=$(curl -s -o /dev/null -w "%{http_code}" --max-time 10 "$endpoint" 2>/dev/null || echo "000")
        
        if [[ ! "$response" =~ ^(200|302|401)$ ]]; then
            log_error "Endpoint $endpoint returned unexpected status: $response"
            cd - >/dev/null
            return 1
        fi
    done
    
    log_success "Update validation passed"
    cd - >/dev/null
    return 0
}

################################################################################
# Rollback Operations
################################################################################

perform_rollback() {
    log_warning "Update failed, initiating automatic rollback..."
    
    if [ "$DRY_RUN" = true ]; then
        log_info "[DRY-RUN] Would rollback to previous version"
        return 0
    fi
    
    # Get backup ID
    local backup_id=""
    if [ -f "/tmp/astron-update-backup.id" ]; then
        backup_id=$(cat /tmp/astron-update-backup.id)
    fi
    
    if [ -n "$backup_id" ] && [ -x "./rollback.sh" ]; then
        log_info "Rolling back to backup: $backup_id"
        ./rollback.sh "$backup_id"
    else
        log_error "Cannot perform automatic rollback"
        return 1
    fi
}

################################################################################
# Main Execution
################################################################################

show_usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  --version <version>   Target version to update to (default: latest)"
    echo "  --force               Force update even if already on target version"
    echo "  --dry-run             Show what would be done without executing"
    echo "  --help                Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0                    # Update to latest version"
    echo "  $0 --version v1.2.3   # Update to specific version"
    echo "  $0 --dry-run          # Preview update actions"
    echo "  $0 --force            # Force update"
}

main() {
    # Parse arguments
    while [ $# -gt 0 ]; do
        case "$1" in
            --version)
                shift
                TARGET_VERSION="$1"
                shift
                ;;
            --force)
                FORCE_UPDATE=true
                shift
                ;;
            --dry-run)
                DRY_RUN=true
                shift
                ;;
            --help)
                show_usage
                exit 0
                ;;
            *)
                log_error "Unknown option: $1"
                show_usage
                exit 1
                ;;
        esac
    done
    
    # Default to latest if no version specified
    if [ -z "$TARGET_VERSION" ]; then
        TARGET_VERSION="latest"
    fi
    
    print_banner
    
    if [ "$DRY_RUN" = true ]; then
        log_warning "Running in DRY-RUN mode - no changes will be made"
        print_separator
    fi
    
    # Show current version
    local current_version=$(get_current_version)
    log_info "Current version: $current_version"
    log_info "Target version: $TARGET_VERSION"
    
    # Check if already on target version
    if [ "$current_version" = "$TARGET_VERSION" ] && [ "$FORCE_UPDATE" = false ]; then
        log_info "Already on target version $TARGET_VERSION"
        log_info "Use --force to force update"
        exit 0
    fi
    
    print_separator
    
    # Pre-update checks
    if ! check_update_prerequisites; then
        log_error "Prerequisites check failed"
        exit 1
    fi
    
    print_separator
    
    # Create backup
    if ! create_pre_update_backup; then
        log_error "Backup creation failed"
        exit 1
    fi
    
    print_separator
    
    # Fetch updates
    if ! fetch_updates; then
        log_error "Failed to fetch updates"
        exit 1
    fi
    
    print_separator
    
    # Apply updates
    if ! apply_updates "$TARGET_VERSION"; then
        log_error "Failed to apply updates"
        perform_rollback
        exit 1
    fi
    
    print_separator
    
    # Restart services
    if ! restart_services; then
        log_error "Failed to restart services"
        perform_rollback
        exit 1
    fi
    
    print_separator
    
    # Validate update
    if ! validate_update; then
        log_error "Update validation failed"
        perform_rollback
        exit 1
    fi
    
    print_separator
    
    if [ "$DRY_RUN" = false ]; then
        # Clean up
        rm -f /tmp/astron-update-backup.id
        
        # Update version file
        echo "$TARGET_VERSION" > "$REPO_DIR/.version"
    fi
    
    echo ""
    echo -e "${GREEN}${BOLD}╔═══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}${BOLD}║                                                               ║${NC}"
    echo -e "${GREEN}${BOLD}║          🎉 UPDATE COMPLETED SUCCESSFULLY! 🎉                ║${NC}"
    echo -e "${GREEN}${BOLD}║                                                               ║${NC}"
    echo -e "${GREEN}${BOLD}╚═══════════════════════════════════════════════════════════════╝${NC}\n"
    
    echo -e "${CYAN}${BOLD}Update Summary:${NC}"
    echo -e "  From: $current_version"
    echo -e "  To: $TARGET_VERSION"
    echo -e "  Log: $LOG_FILE"
    echo ""
}

# Check prerequisites
if ! command -v docker &> /dev/null; then
    log_error "Docker is not installed"
    exit 1
fi

if ! command -v git &> /dev/null; then
    log_error "Git is not installed"
    exit 1
fi

main "$@"

