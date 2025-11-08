#!/bin/bash

################################################################################
# Astron Agent - Log Analyzer
# 
# Intelligent log viewing and analysis tool
# 
# Features:
# - View service logs with filtering
# - Search for patterns
# - Error highlighting
# - Follow logs in real-time
# - Export log snippets
# - Summary of errors/warnings
#
# Usage: ./logs.sh [SERVICE] [OPTIONS]
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
    echo -e "${CYAN}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${CYAN}${BOLD}  $1${NC}"
    echo -e "${CYAN}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"
}

highlight_errors() {
    sed -E \
        -e "s/(ERROR|FATAL|CRITICAL|error|fatal|critical)/${RED}\1${NC}/g" \
        -e "s/(WARNING|WARN|warning|warn)/${YELLOW}\1${NC}/g" \
        -e "s/(SUCCESS|INFO|info|success)/${GREEN}\1${NC}/g" \
        -e "s/(DEBUG|debug)/${BLUE}\1${NC}/g"
}

################################################################################
# Log Functions
################################################################################

list_services() {
    if [ ! -d "$REPO_DIR/$DEPLOY_DIR" ]; then
        echo -e "${RED}Deployment directory not found${NC}"
        exit 1
    fi
    
    cd "$REPO_DIR/$DEPLOY_DIR" || exit 1
    
    echo -e "${CYAN}${BOLD}Available Services:${NC}\n"
    
    local services=$(docker compose -f "$COMPOSE_FILE" ps --services 2>/dev/null)
    
    if [ -z "$services" ]; then
        echo -e "${YELLOW}No services found${NC}"
        cd - > /dev/null
        exit 1
    fi
    
    for service in $services; do
        local container_id=$(docker compose -f "$COMPOSE_FILE" ps -q "$service" 2>/dev/null)
        local status="stopped"
        
        if [ -n "$container_id" ]; then
            status=$(docker inspect --format='{{.State.Status}}' "$container_id" 2>/dev/null || echo "unknown")
        fi
        
        case "$status" in
            "running")
                echo -e "  ${GREEN}✓${NC} $service (running)"
                ;;
            "restarting")
                echo -e "  ${YELLOW}◐${NC} $service (restarting)"
                ;;
            *)
                echo -e "  ${RED}✗${NC} $service ($status)"
                ;;
        esac
    done
    
    cd - > /dev/null
    echo ""
}

view_service_logs() {
    local service="$1"
    local lines="${2:-50}"
    local follow="${3:-false}"
    local filter="${4:-}"
    
    if [ ! -d "$REPO_DIR/$DEPLOY_DIR" ]; then
        echo -e "${RED}Deployment directory not found${NC}"
        exit 1
    fi
    
    cd "$REPO_DIR/$DEPLOY_DIR" || exit 1
    
    # Check if service exists
    if ! docker compose -f "$COMPOSE_FILE" ps --services 2>/dev/null | grep -q "^${service}$"; then
        echo -e "${RED}Service '$service' not found${NC}"
        echo ""
        list_services
        cd - > /dev/null
        exit 1
    fi
    
    print_header "📋 LOGS: $service"
    
    if [ "$follow" = "true" ]; then
        echo -e "${CYAN}Following logs (Ctrl+C to stop)...${NC}\n"
        
        if [ -n "$filter" ]; then
            docker compose -f "$COMPOSE_FILE" logs -f --tail="$lines" "$service" 2>&1 | grep -i "$filter" | highlight_errors
        else
            docker compose -f "$COMPOSE_FILE" logs -f --tail="$lines" "$service" 2>&1 | highlight_errors
        fi
    else
        if [ -n "$filter" ]; then
            docker compose -f "$COMPOSE_FILE" logs --tail="$lines" "$service" 2>&1 | grep -i "$filter" | highlight_errors
        else
            docker compose -f "$COMPOSE_FILE" logs --tail="$lines" "$service" 2>&1 | highlight_errors
        fi
    fi
    
    cd - > /dev/null
}

view_all_logs() {
    local lines="${1:-50}"
    local follow="${2:-false}"
    
    if [ ! -d "$REPO_DIR/$DEPLOY_DIR" ]; then
        echo -e "${RED}Deployment directory not found${NC}"
        exit 1
    fi
    
    cd "$REPO_DIR/$DEPLOY_DIR" || exit 1
    
    print_header "📋 ALL SERVICE LOGS"
    
    if [ "$follow" = "true" ]; then
        echo -e "${CYAN}Following logs (Ctrl+C to stop)...${NC}\n"
        docker compose -f "$COMPOSE_FILE" logs -f --tail="$lines" 2>&1 | highlight_errors
    else
        docker compose -f "$COMPOSE_FILE" logs --tail="$lines" 2>&1 | highlight_errors
    fi
    
    cd - > /dev/null
}

