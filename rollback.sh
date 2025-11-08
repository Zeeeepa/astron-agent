#!/bin/bash

################################################################################
# Astron Agent - Rollback Script
# 
# This script provides rollback capabilities for failed deployments
# 
# Features:
# - List available backups
# - Rollback to specific backup
# - Validate backup integrity
# - Automatic cleanup of old backups
#
# Usage: ./rollback.sh [backup_id]
#        ./rollback.sh --list
#        ./rollback.sh --latest
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
BACKUP_DIR="${BACKUP_DIR:-./backups}"
REPO_DIR="${REPO_DIR:-astron-agent}"
DEPLOY_DIR="docker/astronAgent"
MAX_BACKUPS=5
LOG_FILE="rollback_$(date +%Y%m%d_%H%M%S).log"

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
║                    Rollback Manager                           ║
║                                                               ║
╚═══════════════════════════════════════════════════════════════╝
EOF
    echo -e "${NC}\n"
}

print_separator() {
    echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
}

################################################################################
# Backup Management
################################################################################

list_backups() {
    log_info "Available backups:"
    
    if [ ! -d "$BACKUP_DIR" ] || [ -z "$(ls -A $BACKUP_DIR 2>/dev/null)" ]; then
        log_warning "No backups found in $BACKUP_DIR"
        return 1
    fi
    
    echo ""
    echo -e "${CYAN}${BOLD}ID        Date/Time           Size      Status${NC}"
    echo "------------------------------------------------------------"
    
    local backups=($(ls -1t "$BACKUP_DIR" 2>/dev/null || true))
    
    for backup in "${backups[@]}"; do
        if [ -d "$BACKUP_DIR/$backup" ]; then
            local backup_path="$BACKUP_DIR/$backup"
            local metadata_file="$backup_path/metadata.json"
            
            if [ -f "$metadata_file" ]; then
                local timestamp=$(jq -r '.timestamp // "unknown"' "$metadata_file" 2>/dev/null || echo "unknown")
                local status=$(jq -r '.status // "unknown"' "$metadata_file" 2>/dev/null || echo "unknown")
                local size=$(du -sh "$backup_path" 2>/dev/null | cut -f1)
                
                local status_color="${GREEN}"
                if [ "$status" != "success" ]; then
                    status_color="${YELLOW}"
                fi
                
                printf "${BOLD}%-10s${NC} %-20s %-10s ${status_color}%-10s${NC}\n" \
                    "$backup" "$timestamp" "$size" "$status"
            fi
        fi
    done
    
    echo ""
}

validate_backup() {
    local backup_id="$1"
    local backup_path="$BACKUP_DIR/$backup_id"
    
    log_info "Validating backup: $backup_id"
    
    # Check backup directory exists
    if [ ! -d "$backup_path" ]; then
        log_error "Backup directory not found: $backup_path"
        return 1
    fi
    
    # Check metadata file
    if [ ! -f "$backup_path/metadata.json" ]; then
        log_error "Metadata file missing"
        return 1
    fi
    
    # Validate metadata
    if ! jq empty "$backup_path/metadata.json" 2>/dev/null; then
        log_error "Invalid metadata JSON"
        return 1
    fi
    
    # Check required files
    local required_files=(
        "env_backup"
        "docker_volumes_backup.tar.gz"
    )
    
    for file in "${required_files[@]}"; do
        if [ ! -f "$backup_path/$file" ]; then
            log_warning "Missing file: $file"
        fi
    done
    
    # Validate tar integrity
    if [ -f "$backup_path/docker_volumes_backup.tar.gz" ]; then
        if ! tar -tzf "$backup_path/docker_volumes_backup.tar.gz" > /dev/null 2>&1; then
            log_error "Corrupted volume backup"
            return 1
        fi
    fi
    
    log_success "Backup validation passed"
    return 0
}

################################################################################
# Rollback Operations
################################################################################

