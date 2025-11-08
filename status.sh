#!/bin/bash

################################################################################
# Astron Agent - Status Checker
# 
# Provides comprehensive status information about the deployed system
# 
# Features:
# - Service health status
# - Deployment information
# - Resource usage
# - Recent activity
# - Quick diagnostics
#
# Usage: ./status.sh [--services|--health|--resources|--deployment|--all]
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

################################################################################
# Utility Functions
################################################################################

print_header() {
    local title="$1"
    echo -e "\n${CYAN}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${CYAN}${BOLD}  $title${NC}"
    echo -e "${CYAN}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

print_section() {
    local title="$1"
    echo -e "\n${BLUE}${BOLD}▶ $title${NC}"
}

status_icon() {
    local status="$1"
    case "$status" in
        "running"|"healthy"|"success"|"online")
            echo -e "${GREEN}✓${NC}"
            ;;
        "starting"|"degraded"|"warning")
            echo -e "${YELLOW}◐${NC}"
            ;;
        "stopped"|"unhealthy"|"failed"|"offline")
            echo -e "${RED}✗${NC}"
            ;;
        *)
            echo -e "${BLUE}○${NC}"
            ;;
    esac
}

################################################################################
# Status Functions
################################################################################

check_services_status() {
    print_section "Service Status"
    
    if [ ! -d "$REPO_DIR/$DEPLOY_DIR" ]; then
        echo -e "${RED}  Deployment directory not found${NC}"
        return 1
    fi
    
    cd "$REPO_DIR/$DEPLOY_DIR" || return 1
    
    # Check if Docker Compose is running
    if ! docker compose -f "$COMPOSE_FILE" ps -q > /dev/null 2>&1; then
        echo -e "${YELLOW}  No services running${NC}"
        cd - > /dev/null
        return 1
    fi
    
    # Get service list
    local services=$(docker compose -f "$COMPOSE_FILE" ps --services 2>/dev/null)
    
    if [ -z "$services" ]; then
        echo -e "${YELLOW}  No services configured${NC}"
        cd - > /dev/null
        return 1
    fi
    
    # Display service status table
    printf "  ${BOLD}%-20s %-12s %-15s %-10s${NC}\n" "SERVICE" "STATUS" "HEALTH" "UPTIME"
    echo "  ────────────────────────────────────────────────────────────"
    
    for service in $services; do
        local container_id=$(docker compose -f "$COMPOSE_FILE" ps -q "$service" 2>/dev/null)
        
        if [ -z "$container_id" ]; then
            printf "  %-20s ${RED}%-12s${NC} %-15s %-10s\n" "$service" "not found" "-" "-"
            continue
        fi
        
        local status=$(docker inspect --format='{{.State.Status}}' "$container_id" 2>/dev/null || echo "unknown")
        local health=$(docker inspect --format='{{.State.Health.Status}}' "$container_id" 2>/dev/null || echo "-")
        local started=$(docker inspect --format='{{.State.StartedAt}}' "$container_id" 2>/dev/null || echo "-")
        
        # Calculate uptime
        local uptime="-"
        if [ "$status" = "running" ] && [ "$started" != "-" ]; then
            local start_epoch=$(date -d "$started" +%s 2>/dev/null || echo "0")
            local now_epoch=$(date +%s)
            local diff=$((now_epoch - start_epoch))
            
            if [ $diff -gt 86400 ]; then
                uptime="$((diff / 86400))d"
            elif [ $diff -gt 3600 ]; then
                uptime="$((diff / 3600))h"
            elif [ $diff -gt 60 ]; then
                uptime="$((diff / 60))m"
            else
                uptime="${diff}s"
            fi
        fi
        
        # Format health
        if [ "$health" = "<no value>" ]; then
            health="-"
        fi
        
        # Color status
        local status_colored="$status"
        case "$status" in
            "running")
                status_colored="${GREEN}$status${NC}"
                ;;
            "restarting")
                status_colored="${YELLOW}$status${NC}"
                ;;
            *)
                status_colored="${RED}$status${NC}"
                ;;
        esac
        
        # Color health
        local health_colored="$health"
        case "$health" in
            "healthy")
                health_colored="${GREEN}$health${NC}"
                ;;
            "starting")
                health_colored="${YELLOW}$health${NC}"
                ;;
            "unhealthy")
                health_colored="${RED}$health${NC}"
                ;;
        esac
        
        printf "  %-20s %-22s %-25s %-10s\n" "$service" "$status_colored" "$health_colored" "$uptime"
    done
    
    cd - > /dev/null
    echo ""
}

