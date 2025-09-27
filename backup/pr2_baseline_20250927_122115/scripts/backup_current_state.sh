#!/bin/bash

# Backup Current State Script for Astron-Agent RPA Integration
# Creates comprehensive backup of current PR #2 implementation

set -e

echo "🔄 Astron-Agent State Backup"
echo "============================"
echo ""

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Backup configuration
BACKUP_DIR="backup"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
BACKUP_NAME="pr2_baseline_${TIMESTAMP}"
BACKUP_PATH="${BACKUP_DIR}/${BACKUP_NAME}"

echo "📦 Backup Configuration"
echo "----------------------"
echo "Backup Directory: ${BACKUP_PATH}"
echo "Timestamp: ${TIMESTAMP}"
echo "Current Branch: $(git branch --show-current)"
echo "Current Commit: $(git rev-parse HEAD)"
echo ""

# Create backup directory
mkdir -p "${BACKUP_PATH}"

echo "🗂️  Creating file system backup..."
echo "--------------------------------"

# Backup key directories and files
BACKUP_ITEMS=(
    "core/"
    "docker/"
    "tests/"
    "scripts/"
    "docs/"
    "requirements-test.txt"
    "README.md"
    ".env.example"
    "Makefile"
)

for item in "${BACKUP_ITEMS[@]}"; do
    if [ -e "$item" ]; then
        echo -e "${GREEN}✅ Backing up: $item${NC}"
        cp -r "$item" "${BACKUP_PATH}/"
    else
        echo -e "${YELLOW}⚠️  Not found: $item${NC}"
    fi
done

echo ""
echo "📊 Creating repository metadata backup..."
echo "---------------------------------------"

# Create metadata file
cat > "${BACKUP_PATH}/backup_metadata.json" << EOF
{
    "backup_timestamp": "${TIMESTAMP}",
    "git_branch": "$(git branch --show-current)",
    "git_commit": "$(git rev-parse HEAD)",
    "git_commit_message": "$(git log -1 --pretty=format:'%s')",
    "git_author": "$(git log -1 --pretty=format:'%an <%ae>')",
    "git_date": "$(git log -1 --pretty=format:'%ai')",
    "repository_stats": {
        "total_files": $(find . -type f -name '*.py' -o -name '*.yml' -o -name '*.yaml' -o -name '*.md' -o -name '*.sh' -o -name '*.txt' | grep -v '.git' | wc -l),
        "python_files": $(find . -type f -name '*.py' | grep -v '.git' | wc -l),
        "test_files": $(find . -type f -path '*/test*' -name '*.py' | wc -l),
        "lines_of_code": $(find . -type f -name '*.py' | grep -v '.git' | xargs wc -l 2>/dev/null | tail -1 | awk '{print $1}' || echo 0)
    },
    "backup_contents": [
$(for item in "${BACKUP_ITEMS[@]}"; do
    if [ -e "$item" ]; then
        echo "        \"$item\","
    fi
done | sed '$ s/,$//')
    ]
}
EOF

echo -e "${GREEN}✅ Metadata backup created${NC}"

# Create git patch backup
echo ""
echo "🔧 Creating git state backup..."
echo "------------------------------"

# Save current git status
git status > "${BACKUP_PATH}/git_status.txt"
echo -e "${GREEN}✅ Git status saved${NC}"

# Save git diff (if any uncommitted changes)
if ! git diff --quiet; then
    git diff > "${BACKUP_PATH}/git_diff_unstaged.patch"
    echo -e "${GREEN}✅ Unstaged changes saved${NC}"
else
    echo -e "${BLUE}ℹ️  No unstaged changes${NC}"
fi

# Save staged diff (if any staged changes)
if ! git diff --cached --quiet; then
    git diff --cached > "${BACKUP_PATH}/git_diff_staged.patch"
    echo -e "${GREEN}✅ Staged changes saved${NC}"
else
    echo -e "${BLUE}ℹ️  No staged changes${NC}"
fi

# Save recent commit history
git log --oneline -10 > "${BACKUP_PATH}/git_recent_commits.txt"
echo -e "${GREEN}✅ Recent commits saved${NC}"

echo ""
echo "📋 Creating inventory..."
echo "----------------------"

