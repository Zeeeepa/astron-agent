#!/bin/bash

################################################################################
# Astron Agent - Configuration Validator
# 
# Validates .env configuration files for completeness and correctness
# 
# Features:
# - Check required variables
# - Validate variable formats
# - Security validation
# - Port conflict detection
# - Generate configuration report
#
# Usage: ./validate-config.sh [path/to/.env]
################################################################################

set -eE
set -o pipefail
set -u

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'
BOLD='\033[1m'

# Configuration
ENV_FILE="${1:-docker/astronAgent/.env}"
VALIDATION_PASSED=true
ERROR_COUNT=0
WARNING_COUNT=0

################################################################################
# Utility Functions
################################################################################

log() {
    echo -e "${GREEN}[$(date +'%H:%M:%S')]${NC} $*"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $*"
    ((ERROR_COUNT++))
    VALIDATION_PASSED=false
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $*"
    ((WARNING_COUNT++))
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} ✓ $*"
}

log_info() {
    echo -e "${CYAN}[INFO]${NC} $*"
}

print_banner() {
    echo -e "${BLUE}${BOLD}"
    cat << "EOF"
╔═══════════════════════════════════════════════════════╗
║                                                       ║
║        Configuration Validator                       ║
║                                                       ║
╚═══════════════════════════════════════════════════════╝
EOF
    echo -e "${NC}\n"
}

print_separator() {
    echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}"
}

################################################################################
# Validation Functions
################################################################################

check_file_exists() {
    log_info "Checking if configuration file exists..."
    
    if [ ! -f "$ENV_FILE" ]; then
        log_error "Configuration file not found: $ENV_FILE"
        log_info "Create it from template: cp .env.example $ENV_FILE"
        return 1
    fi
    
    log_success "Configuration file found"
    return 0
}