check_endpoints_health() {
    print_section "Endpoint Health"
    
    local endpoints=(
        "http://localhost/:Frontend"
        "http://localhost:8000:Casdoor"
        "http://localhost:8080/docs:API Gateway"
    )
    
    printf "  ${BOLD}%-30s %-12s %-10s${NC}\n" "ENDPOINT" "STATUS" "RESPONSE"
    echo "  ──────────────────────────────────────────────────────"
    
    for endpoint in "${endpoints[@]}"; do
        local url="${endpoint%%:*}"
        local name="${endpoint##*:}"
        
        local response=$(curl -s -o /dev/null -w "%{http_code}" --max-time 5 "$url" 2>/dev/null || echo "000")
        local status="offline"
        local status_color="${RED}"
        
        if [[ "$response" =~ ^(200|302|401)$ ]]; then
            status="online"
            status_color="${GREEN}"
        elif [[ "$response" != "000" ]]; then
            status="degraded"
            status_color="${YELLOW}"
        fi
        
        printf "  %-30s ${status_color}%-12s${NC} %-10s\n" "$name" "$status" "$response"
    done
    
    echo ""
}

check_deployment_info() {
    print_section "Deployment Information"
    
    # Check lock file
    local lock_file="/tmp/astron-agent-deploy.lock"
    if [ -f "$lock_file" ]; then
        local lock_pid=$(cat "$lock_file" 2>/dev/null || echo "unknown")
        echo -e "  ${YELLOW}Deployment Lock:${NC} Active (PID: $lock_pid)"
    else
        echo -e "  ${GREEN}Deployment Lock:${NC} None"
    fi
    
    # Get git info
    if [ -d "$REPO_DIR/.git" ]; then
        local commit=$(git -C "$REPO_DIR" rev-parse --short HEAD 2>/dev/null || echo "unknown")
        local branch=$(git -C "$REPO_DIR" rev-parse --abbrev-ref HEAD 2>/dev/null || echo "unknown")
        local last_commit_date=$(git -C "$REPO_DIR" log -1 --format=%cd --date=relative 2>/dev/null || echo "unknown")
        
        echo -e "  ${CYAN}Git Branch:${NC} $branch"
        echo -e "  ${CYAN}Git Commit:${NC} $commit"
        echo -e "  ${CYAN}Last Update:${NC} $last_commit_date"
    fi
    
    # Check backup info
    if [ -d "./backups" ]; then
        local backup_count=$(ls -1 ./backups 2>/dev/null | wc -l)
        local latest_backup=$(ls -1t ./backups 2>/dev/null | head -n1 || echo "none")
        
        echo -e "  ${CYAN}Backups Available:${NC} $backup_count"
        if [ "$latest_backup" != "none" ]; then
            echo -e "  ${CYAN}Latest Backup:${NC} $latest_backup"
        fi
    fi
    
    # Check log files
    local latest_log=$(ls -1t deployment_*.log 2>/dev/null | head -n1 || echo "none")
    if [ "$latest_log" != "none" ]; then
        echo -e "  ${CYAN}Latest Log:${NC} $latest_log"
    fi
    
    echo ""
}

check_resource_usage() {
    print_section "Resource Usage"
    
    # System resources
    local total_mem=$(free -h | awk '/^Mem:/ {print $2}')
    local used_mem=$(free -h | awk '/^Mem:/ {print $3}')
    local mem_percent=$(free | awk '/^Mem:/ {printf "%.1f", $3/$2 * 100}')
    
    local disk_total=$(df -h / | awk 'NR==2 {print $2}')
    local disk_used=$(df -h / | awk 'NR==2 {print $3}')
    local disk_percent=$(df / | awk 'NR==2 {print $5}')
    
    echo -e "  ${CYAN}Memory:${NC} $used_mem / $total_mem (${mem_percent}%)"
    echo -e "  ${CYAN}Disk:${NC} $disk_used / $disk_total ($disk_percent)"
    
    # Docker container resources
    if docker ps -q > /dev/null 2>&1; then
        echo -e "\n  ${BOLD}Container Resources:${NC}"
        
        if [ -d "$REPO_DIR/$DEPLOY_DIR" ]; then
            cd "$REPO_DIR/$DEPLOY_DIR" || return 1
            
            local containers=$(docker compose -f "$COMPOSE_FILE" ps -q 2>/dev/null)
            
            if [ -n "$containers" ]; then
                printf "  ${BOLD}%-20s %-10s %-10s${NC}\n" "CONTAINER" "CPU %" "MEMORY"
                echo "  ────────────────────────────────────────────"
                
                for container in $containers; do
                    local name=$(docker inspect --format='{{.Name}}' "$container" | sed 's/\///')
                    local stats=$(docker stats --no-stream --format "{{.CPUPerc}},{{.MemUsage}}" "$container" 2>/dev/null || echo "0.00%,0B / 0B")
                    
                    local cpu=$(echo "$stats" | cut -d',' -f1)
                    local mem=$(echo "$stats" | cut -d',' -f2 | awk '{print $1}')
                    
                    printf "  %-20s %-10s %-10s\n" "$name" "$cpu" "$mem"
                done
            fi
            
            cd - > /dev/null
        fi
    fi
    
    echo ""
}