# Create detailed inventory
cat > "${BACKUP_PATH}/inventory.md" << EOF
# Backup Inventory: ${BACKUP_NAME}

## Backup Information
- **Timestamp**: ${TIMESTAMP}
- **Git Branch**: $(git branch --show-current)
- **Git Commit**: $(git rev-parse HEAD)
- **Backup Path**: ${BACKUP_PATH}

## Repository Statistics
- **Total Files**: $(find . -type f -name '*.py' -o -name '*.yml' -o -name '*.yaml' -o -name '*.md' -o -name '*.sh' -o -name '*.txt' | grep -v '.git' | wc -l)
- **Python Files**: $(find . -type f -name '*.py' | grep -v '.git' | wc -l)
- **Test Files**: $(find . -type f -path '*/test*' -name '*.py' | wc -l)
- **Lines of Code**: $(find . -type f -name '*.py' | grep -v '.git' | xargs wc -l 2>/dev/null | tail -1 | awk '{print $1}' || echo 0)

## Backed Up Components

### Core Application
- \`core/\` - Main application code
- \`requirements-test.txt\` - Testing dependencies

### Docker Infrastructure
- \`docker/\` - Docker configuration and compose files

### Testing Infrastructure
- \`tests/\` - Comprehensive test suite
  - Integration tests
  - Playwright UI tests
  - Performance tests

### Deployment & Scripts
- \`scripts/\` - Deployment and utility scripts
  - \`deploy_rpa_integration.sh\` - Main deployment script
  - \`validate_environment.sh\` - Environment validation

### Documentation
- \`docs/\` - Project documentation
- \`README.md\` - Main project documentation

### Configuration
- \`.env.example\` - Environment configuration template
- \`Makefile\` - Build and deployment automation

## Git State
- \`git_status.txt\` - Current git status
- \`git_recent_commits.txt\` - Recent commit history
- \`git_diff_*.patch\` - Any uncommitted changes

## Restoration Instructions

To restore this backup:

1. **Stop current work**:
   \`\`\`bash
   git stash  # Save any current work
   \`\`\`

2. **Restore files**:
   \`\`\`bash
   ./scripts/restore_baseline.sh ${BACKUP_NAME}
   \`\`\`

3. **Verify restoration**:
   \`\`\`bash
   git status
   ./scripts/validate_environment.sh
   \`\`\`

## Backup Verification

This backup contains all critical components needed to restore the PR #2 baseline state.
EOF

echo -e "${GREEN}✅ Inventory created${NC}"

echo ""
echo "🔍 Backup verification..."
echo "------------------------"

# Verify backup integrity
BACKUP_SIZE=$(du -sh "${BACKUP_PATH}" | cut -f1)
BACKUP_FILES=$(find "${BACKUP_PATH}" -type f | wc -l)

echo "Backup Size: ${BACKUP_SIZE}"
echo "Backup Files: ${BACKUP_FILES}"

# Verify critical files
CRITICAL_FILES=(
    "${BACKUP_PATH}/core"
    "${BACKUP_PATH}/tests"
    "${BACKUP_PATH}/scripts"
    "${BACKUP_PATH}/backup_metadata.json"
    "${BACKUP_PATH}/inventory.md"
)

echo ""
echo "Critical files verification:"
for file in "${CRITICAL_FILES[@]}"; do
    if [ -e "$file" ]; then
        echo -e "${GREEN}✅ $file${NC}"
    else
        echo -e "${RED}❌ $file${NC}"
    fi
done

echo ""
echo "🎯 Backup Summary"
echo "================="
echo -e "${GREEN}✅ Backup completed successfully!${NC}"
echo -e "${GREEN}📦 Backup location: ${BACKUP_PATH}${NC}"
echo -e "${GREEN}📊 Backup size: ${BACKUP_SIZE}${NC}"
echo -e "${GREEN}📁 Files backed up: ${BACKUP_FILES}${NC}"
echo ""
echo -e "${BLUE}ℹ️  To restore this backup, run:${NC}"
echo -e "${BLUE}   ./scripts/restore_baseline.sh ${BACKUP_NAME}${NC}"
echo ""
echo -e "${GREEN}🔒 Baseline state secured! Ready for integration.${NC}"
