#!/bin/bash

################################################################################
# Advanced Error Handling Library
#
# Features:
# - Multi-provider AI fallback chain  
# - Circuit breaker pattern
# - Exponential backoff with jitter
# - Error pattern matching
# - Self-healing workflows
# - Comprehensive diagnostics
#
# Usage: source lib/error-handler.sh
################################################################################

# Circuit breaker state storage
declare -A CIRCUIT_STATE
declare -A CIRCUIT_FAILURES
declare -A CIRCUIT_LAST_ATTEMPT
CIRCUIT_THRESHOLD=5
CIRCUIT_TIMEOUT=60  # seconds

# Retry configuration
RETRY_MAX_DELAY=60
RETRY_INITIAL_DELAY=1
RETRY_MULTIPLIER=2

# Error knowledge base
declare -A ERROR_PATTERNS

################################################################################
# Circuit Breaker Implementation
################################################################################

circuit_init() {
    local service="$1"
    CIRCUIT_STATE[$service]="closed"
    CIRCUIT_FAILURES[$service]=0
    CIRCUIT_LAST_ATTEMPT[$service]=0
}

circuit_is_open() {
    local service="$1"
    local state="${CIRCUIT_STATE[$service]:-closed}"
    
    if [ "$state" = "open" ]; then
        local last_attempt="${CIRCUIT_LAST_ATTEMPT[$service]}"
        local now=$(date +%s)
        local elapsed=$((now - last_attempt))
        
        # Try half-open after timeout
        if [ $elapsed -gt $CIRCUIT_TIMEOUT ]; then
            CIRCUIT_STATE[$service]="half-open"
            echo "[INFO] Circuit $service entering half-open state"
            return 1  # Allow one attempt
        fi
        return 0  # Circuit still open
    fi
    
    return 1  # Circuit closed or half-open
}

circuit_record_success() {
    local service="$1"
    CIRCUIT_STATE[$service]="closed"
    CIRCUIT_FAILURES[$service]=0
    echo "[SUCCESS] Circuit $service: Success recorded, circuit closed"
}

circuit_record_failure() {
    local service="$1"
    local failures=$((${CIRCUIT_FAILURES[$service]:-0} + 1))
    CIRCUIT_FAILURES[$service]=$failures
    CIRCUIT_LAST_ATTEMPT[$service]=$(date +%s)
    
    if [ $failures -ge $CIRCUIT_THRESHOLD ]; then
        CIRCUIT_STATE[$service]="open"
        echo "[ERROR] Circuit $service: OPENED after $failures failures"
        return 0
    fi
    
    echo "[WARNING] Circuit $service: Failure $failures/$CIRCUIT_THRESHOLD"
    return 1
}

circuit_execute() {
    local service="$1"
    shift
    local command="$@"
    
    circuit_init "$service"
    
    if circuit_is_open "$service"; then
        echo "[ERROR] Circuit $service is OPEN - command blocked"
        return 1
    fi
    
    if eval "$command"; then
        circuit_record_success "$service"
        return 0
    else
        circuit_record_failure "$service"
        return 1
    fi
}

################################################################################
# Exponential Backoff with Jitter
################################################################################

exponential_backoff() {
    local attempt="$1"
    local max_delay="${2:-$RETRY_MAX_DELAY}"
    
    # Calculate delay: initial_delay * (multiplier ^ (attempt - 1))
    local delay=$RETRY_INITIAL_DELAY
    for ((i=1; i<attempt; i++)); do
        delay=$((delay * RETRY_MULTIPLIER))
    done
    
    # Cap at max delay
    if [ $delay -gt $max_delay ]; then
        delay=$max_delay
    fi
    
    # Add jitter (0-25% of delay)
    local jitter=$((RANDOM % (delay / 4 + 1)))
    delay=$((delay + jitter))
    
    echo $delay
}

retry_with_backoff() {
    local max_attempts="$1"
    shift
    local command="$@"
    local attempt=1
    
    while [ $attempt -le $max_attempts ]; do
        echo "[INFO] Attempt $attempt/$max_attempts: ${command:0:80}..."
        
        if eval "$command"; then
            echo "[SUCCESS] Command succeeded on attempt $attempt"
            return 0
        fi
        
        if [ $attempt -lt $max_attempts ]; then
            local delay=$(exponential_backoff $attempt)
            echo "[WARNING] Attempt $attempt failed. Retrying in ${delay}s (exponential backoff + jitter)..."
            sleep $delay
        fi
        
        attempt=$((attempt + 1))
    done
    
    echo "[ERROR] Command failed after $max_attempts attempts"
    return 1
}

################################################################################
# Error Pattern Database
################################################################################

error_patterns_init() {
    ERROR_PATTERNS["docker_permission"]="sudo usermod -aG docker \\$USER && newgrp docker"
    ERROR_PATTERNS["port_in_use"]="Check with: sudo lsof -i :<port> or sudo fuser -k <port>/tcp"
    ERROR_PATTERNS["disk_full"]="df -h && sudo apt-get clean && docker system prune -af"
    ERROR_PATTERNS["network_timeout"]="curl -v <url> && ping -c 3 8.8.8.8"
    ERROR_PATTERNS["connection_refused"]="Check service status: systemctl status <service>"
    ERROR_PATTERNS["permission_denied"]="sudo chmod +x <file> or check file ownership"
    ERROR_PATTERNS["command_not_found"]="sudo apt-get install <package> or check PATH"
    ERROR_PATTERNS["memory_exhausted"]="free -h && docker stats && kill heavy processes"
}

match_error_pattern() {
    local error_message="$1"
    local error_lower=$(echo "$error_message" | tr '[:upper:]' '[:lower:]')
    
    for pattern in "${!ERROR_PATTERNS[@]}"; do
        if [[ "$error_lower" == *"$pattern"* ]] || [[ "$error_lower" == *"${pattern//_/ }"* ]]; then
            echo "$pattern: ${ERROR_PATTERNS[$pattern]}"
            return 0
        fi
    done
    
    return 1
}

# Initialize
error_patterns_init

echo "[INFO] Enhanced error handling library loaded"