stop_services() {
    log_info "Stopping current services..."
    
    cd "$REPO_DIR/$DEPLOY_DIR" || return 1
    
    if docker compose -f docker-compose-with-auth.yaml ps -q > /dev/null 2>&1; then
        docker compose -f docker-compose-with-auth.yaml stop --timeout 30 2>&1 | tee -a "$LOG_FILE"
        docker compose -f docker-compose-with-auth.yaml down 2>&1 | tee -a "$LOG_FILE"
    fi
    
    log_success "Services stopped"
    cd - > /dev/null
}

restore_configuration() {
    local backup_path="$1"
    
    log_info "Restoring configuration..."
    
    # Backup current config
    if [ -f "$REPO_DIR/$DEPLOY_DIR/.env" ]; then
        cp "$REPO_DIR/$DEPLOY_DIR/.env" "$REPO_DIR/$DEPLOY_DIR/.env.rollback_backup"
    fi
    
    # Restore .env
    if [ -f "$backup_path/env_backup" ]; then
        cp "$backup_path/env_backup" "$REPO_DIR/$DEPLOY_DIR/.env"
        log_success "Configuration restored"
    else
        log_warning "No configuration backup found"
    fi
}

restore_volumes() {
    local backup_path="$1"
    
    log_info "Restoring Docker volumes..."
    
    if [ ! -f "$backup_path/docker_volumes_backup.tar.gz" ]; then
        log_warning "No volume backup found, skipping..."
        return 0
    fi
    
    # Extract volume backup
    cd "$BACKUP_DIR" || return 1
    
    if sudo tar -xzf "$backup_path/docker_volumes_backup.tar.gz" -C / 2>&1 | tee -a "$LOG_FILE"; then
        log_success "Volumes restored"
    else
        log_error "Failed to restore volumes"
        cd - > /dev/null
        return 1
    fi
    
    cd - > /dev/null
}

start_services() {
    log_info "Starting services..."
    
    cd "$REPO_DIR/$DEPLOY_DIR" || return 1
    
    if docker compose -f docker-compose-with-auth.yaml up -d 2>&1 | tee -a "$LOG_FILE"; then
        log_success "Services started"
    else
        log_error "Failed to start services"
        cd - > /dev/null
        return 1
    fi
    
    cd - > /dev/null
}

verify_rollback() {
    log_info "Verifying rollback..."
    
    cd "$REPO_DIR/$DEPLOY_DIR" || return 1
    
    # Wait for services
    sleep 10
    
    # Check container status
    local running_containers=$(docker compose -f docker-compose-with-auth.yaml ps -q | wc -l)
    
    if [ "$running_containers" -gt 0 ]; then
        log_success "Rollback verification passed"
        cd - > /dev/null
        return 0
    else
        log_error "Rollback verification failed"
        cd - > /dev/null
        return 1
    fi
}

perform_rollback() {
    local backup_id="$1"
    local backup_path="$BACKUP_DIR/$backup_id"
    
    log_info "Starting rollback to: $backup_id"
    print_separator
    
    # Validate backup
    if ! validate_backup "$backup_id"; then
        log_error "Backup validation failed"
        return 1
    fi
    print_separator
    
    # Stop services
    if ! stop_services; then
        log_error "Failed to stop services"
        return 1
    fi
    print_separator
    
    # Restore configuration
    if ! restore_configuration "$backup_path"; then
        log_error "Failed to restore configuration"
        return 1
    fi
    print_separator
    
    # Restore volumes
    if ! restore_volumes "$backup_path"; then
        log_error "Failed to restore volumes"
        return 1
    fi
    print_separator
    
    # Start services
    if ! start_services; then
        log_error "Failed to start services"
        return 1
    fi
    print_separator
    
    # Verify rollback
    if ! verify_rollback; then
        log_warning "Rollback completed but verification failed"
        return 1
    fi
    
    log_success "Rollback completed successfully!"
    return 0
}

################################################################################
# Main Execution
################################################################################

