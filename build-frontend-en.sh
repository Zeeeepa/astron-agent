#!/usr/bin/env bash

#############################################################################
# Astron Agent Frontend Builder - English Version
#############################################################################
# This script builds the console frontend with English as the default language
# Usage: ./build-frontend-en.sh [tag]
#############################################################################

set -e  # Exit on error
set -o pipefail  # Catch pipe errors

# Color output helpers
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

print_header() {
    echo -e "\n${BLUE}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${CYAN}$1${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}\n"
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

print_info() {
    echo -e "${CYAN}ℹ $1${NC}"
}

#############################################################################
# Configuration
#############################################################################

# Docker image tag (default: latest)
IMAGE_TAG="${1:-latest}"
IMAGE_NAME="astron-agent-console-frontend-en"
FULL_IMAGE_NAME="${IMAGE_NAME}:${IMAGE_TAG}"

# Build metadata
VERSION="${IMAGE_TAG}"
GIT_COMMIT=$(git rev-parse --short HEAD 2>/dev/null || echo "unknown")
BUILD_TIME=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

# Platform support
PLATFORM="linux/amd64,linux/arm64"

#############################################################################
# Pre-flight Checks
#############################################################################

print_header "🔍 Pre-flight Checks"

# Check if Docker is installed
if ! command -v docker &> /dev/null; then
    print_error "Docker is not installed"
    exit 1
fi
print_success "Docker found: $(docker --version)"

# Check if we're in the correct directory
if [ ! -f "console/frontend/Dockerfile" ]; then
    print_error "Dockerfile not found. Please run this script from the repository root."
    exit 1
fi
print_success "Repository structure validated"

# Check if i18n modification was applied
if ! grep -q "fallbackLng: 'en'" console/frontend/src/i18n/index.ts; then
    print_warning "i18n default language is not set to English"
    print_info "The frontend will still default to Chinese"
    echo ""
    read -p "Do you want to continue anyway? (y/N) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_error "Build cancelled"
        exit 1
    fi
else
    print_success "i18n configured for English default"
fi

# Check Docker BuildKit support
if [ -z "$DOCKER_BUILDKIT" ]; then
    export DOCKER_BUILDKIT=1
    print_info "Enabled Docker BuildKit for faster builds"
fi

#############################################################################
# Build Frontend
#############################################################################

print_header "🏗️  Building Frontend (English Default)"

print_info "Image name: ${FULL_IMAGE_NAME}"
print_info "Version: ${VERSION}"
print_info "Git commit: ${GIT_COMMIT}"
print_info "Build time: ${BUILD_TIME}"
print_info "Platform: ${PLATFORM}"

echo ""
print_info "Starting multi-platform build..."
echo ""

# Build the Docker image
docker build \
    --platform "${PLATFORM}" \
    --build-arg VERSION="${VERSION}" \
    --build-arg GIT_COMMIT="${GIT_COMMIT}" \
    --build-arg BUILD_TIME="${BUILD_TIME}" \
    -t "${FULL_IMAGE_NAME}" \
    -f console/frontend/Dockerfile \
    . || {
        print_error "Docker build failed"
        exit 1
    }

print_success "Frontend image built successfully"

#############################################################################
# Verify Build
#############################################################################

print_header "✅ Verifying Build"

# Check if image exists
if docker image inspect "${FULL_IMAGE_NAME}" &> /dev/null; then
    IMAGE_SIZE=$(docker image inspect "${FULL_IMAGE_NAME}" --format='{{.Size}}' | awk '{print $1/1024/1024 " MB"}')
    print_success "Image exists: ${FULL_IMAGE_NAME}"
    print_info "Image size: ${IMAGE_SIZE}"
else
    print_error "Image verification failed"
    exit 1
fi

# Display image labels
print_info "Image metadata:"
docker image inspect "${FULL_IMAGE_NAME}" --format='  Version: {{index .Config.Labels "org.opencontainers.image.version"}}'
docker image inspect "${FULL_IMAGE_NAME}" --format='  Revision: {{index .Config.Labels "org.opencontainers.image.revision"}}'
docker image inspect "${FULL_IMAGE_NAME}" --format='  Created: {{index .Config.Labels "org.opencontainers.image.created"}}'

#############################################################################
# Tag Management
#############################################################################

print_header "🏷️  Tag Management"

# Create additional tags if building latest
if [ "${IMAGE_TAG}" == "latest" ]; then
    print_info "Creating version-specific tags..."
    
    # Tag with git commit
    docker tag "${FULL_IMAGE_NAME}" "${IMAGE_NAME}:${GIT_COMMIT}"
    print_success "Tagged as ${IMAGE_NAME}:${GIT_COMMIT}"
    
    # Tag with date
    DATE_TAG=$(date +%Y%m%d)
    docker tag "${FULL_IMAGE_NAME}" "${IMAGE_NAME}:${DATE_TAG}"
    print_success "Tagged as ${IMAGE_NAME}:${DATE_TAG}"
fi

#############################################################################
# Next Steps
#############################################################################

print_header "📋 Next Steps"

cat <<EOF
${GREEN}✓ Frontend build completed successfully!${NC}

${CYAN}Available Images:${NC}
  - ${FULL_IMAGE_NAME}
$([ "${IMAGE_TAG}" == "latest" ] && echo "  - ${IMAGE_NAME}:${GIT_COMMIT}")
$([ "${IMAGE_TAG}" == "latest" ] && echo "  - ${IMAGE_NAME}:${DATE_TAG}")

${CYAN}To test the image locally:${NC}
  ${YELLOW}docker run -p 1881:1881 ${FULL_IMAGE_NAME}${NC}
  Then open: http://localhost:1881

${CYAN}To push to a registry:${NC}
  ${YELLOW}docker tag ${FULL_IMAGE_NAME} your-registry.com/${IMAGE_NAME}:${IMAGE_TAG}${NC}
  ${YELLOW}docker push your-registry.com/${IMAGE_NAME}:${IMAGE_TAG}${NC}

${CYAN}To update docker-compose.yaml:${NC}
  Replace the console-frontend image reference with:
  ${YELLOW}image: ${FULL_IMAGE_NAME}${NC}

${CYAN}To verify English default:${NC}
  1. Start the container
  2. Open in browser (incognito/private mode)
  3. Clear localStorage and refresh
  4. UI should default to English

${GREEN}════════════════════════════════════════════════════════════${NC}
${GREEN}Build completed at: $(date)${NC}
${GREEN}════════════════════════════════════════════════════════════${NC}

EOF