view_deployment_logs() {
    print_header "📋 DEPLOYMENT LOGS"
    
    local logs=$(ls -1t deployment_*.log 2>/dev/null)
    
    if [ -z "$logs" ]; then
        echo -e "${YELLOW}No deployment logs found${NC}"
        exit 0
    fi
    
    echo -e "${CYAN}${BOLD}Available Deployment Logs:${NC}\n"
    
    local count=1
    for log in $logs; do
        local timestamp=$(echo "$log" | sed 's/deployment_\(.*\)\.log/\1/')
        local formatted=$(date -d "${timestamp:0:8} ${timestamp:9:2}:${timestamp:11:2}:${timestamp:13:2}" "+%Y-%m-%d %H:%M:%S" 2>/dev/null || echo "$timestamp")
        local size=$(du -h "$log" | cut -f1)
        
        echo -e "  ${BOLD}$count.${NC} $formatted ($size) - $log"
        count=$((count + 1))
    done
    
    echo ""
    read -p "$(echo -e ${CYAN}View which log? [1-$((count-1)) or filename]: ${NC})" choice
    
    local selected_log=""
    if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -lt "$count" ]; then
        selected_log=$(echo "$logs" | sed -n "${choice}p")
    elif [ -f "$choice" ]; then
        selected_log="$choice"
    else
        echo -e "${RED}Invalid selection${NC}"
        exit 1
    fi
    
    echo -e "\n${CYAN}${BOLD}Viewing: $selected_log${NC}\n"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"
    
    cat "$selected_log" | highlight_errors | less -R
}

analyze_errors() {
    local service="${1:-all}"
    
    print_header "🔍 ERROR ANALYSIS"
    
    if [ ! -d "$REPO_DIR/$DEPLOY_DIR" ]; then
        echo -e "${RED}Deployment directory not found${NC}"
        exit 1
    fi
    
    cd "$REPO_DIR/$DEPLOY_DIR" || exit 1
    
    echo -e "${CYAN}Analyzing last 200 lines...${NC}\n"
    
    local logs=""
    if [ "$service" = "all" ]; then
        logs=$(docker compose -f "$COMPOSE_FILE" logs --tail=200 2>&1)
    else
        logs=$(docker compose -f "$COMPOSE_FILE" logs --tail=200 "$service" 2>&1)
    fi
    
    # Count errors
    local error_count=$(echo "$logs" | grep -iE "(ERROR|FATAL|CRITICAL)" | wc -l)
    local warning_count=$(echo "$logs" | grep -iE "(WARNING|WARN)" | wc -l)
    
    echo -e "${RED}Errors:${NC} $error_count"
    echo -e "${YELLOW}Warnings:${NC} $warning_count"
    
    if [ "$error_count" -gt 0 ]; then
        echo -e "\n${RED}${BOLD}Recent Errors:${NC}\n"
        echo "$logs" | grep -iE "(ERROR|FATAL|CRITICAL)" | tail -n10 | highlight_errors
    fi
    
    if [ "$warning_count" -gt 0 ]; then
        echo -e "\n${YELLOW}${BOLD}Recent Warnings:${NC}\n"
        echo "$logs" | grep -iE "(WARNING|WARN)" | tail -n10 | highlight_errors
    fi
    
    if [ "$error_count" -eq 0 ] && [ "$warning_count" -eq 0 ]; then
        echo -e "\n${GREEN}✓ No errors or warnings found${NC}"
    fi
    
    cd - > /dev/null
    echo ""
}

search_logs() {
    local pattern="$1"
    local service="${2:-all}"
    
    print_header "🔍 SEARCH RESULTS: '$pattern'"
    
    if [ ! -d "$REPO_DIR/$DEPLOY_DIR" ]; then
        echo -e "${RED}Deployment directory not found${NC}"
        exit 1
    fi
    
    cd "$REPO_DIR/$DEPLOY_DIR" || exit 1
    
    local logs=""
    if [ "$service" = "all" ]; then
        logs=$(docker compose -f "$COMPOSE_FILE" logs --tail=500 2>&1)
    else
        logs=$(docker compose -f "$COMPOSE_FILE" logs --tail=500 "$service" 2>&1)
    fi
    
    local matches=$(echo "$logs" | grep -i "$pattern")
    local count=$(echo "$matches" | grep -c "." || echo "0")
    
    echo -e "${CYAN}Found $count matches${NC}\n"
    
    if [ "$count" -gt 0 ]; then
        echo "$matches" | highlight_errors
    else
        echo -e "${YELLOW}No matches found${NC}"
    fi
    
    cd - > /dev/null
    echo ""
}

