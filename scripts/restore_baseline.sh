#!/bin/bash

# Restore Baseline Script for Astron-Agent RPA Integration
# Restores a previously created backup to restore PR #2 baseline state

set -e

echo "🔄 Astron-Agent Baseline Restoration"
echo "===================================="
echo ""

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Check if backup name provided
if [ $# -eq 0 ]; then
    echo -e "${RED}❌ Error: Backup name required${NC}"
    echo ""
    echo "Usage: $0 <backup_name>"
    echo ""
    echo "Available backups:"
    if [ -d "backup" ]; then
        ls -1 backup/ | grep "pr2_baseline_" || echo "No backups found"
    else
        echo "No backup directory found"
    fi
    exit 1
fi

BACKUP_NAME="$1"
BACKUP_PATH="backup/${BACKUP_NAME}"

# Validate backup exists
if [ ! -d "${BACKUP_PATH}" ]; then
    echo -e "${RED}❌ Error: Backup not found: ${BACKUP_PATH}${NC}"
    echo ""
    echo "Available backups:"
    if [ -d "backup" ]; then
        ls -1 backup/ | grep "pr2_baseline_" || echo "No backups found"
    else
        echo "No backup directory found"
    fi
    exit 1
fi

echo "📦 Restoration Configuration"
echo "---------------------------"
echo "Backup Name: ${BACKUP_NAME}"
echo "Backup Path: ${BACKUP_PATH}"
echo "Current Branch: $(git branch --show-current)"
echo "Current Commit: $(git rev-parse HEAD)"
echo ""

# Load backup metadata if available
if [ -f "${BACKUP_PATH}/backup_metadata.json" ]; then
    echo "📊 Backup Information"
    echo "--------------------"
    
    # Extract key information from metadata (basic parsing)
    if command -v jq &> /dev/null; then
        echo "Original Branch: $(jq -r '.git_branch' "${BACKUP_PATH}/backup_metadata.json")"
        echo "Original Commit: $(jq -r '.git_commit' "${BACKUP_PATH}/backup_metadata.json")"
        echo "Backup Timestamp: $(jq -r '.backup_timestamp' "${BACKUP_PATH}/backup_metadata.json")"
    else
        echo "Metadata file found (install jq for detailed info)"
    fi
    echo ""
fi

# Confirmation prompt
echo -e "${YELLOW}⚠️  WARNING: This will overwrite current files with backup content${NC}"
echo -e "${YELLOW}⚠️  Make sure you have committed or stashed any important changes${NC}"
echo ""
read -p "Continue with restoration? (y/N): " -n 1 -r
echo ""

if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo -e "${BLUE}ℹ️  Restoration cancelled${NC}"
    exit 0
fi

echo ""
echo "🔄 Starting restoration process..."
echo "--------------------------------"

# Check current git status
if ! git diff --quiet || ! git diff --cached --quiet; then
    echo -e "${YELLOW}⚠️  Uncommitted changes detected${NC}"
    echo "Stashing current changes..."
    git stash push -m "Pre-restoration stash $(date)"
    echo -e "${GREEN}✅ Changes stashed${NC}"
fi

# Restore files
RESTORE_ITEMS=(
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

echo ""
echo "📁 Restoring files..."
echo "--------------------"

for item in "${RESTORE_ITEMS[@]}"; do
    if [ -e "${BACKUP_PATH}/${item}" ]; then
        echo -e "${GREEN}✅ Restoring: ${item}${NC}"
        
        # Remove existing item if it exists
        if [ -e "${item}" ]; then
            rm -rf "${item}"
        fi
        
        # Copy from backup
        cp -r "${BACKUP_PATH}/${item}" "${item}"
    else
        echo -e "${YELLOW}⚠️  Not in backup: ${item}${NC}"
    fi
done

echo ""
echo "🔧 Restoring git patches (if any)..."
echo "-----------------------------------"

# Apply unstaged changes if they exist
if [ -f "${BACKUP_PATH}/git_diff_unstaged.patch" ]; then
    if git apply "${BACKUP_PATH}/git_diff_unstaged.patch" 2>/dev/null; then
        echo -e "${GREEN}✅ Unstaged changes restored${NC}"
    else
        echo -e "${YELLOW}⚠️  Could not apply unstaged changes (conflicts possible)${NC}"
    fi
else
    echo -e "${BLUE}ℹ️  No unstaged changes to restore${NC}"
fi

# Apply staged changes if they exist
if [ -f "${BACKUP_PATH}/git_diff_staged.patch" ]; then
    if git apply --cached "${BACKUP_PATH}/git_diff_staged.patch" 2>/dev/null; then
        echo -e "${GREEN}✅ Staged changes restored${NC}"
    else
        echo -e "${YELLOW}⚠️  Could not apply staged changes (conflicts possible)${NC}"
    fi
else
    echo -e "${BLUE}ℹ️  No staged changes to restore${NC}"
fi

echo ""
echo "🔍 Restoration verification..."
echo "-----------------------------"

# Verify critical files
CRITICAL_FILES=(
    "core/"
    "tests/"
    "scripts/"
    "requirements-test.txt"
)

echo "Critical files verification:"
for file in "${CRITICAL_FILES[@]}"; do
    if [ -e "$file" ]; then
        echo -e "${GREEN}✅ $file${NC}"
    else
        echo -e "${RED}❌ $file${NC}"
    fi
done

echo ""
echo "📊 Post-restoration status..."
echo "----------------------------"

# Show current git status
echo "Git status:"
git status --short

echo ""
echo "Repository statistics:"
echo "Files: $(find . -type f -name '*.py' -o -name '*.yml' -o -name '*.yaml' -o -name '*.md' -o -name '*.sh' -o -name '*.txt' | grep -v '.git' | wc -l)"
echo "Python files: $(find . -type f -name '*.py' | grep -v '.git' | wc -l)"
echo "Test files: $(find . -type f -path '*/test*' -name '*.py' | wc -l)"

echo ""
echo "🎯 Restoration Summary"
echo "====================="
echo -e "${GREEN}✅ Restoration completed successfully!${NC}"
echo -e "${GREEN}📦 Restored from: ${BACKUP_PATH}${NC}"
echo -e "${GREEN}🔄 Baseline state restored${NC}"
echo ""
echo -e "${BLUE}ℹ️  Next steps:${NC}"
echo -e "${BLUE}   1. Review git status: git status${NC}"
echo -e "${BLUE}   2. Validate environment: ./scripts/validate_environment.sh${NC}"
echo -e "${BLUE}   3. Run tests to verify functionality${NC}"
echo ""
echo -e "${GREEN}🔒 Ready to proceed with integration!${NC}"