check_required_variables() {
    log_info "Checking required variables..."
    
    local required_vars=(
        "PLATFORM_APP_ID"
        "PLATFORM_API_KEY"
        "PLATFORM_API_SECRET"
        "SPARK_API_PASSWORD"
    )
    
    local missing_vars=()
    
    for var in "${required_vars[@]}"; do
        if ! grep -q "^${var}=" "$ENV_FILE" 2>/dev/null || \
           grep -q "^${var}=$" "$ENV_FILE" 2>/dev/null || \
           grep -q "^${var}=your_.*_here" "$ENV_FILE" 2>/dev/null; then
            missing_vars+=("$var")
            log_error "Required variable missing or not set: $var"
        fi
    done
    
    if [ ${#missing_vars[@]} -eq 0 ]; then
        log_success "All required variables present"
        return 0
    else
        log_error "Missing ${#missing_vars[@]} required variable(s)"
        return 1
    fi
}

check_password_security() {
    log_info "Checking password security..."
    
    local weak_passwords=(
        "password"
        "123456"
        "admin"
        "root"
        "change_me"
    )
    
    local insecure_found=false
    
    for weak in "${weak_passwords[@]}"; do
        if grep -i "PASSWORD.*=.*$weak" "$ENV_FILE" >/dev/null 2>&1; then
            log_error "Weak/default password detected: $weak"
            insecure_found=true
        fi
    done
    
    # Check password length
    while IFS='=' read -r key value; do
        if [[ "$key" =~ PASSWORD|SECRET ]]; then
            # Remove quotes if present
            value="${value//\"/}"
            value="${value//\'/}"
            
            if [ ${#value} -lt 12 ]; then
                log_warning "$key is too short (${#value} chars, recommended 12+)"
            fi
        fi
    done < "$ENV_FILE"
    
    if [ "$insecure_found" = false ]; then
        log_success "No weak passwords detected"
        return 0
    else
        return 1
    fi
}

check_port_conflicts() {
    log_info "Checking for port conflicts..."
    
    local ports=(80 8000 3306 6379)
    local conflicts=false
    
    for port in "${ports[@]}"; do
        if command -v lsof >/dev/null 2>&1; then
            if lsof -Pi :$port -sTCP:LISTEN -t >/dev/null 2>&1; then
                log_warning "Port $port is already in use"
                conflicts=true
            fi
        elif command -v netstat >/dev/null 2>&1; then
            if netstat -tuln | grep -q ":$port "; then
                log_warning "Port $port appears to be in use"
                conflicts=true
            fi
        fi
    done
    
    if [ "$conflicts" = false ]; then
        log_success "No port conflicts detected"
    fi
    
    return 0
}

check_secret_format() {
    log_info "Checking secret format and strength..."
    
    local secret_vars=(
        "SESSION_SECRET"
        "JWT_SECRET"
    )
    
    for var in "${secret_vars[@]}"; do
        if grep -q "^${var}=" "$ENV_FILE" 2>/dev/null; then
            local value=$(grep "^${var}=" "$ENV_FILE" | cut -d'=' -f2- | tr -d '"' | tr -d "'")
            
            if [ ${#value} -lt 32 ]; then
                log_error "$var is too short (${#value} chars, need 32+)"
            else
                log_success "$var length is adequate (${#value} chars)"
            fi
        else
            log_warning "$var not found (optional but recommended)"
        fi
    done
    
    return 0
}

check_url_format() {
    log_info "Checking URL formats..."
    
    local url_vars=(
        "PLATFORM_BASE_URL"
        "PLATFORM_WEB_URL"
        "CASDOOR_ENDPOINT"
    )
    
    for var in "${url_vars[@]}"; do
        if grep -q "^${var}=" "$ENV_FILE" 2>/dev/null; then
            local value=$(grep "^${var}=" "$ENV_FILE" | cut -d'=' -f2- | tr -d '"' | tr -d "'")
            
            if [[ ! "$value" =~ ^https?:// ]]; then
                log_warning "$var should start with http:// or https://"
            else
                log_success "$var format is valid"
            fi
        fi
    done
    
    return 0
}

check_database_config() {
    log_info "Checking database configuration..."
    
    local db_vars=(
        "MYSQL_ROOT_PASSWORD"
        "MYSQL_DATABASE"
        "MYSQL_USER"
        "MYSQL_PASSWORD"
        "REDIS_PASSWORD"
    )
    
    local db_config_found=false
    
    for var in "${db_vars[@]}"; do
        if grep -q "^${var}=" "$ENV_FILE" 2>/dev/null; then
            db_config_found=true
            
            local value=$(grep "^${var}=" "$ENV_FILE" | cut -d'=' -f2- | tr -d '"' | tr -d "'")
            
            if [ -z "$value" ]; then
                log_error "$var is empty"
            fi
        fi
    done
    
    if [ "$db_config_found" = true ]; then
        log_success "Database configuration present"
    else
        log_warning "No database configuration found (may use defaults)"
    fi
    
    return 0
}

check_environment_mode() {
    log_info "Checking environment mode..."
    
    if grep -q "^NODE_ENV=" "$ENV_FILE" 2>/dev/null; then
        local env=$(grep "^NODE_ENV=" "$ENV_FILE" | cut -d'=' -f2- | tr -d '"' | tr -d "'")
        
        case "$env" in
            production)
                log_success "Environment: production"
                
                # Extra checks for production
                if grep -q "DEBUG=true" "$ENV_FILE" 2>/dev/null; then
                    log_error "DEBUG mode is enabled in production!"
                fi
                ;;
            staging)
                log_info "Environment: staging"
                ;;
            development)
                log_info "Environment: development"
                log_warning "Using development mode (not recommended for production)"
                ;;
            *)
                log_warning "Unknown environment: $env"
                ;;
        esac
    else
        log_warning "NODE_ENV not set (will default to production)"
    fi
    
    return 0
}

check_for_example_values() {
    log_info "Checking for example/placeholder values..."
    
    local example_patterns=(
        "your_.*_here"
        "example\.com"
        "changeme"
        "change_me"
        "replace_this"
    )
    
    local examples_found=false
    
    for pattern in "${example_patterns[@]}"; do
        if grep -iE "=$pattern|='$pattern'|=\"$pattern\"" "$ENV_FILE" >/dev/null 2>&1; then
            log_error "Example/placeholder value found: $pattern"
            examples_found=true
        fi
    done
    
    if [ "$examples_found" = false ]; then
        log_success "No placeholder values detected"
    fi
    
    return 0
}

generate_report() {
    print_separator
    echo ""
    echo -e "${BOLD}═══ VALIDATION REPORT ═══${NC}\n"
    
    echo -e "${CYAN}Configuration File:${NC} $ENV_FILE"
    echo -e "${CYAN}Total Variables:${NC} $(grep -c "^[A-Z_]*=" "$ENV_FILE" 2>/dev/null || echo 0)"
    echo ""
    
    if [ $ERROR_COUNT -eq 0 ] && [ $WARNING_COUNT -eq 0 ]; then
        echo -e "${GREEN}${BOLD}✓ VALIDATION PASSED${NC}"
        echo -e "${GREEN}No errors or warnings detected${NC}"
    elif [ $ERROR_COUNT -eq 0 ]; then
        echo -e "${YELLOW}${BOLD}⚠ VALIDATION PASSED WITH WARNINGS${NC}"
        echo -e "${YELLOW}Errors: $ERROR_COUNT | Warnings: $WARNING_COUNT${NC}"
    else
        echo -e "${RED}${BOLD}✗ VALIDATION FAILED${NC}"
        echo -e "${RED}Errors: $ERROR_COUNT | Warnings: $WARNING_COUNT${NC}"
    fi
    
    echo ""
    print_separator
    
    if [ $ERROR_COUNT -gt 0 ]; then
        echo -e "\n${RED}${BOLD}Action Required:${NC}"
        echo -e "1. Fix all errors in $ENV_FILE"
        echo -e "2. Re-run validation: ./validate-config.sh"
        echo -e "3. Refer to .env.example for guidance"
        return 1
    elif [ $WARNING_COUNT -gt 0 ]; then
        echo -e "\n${YELLOW}${BOLD}Recommendations:${NC}"
        echo -e "1. Review warnings and update configuration"
        echo -e "2. Warnings won't prevent deployment but should be addressed"
        return 0
    else
        echo -e "\n${GREEN}${BOLD}Ready to Deploy:${NC}"
        echo -e "Configuration is valid and ready for deployment"
        return 0
    fi
}

################################################################################
# Main Execution
################################################################################

main() {
    print_banner
    
    echo -e "${BOLD}Validating configuration: ${ENV_FILE}${NC}\n"
    print_separator
    echo ""
    
    # Run all checks
    check_file_exists || exit 1
    
    echo ""
    check_required_variables
    
    echo ""
    check_password_security
    
    echo ""
    check_secret_format
    
    echo ""
    check_url_format
    
    echo ""
    check_database_config
    
    echo ""
    check_environment_mode
    
    echo ""
    check_for_example_values
    
    echo ""
    check_port_conflicts
    
    echo ""
    
    # Generate final report
    generate_report
    local exit_code=$?
    
    exit $exit_code
}

# Show usage if help requested
if [ "${1:-}" = "--help" ] || [ "${1:-}" = "-h" ]; then
    echo "Usage: $0 [path/to/.env]"
    echo ""
    echo "Validates configuration file for completeness and security."
    echo ""
    echo "Default: docker/astronAgent/.env"
    echo ""
    echo "Examples:"
    echo "  $0                              # Validate default .env"
    echo "  $0 custom/.env                  # Validate custom file"
    echo "  $0 --help                       # Show this help"
    exit 0
fi

main

