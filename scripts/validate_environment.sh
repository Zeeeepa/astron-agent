#!/bin/bash

# Environment Validation Script for Astron-Agent RPA Integration
# This script validates all prerequisites for the comprehensive 20-step upgrade

set -e

echo "🚀 Astron-Agent Environment Validation"
echo "======================================"
echo ""

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Validation results
VALIDATION_PASSED=true

validate_command() {
    local cmd=$1
    local name=$2
    local required_version=$3
    
    if command -v $cmd &> /dev/null; then
        local version=$($cmd --version 2>&1 | head -n1)
        echo -e "${GREEN}✅ $name: $version${NC}"
        return 0
    else
        echo -e "${RED}❌ $name: Not installed${NC}"
        VALIDATION_PASSED=false
        return 1
    fi
}

validate_python_package() {
    local package=$1
    local name=$2
    
    if python3 -c "import $package" 2>/dev/null; then
        local version=$(python3 -c "import $package; print($package.__version__)" 2>/dev/null || echo "unknown")
        echo -e "${GREEN}✅ $name: $version${NC}"
        return 0
    else
        echo -e "${YELLOW}⚠️  $name: Not installed (will be installed during setup)${NC}"
        return 1
    fi
}

echo "🔍 System Requirements Validation"
echo "--------------------------------"

# Basic system info
echo "System: $(uname -s) $(uname -r)"
echo "Architecture: $(uname -m)"
echo "Memory: $(free -h | grep '^Mem:' | awk '{print $2}')"
echo "Disk Space: $(df -h / | tail -1 | awk '{print $4}') available"
echo ""

echo "🛠️  Core Tools Validation"
echo "-------------------------"

# Validate core tools
validate_command "docker" "Docker"
validate_command "docker-compose" "Docker Compose" || validate_command "docker compose" "Docker Compose"
validate_command "python3" "Python 3"
validate_command "pip3" "pip3"
validate_command "git" "Git"
validate_command "curl" "curl"
validate_command "node" "Node.js" || echo -e "${YELLOW}⚠️  Node.js: Not required but recommended${NC}"

echo ""
echo "🐍 Python Environment Validation"
echo "--------------------------------"

# Check Python version
PYTHON_VERSION=$(python3 -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}')")
if (( $(echo "$PYTHON_VERSION >= 3.8" | bc -l) )); then
    echo -e "${GREEN}✅ Python Version: $PYTHON_VERSION (>= 3.8 required)${NC}"
else
    echo -e "${RED}❌ Python Version: $PYTHON_VERSION (>= 3.8 required)${NC}"
    VALIDATION_PASSED=false
fi

# Validate Python packages (optional for now)
echo ""
echo "📦 Python Packages (Optional)"
echo "-----------------------------"
validate_python_package "fastapi" "FastAPI"
validate_python_package "uvicorn" "Uvicorn"
validate_python_package "pytest" "pytest"
validate_python_package "requests" "requests"

echo ""
echo "🐳 Docker Environment Validation"
echo "--------------------------------"

# Test Docker functionality
if docker info &> /dev/null; then
    echo -e "${GREEN}✅ Docker daemon: Running${NC}"
    
    # Test Docker functionality
    if docker run --rm hello-world &> /dev/null; then
        echo -e "${GREEN}✅ Docker functionality: Working${NC}"
    else
        echo -e "${RED}❌ Docker functionality: Failed${NC}"
        VALIDATION_PASSED=false
    fi
else
    echo -e "${RED}❌ Docker daemon: Not running${NC}"
    VALIDATION_PASSED=false
fi

echo ""
echo "🌐 Network Connectivity Validation"
echo "----------------------------------"

# Test network connectivity
if curl -s --connect-timeout 5 https://httpbin.org/get > /dev/null; then
    echo -e "${GREEN}✅ Internet connectivity: OK${NC}"
else
    echo -e "${RED}❌ Internet connectivity: Failed${NC}"
    VALIDATION_PASSED=false
fi

# Test Docker Hub connectivity
if curl -s --connect-timeout 5 https://registry-1.docker.io/v2/ > /dev/null; then
    echo -e "${GREEN}✅ Docker Hub connectivity: OK${NC}"
else
    echo -e "${YELLOW}⚠️  Docker Hub connectivity: Limited (may affect image pulls)${NC}"
fi

echo ""
echo "📁 Repository Structure Validation"
echo "----------------------------------"

# Check for key directories and files
REQUIRED_DIRS=("core" "docker" "tests" "scripts")
REQUIRED_FILES=("README.md" "requirements-test.txt")

for dir in "${REQUIRED_DIRS[@]}"; do
    if [ -d "$dir" ]; then
        echo -e "${GREEN}✅ Directory: $dir${NC}"
    else
        echo -e "${RED}❌ Directory: $dir (missing)${NC}"
        VALIDATION_PASSED=false
    fi
done

for file in "${REQUIRED_FILES[@]}"; do
    if [ -f "$file" ]; then
        echo -e "${GREEN}✅ File: $file${NC}"
    else
        echo -e "${RED}❌ File: $file (missing)${NC}"
        VALIDATION_PASSED=false
    fi
done

echo ""
echo "📊 Resource Requirements Check"
echo "-----------------------------"

# Check available resources
AVAILABLE_MEMORY=$(free -m | grep '^Mem:' | awk '{print $7}')
AVAILABLE_DISK=$(df / | tail -1 | awk '{print $4}')

if [ "$AVAILABLE_MEMORY" -gt 2048 ]; then
    echo -e "${GREEN}✅ Available Memory: ${AVAILABLE_MEMORY}MB (>2GB recommended)${NC}"
else
    echo -e "${YELLOW}⚠️  Available Memory: ${AVAILABLE_MEMORY}MB (2GB+ recommended)${NC}"
fi

if [ "$AVAILABLE_DISK" -gt 10485760 ]; then  # 10GB in KB
    echo -e "${GREEN}✅ Available Disk: $(($AVAILABLE_DISK/1024/1024))GB (>10GB recommended)${NC}"
else
    echo -e "${YELLOW}⚠️  Available Disk: $(($AVAILABLE_DISK/1024/1024))GB (10GB+ recommended)${NC}"
fi

echo ""
echo "🎯 Validation Summary"
echo "===================="

if [ "$VALIDATION_PASSED" = true ]; then
    echo -e "${GREEN}🎉 Environment validation PASSED!${NC}"
    echo -e "${GREEN}✅ All prerequisites are met for the 20-step upgrade process.${NC}"
    exit 0
else
    echo -e "${RED}❌ Environment validation FAILED!${NC}"
    echo -e "${RED}Please resolve the issues above before proceeding.${NC}"
    exit 1
fi