export_logs() {
    local service="${1:-all}"
    local output_file="logs_export_$(date +%Y%m%d_%H%M%S).txt"
    
    print_header "📤 EXPORT LOGS"
    
    if [ ! -d "$REPO_DIR/$DEPLOY_DIR" ]; then
        echo -e "${RED}Deployment directory not found${NC}"
        exit 1
    fi
    
    cd "$REPO_DIR/$DEPLOY_DIR" || exit 1
    
    echo -e "${CYAN}Exporting logs to: $output_file${NC}\n"
    
    {
        echo "======================================"
        echo "Astron Agent - Log Export"
        echo "Date: $(date)"
        echo "Service: $service"
        echo "======================================"
        echo ""
        
        if [ "$service" = "all" ]; then
            docker compose -f "$COMPOSE_FILE" logs --tail=1000 2>&1
        else
            docker compose -f "$COMPOSE_FILE" logs --tail=1000 "$service" 2>&1
        fi
    } > "$output_file"
    
    local size=$(du -h "$output_file" | cut -f1)
    
    echo -e "${GREEN}✓ Logs exported successfully${NC}"
    echo -e "  File: $output_file"
    echo -e "  Size: $size"
    
    cd - > /dev/null
    echo ""
}

################################################################################
# Main Execution
################################################################################

show_usage() {
    cat << EOF
Usage: $0 [SERVICE] [OPTIONS]

View and analyze service logs with intelligent filtering and highlighting.

Commands:
  $0                          # List available services
  $0 <service>                # View last 50 lines of service logs
  $0 <service> -f             # Follow service logs in real-time
  $0 <service> -n <lines>     # View last N lines
  $0 <service> --search <pattern>  # Search for pattern
  $0 --all                    # View all service logs
  $0 --all -f                 # Follow all service logs
  $0 --deployment             # View deployment logs
  $0 --errors [service]       # Analyze errors and warnings
  $0 --export [service]       # Export logs to file

Options:
  -f, --follow                Follow logs in real-time (Ctrl+C to stop)
  -n, --lines <number>        Number of lines to show (default: 50)
  --search <pattern>          Search for pattern (case-insensitive)
  --errors                    Show error analysis
  --deployment                View deployment logs
  --export                    Export logs to file
  --all                       View all services
  --help                      Show this help message

Examples:
  $0                                    # List services
  $0 nginx                              # View nginx logs
  $0 nginx -f                           # Follow nginx logs
  $0 nginx -n 100                       # Last 100 lines
  $0 nginx --search "error"             # Search for "error"
  $0 --all                              # All service logs
  $0 --errors                           # Error analysis (all services)
  $0 --errors nginx                     # Error analysis (nginx only)
  $0 --deployment                       # View deployment logs
  $0 --export                           # Export all logs
  $0 --export nginx                     # Export nginx logs

EOF
}

main() {
    local service=""
    local lines=50
    local follow=false
    local filter=""
    local mode="view"
    
    # Parse arguments
    while [ $# -gt 0 ]; do
        case "$1" in
            --help|-h)
                show_usage
                exit 0
                ;;
            --all)
                service="all"
                shift
                ;;
            --deployment)
                view_deployment_logs
                exit 0
                ;;
            --errors)
                mode="errors"
                shift
                if [ $# -gt 0 ] && [[ ! "$1" =~ ^- ]]; then
                    service="$1"
                    shift
                else
                    service="all"
                fi
                ;;
            --export)
                mode="export"
                shift
                if [ $# -gt 0 ] && [[ ! "$1" =~ ^- ]]; then
                    service="$1"
                    shift
                else
                    service="all"
                fi
                ;;
            --search)
                shift
                if [ $# -eq 0 ]; then
                    echo -e "${RED}Error: --search requires a pattern${NC}"
                    exit 1
                fi
                filter="$1"
                mode="search"
                shift
                ;;
            -f|--follow)
                follow=true
                shift
                ;;
            -n|--lines)
                shift
                if [ $# -eq 0 ]; then
                    echo -e "${RED}Error: --lines requires a number${NC}"
                    exit 1
                fi
                lines="$1"
                shift
                ;;
            -*)
                echo -e "${RED}Unknown option: $1${NC}"
                show_usage
                exit 1
                ;;
            *)
                service="$1"
                shift
                ;;
        esac
    done
    
    # Execute based on mode
    case "$mode" in
        errors)
            analyze_errors "$service"
            ;;
        export)
            export_logs "$service"
            ;;
        search)
            if [ -z "$filter" ]; then
                echo -e "${RED}Error: No search pattern provided${NC}"
                exit 1
            fi
            search_logs "$filter" "$service"
            ;;
        view)
            if [ -z "$service" ]; then
                list_services
            elif [ "$service" = "all" ]; then
                view_all_logs "$lines" "$follow"
            else
                view_service_logs "$service" "$lines" "$follow" "$filter"
            fi
            ;;
    esac
}

# Check prerequisites
if ! command -v docker &> /dev/null; then
    echo -e "${RED}[ERROR]${NC} Docker is not installed"
    exit 1
fi

main "$@"