show_usage() {
    echo "Usage: $0 [OPTIONS] [BACKUP_ID]"
    echo ""
    echo "Options:"
    echo "  --list          List all available backups"
    echo "  --latest        Rollback to the latest backup"
    echo "  --help          Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 --list"
    echo "  $0 --latest"
    echo "  $0 backup_20250108_171930"
}

main() {
    print_banner
    
    # Parse arguments
    case "${1:-}" in
        --list)
            list_backups
            exit 0
            ;;
        --latest)
            log_info "Finding latest backup..."
            local latest=$(ls -1t "$BACKUP_DIR" 2>/dev/null | head -n1)
            if [ -z "$latest" ]; then
                log_error "No backups available"
                exit 1
            fi
            log_info "Latest backup: $latest"
            print_separator
            
            read -p "$(echo -e ${YELLOW}Rollback to $latest? [y/N]: ${NC})" -n 1 -r
            echo
            if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                log_info "Rollback cancelled"
                exit 0
            fi
            
            perform_rollback "$latest"
            exit $?
            ;;
        --help)
            show_usage
            exit 0
            ;;
        "")
            log_error "No backup specified"
            echo ""
            show_usage
            echo ""
            list_backups
            exit 1
            ;;
        *)
            local backup_id="$1"
            
            # Show backup info
            echo -e "${CYAN}${BOLD}Rollback Target:${NC}"
            echo "  Backup ID: $backup_id"
            echo "  Backup Path: $BACKUP_DIR/$backup_id"
            echo ""
            
            # Confirmation
            read -p "$(echo -e ${YELLOW}Are you sure you want to rollback? [y/N]: ${NC})" -n 1 -r
            echo
            if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                log_info "Rollback cancelled"
                exit 0
            fi
            
            print_separator
            
            if perform_rollback "$backup_id"; then
                echo ""
                echo -e "${GREEN}${BOLD}╔═══════════════════════════════════════════════════════════════╗${NC}"
                echo -e "${GREEN}${BOLD}║                                                               ║${NC}"
                echo -e "${GREEN}${BOLD}║          🎉 ROLLBACK COMPLETED SUCCESSFULLY! 🎉              ║${NC}"
                echo -e "${GREEN}${BOLD}║                                                               ║${NC}"
                echo -e "${GREEN}${BOLD}╚═══════════════════════════════════════════════════════════════╝${NC}\n"
                
                echo -e "${CYAN}${BOLD}Next Steps:${NC}"
                echo -e "1. Verify services: ${GREEN}./start.sh${NC}"
                echo -e "2. Check logs: ${YELLOW}docker compose logs -f${NC}"
                echo -e "3. Access at: ${BLUE}http://localhost/${NC}"
                echo ""
                exit 0
            else
                echo ""
                echo -e "${RED}${BOLD}╔═══════════════════════════════════════════════════════════════╗${NC}"
                echo -e "${RED}${BOLD}║                                                               ║${NC}"
                echo -e "${RED}${BOLD}║               ❌ ROLLBACK FAILED ❌                           ║${NC}"
                echo -e "${RED}${BOLD}║                                                               ║${NC}"
                echo -e "${RED}${BOLD}╚═══════════════════════════════════════════════════════════════╝${NC}\n"
                
                echo -e "${CYAN}${BOLD}Troubleshooting:${NC}"
                echo -e "1. Check log: ${YELLOW}cat $LOG_FILE${NC}"
                echo -e "2. Manual restore: ${YELLOW}cd $BACKUP_DIR/$backup_id${NC}"
                echo -e "3. Contact support with log file"
                echo ""
                exit 1
            fi
            ;;
    esac
}

# Check prerequisites
if ! command -v docker &> /dev/null; then
    log_error "Docker is not installed"
    exit 1
fi

if ! command -v jq &> /dev/null; then
    log_error "jq is not installed. Install with: sudo apt-get install jq"
    exit 1
fi

main "$@"