check_recent_activity() {
    print_section "Recent Activity"
    
    # Recent deployments
    local recent_logs=$(ls -1t deployment_*.log 2>/dev/null | head -n3)
    
    if [ -n "$recent_logs" ]; then
        echo -e "  ${CYAN}Recent Deployments:${NC}"
        for log in $recent_logs; do
            local timestamp=$(echo "$log" | sed 's/deployment_\(.*\)\.log/\1/')
            local formatted=$(date -d "${timestamp:0:8} ${timestamp:9:2}:${timestamp:11:2}:${timestamp:13:2}" "+%Y-%m-%d %H:%M:%S" 2>/dev/null || echo "$timestamp")
            echo -e "    • $formatted"
        done
    fi
    
    # Docker events (last 10)
    if docker ps > /dev/null 2>&1; then
        echo -e "\n  ${CYAN}Recent Docker Events:${NC}"
        docker events --since 1h --until 0s 2>/dev/null | tail -n5 | while read line; do
            echo -e "    ${BLUE}•${NC} $(echo $line | cut -c1-80)..."
        done 2>/dev/null || echo "    No recent events"
    fi
    
    echo ""
}

check_quick_diagnostics() {
    print_section "Quick Diagnostics"
    
    local issues=()
    
    # Check if services are running
    if [ -d "$REPO_DIR/$DEPLOY_DIR" ]; then
        cd "$REPO_DIR/$DEPLOY_DIR" || return 1
        
        local running_count=$(docker compose -f "$COMPOSE_FILE" ps -q 2>/dev/null | wc -l)
        local total_count=$(docker compose -f "$COMPOSE_FILE" ps --services 2>/dev/null | wc -l)
        
        if [ "$running_count" -lt "$total_count" ]; then
            issues+=("${RED}✗${NC} Not all services are running ($running_count/$total_count)")
        else
            echo -e "  ${GREEN}✓${NC} All services running ($running_count/$total_count)"
        fi
        
        cd - > /dev/null
    fi
    
    # Check deployment lock
    if [ -f "/tmp/astron-agent-deploy.lock" ]; then
        issues+=("${YELLOW}⚠${NC} Deployment lock is active")
    fi
    
    # Check disk space
    local disk_percent=$(df / | awk 'NR==2 {print $5}' | tr -d '%')
    if [ "$disk_percent" -gt 90 ]; then
        issues+=("${RED}✗${NC} Disk space critical (${disk_percent}%)")
    elif [ "$disk_percent" -gt 80 ]; then
        issues+=("${YELLOW}⚠${NC} Disk space low (${disk_percent}%)")
    else
        echo -e "  ${GREEN}✓${NC} Disk space healthy (${disk_percent}% used)"
    fi
    
    # Check memory
    local mem_percent=$(free | awk '/^Mem:/ {printf "%.0f", $3/$2 * 100}')
    if [ "$mem_percent" -gt 90 ]; then
        issues+=("${RED}✗${NC} Memory usage critical (${mem_percent}%)")
    elif [ "$mem_percent" -gt 80 ]; then
        issues+=("${YELLOW}⚠${NC} Memory usage high (${mem_percent}%)")
    else
        echo -e "  ${GREEN}✓${NC} Memory usage healthy (${mem_percent}%)"
    fi
    
    # Display issues
    if [ ${#issues[@]} -gt 0 ]; then
        echo ""
        for issue in "${issues[@]}"; do
            echo -e "  $issue"
        done
    fi
    
    echo ""
}

################################################################################
# Main Execution
################################################################################

show_usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  --services      Show only service status"
    echo "  --health        Show only endpoint health"
    echo "  --resources     Show only resource usage"
    echo "  --deployment    Show only deployment info"
    echo "  --diagnostics   Show only quick diagnostics"
    echo "  --all           Show everything (default)"
    echo "  --help          Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0              # Show all information"
    echo "  $0 --services   # Show only services"
    echo "  $0 --health     # Show only endpoint health"
}

main() {
    local mode="${1:---all}"
    
    case "$mode" in
        --services)
            print_header "📊 SERVICE STATUS"
            check_services_status
            ;;
        --health)
            print_header "🏥 ENDPOINT HEALTH"
            check_endpoints_health
            ;;
        --resources)
            print_header "💻 RESOURCE USAGE"
            check_resource_usage
            ;;
        --deployment)
            print_header "📦 DEPLOYMENT INFO"
            check_deployment_info
            ;;
        --diagnostics)
            print_header "🔍 QUICK DIAGNOSTICS"
            check_quick_diagnostics
            ;;
        --help)
            show_usage
            exit 0
            ;;
        --all|*)
            print_header "🚀 ASTRON AGENT - SYSTEM STATUS"
            check_services_status
            check_endpoints_health
            check_resource_usage
            check_deployment_info
            check_recent_activity
            check_quick_diagnostics
            
            echo -e "${CYAN}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"
            echo -e "  ${CYAN}For more details:${NC}"
            echo -e "    ./status.sh --services      # Service details"
            echo -e "    ./status.sh --health        # Endpoint health"
            echo -e "    ./status.sh --resources     # Resource usage"
            echo -e "    ./logs.sh                   # View logs"
            echo ""
            ;;
    esac
}

# Check prerequisites
if ! command -v docker &> /dev/null; then
    echo -e "${RED}[ERROR]${NC} Docker is not installed"
    exit 1
fi

main "$@"

