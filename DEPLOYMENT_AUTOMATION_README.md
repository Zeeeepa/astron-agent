# 🚀 Astron Agent - Deployment Automation

Complete automation suite for deploying and managing Astron Agent platform.

## 📋 Table of Contents

- [Overview](#overview)
- [Scripts](#scripts)
- [Quick Start](#quick-start)
- [Configuration](#configuration)
- [Usage Guide](#usage-guide)
- [Troubleshooting](#troubleshooting)
- [Best Practices](#best-practices)

---

## 🎯 Overview

This deployment automation provides **production-grade** lifecycle management:

✅ **One-command deployment** with automatic error recovery  
✅ **Zero-downtime updates** with automatic rollback  
✅ **Complete observability** with status and log analysis  
✅ **Disaster recovery** with automatic backups  
✅ **Graceful operations** with health monitoring  

### Architecture

```
┌─────────────────────────────────────────────────────────┐
│                  Deployment Lifecycle                    │
├─────────────────────────────────────────────────────────┤
│                                                          │
│  Deploy → Start → Monitor → Update → Rollback (if needed) │
│     ↓       ↓        ↓        ↓          ↓             │
│  deploy.sh  start.sh status.sh update.sh rollback.sh    │
│             stop.sh  logs.sh                             │
│                                                          │
└─────────────────────────────────────────────────────────┘
```

---

## 📜 Scripts

### Core Scripts

| Script | Purpose | Size | Key Features |
|--------|---------|------|--------------|
| **deploy.sh** | Initial deployment | 1,200+ lines | • Backup<br>• Validation<br>• Error recovery |
| **start.sh** | Start services | 15KB | • Health checks<br>• Auto-launch browser<br>• Progress tracking |
| **stop.sh** | Stop services | 12KB | • Graceful shutdown<br>• Optional cleanup<br>• Safety prompts |
| **rollback.sh** | Recover from failures | 500+ lines | • Backup validation<br>• Automatic restore<br>• Health verification |
| **status.sh** | Monitor system | 458 lines | • Service health<br>• Resource usage<br>• Quick diagnostics |
| **logs.sh** | Analyze logs | 490 lines | • Error highlighting<br>• Pattern search<br>• Export logs |
| **update.sh** | Safe updates | 530 lines | • Zero-downtime<br>• Auto-rollback<br>• Version tracking |

---

## ⚡ Quick Start

### First-Time Deployment

```bash
# 1. Clone repository
git clone https://github.com/your-org/astron-agent.git
cd astron-agent

# 2. Configure environment
cp .env.example docker/astronAgent/.env
nano docker/astronAgent/.env  # Edit configuration

# 3. Deploy everything
./deploy.sh

# 4. Access the platform
# Frontend: http://localhost/
# Casdoor: http://localhost:8000 (admin/123)
```

### Daily Operations

```bash
# Check system status
./status.sh

# View logs
./logs.sh nginx

# Update to latest version
./update.sh

# Rollback if needed
./rollback.sh --latest
```

---

## ⚙️ Configuration

### Environment Setup

1. **Copy template:**
   ```bash
   cp .env.example docker/astronAgent/.env
   ```

2. **Edit configuration:**
   ```bash
   nano docker/astronAgent/.env
   ```

3. **Required variables:**
   - `PLATFORM_APP_ID` - Platform application ID
   - `PLATFORM_API_KEY` - API authentication key
   - `PLATFORM_API_SECRET` - API secret
   - `SPARK_API_PASSWORD` - Spark API password
   - `MYSQL_ROOT_PASSWORD` - MySQL root password
   - `REDIS_PASSWORD` - Redis password
   - `SESSION_SECRET` - Session encryption key (32+ chars)
   - `JWT_SECRET` - JWT signing key (32+ chars)

4. **Validate configuration:**
   ```bash
   ./deploy.sh --validate-config
   ```

### Script Configuration

Set environment variables before running scripts:

```bash
# Custom repository directory
export REPO_DIR="custom-path"

# Custom deployment directory
export DEPLOY_DIR="custom-deploy-dir"

# Custom log file
export LOG_FILE="custom-deploy.log"
```

---

## 📖 Usage Guide

### deploy.sh - Initial Deployment

**Purpose:** Deploy the complete Astron Agent platform.

**Features:**
- ✅ Automatic dependency installation
- ✅ Docker setup and configuration
- ✅ Pre-deployment validation
- ✅ Automatic backup creation
- ✅ Health monitoring
- ✅ Error recovery with AI assistance

**Usage:**
```bash
# Standard deployment
./deploy.sh

# Dry-run (preview actions)
./deploy.sh --dry-run

# Verbose output
./deploy.sh --verbose

# Validate configuration only
./deploy.sh --validate-config
```

**What it does:**
1. Validates system prerequisites
2. Installs required dependencies
3. Configures Docker environment
4. Validates ports and disk space
5. Creates pre-deployment backup
6. Deploys all services
7. Performs health checks
8. Validates deployment success

**Time:** ~15-20 minutes (first run)

---

### start.sh - Start Services

**Purpose:** Start all services with health monitoring.

**Features:**
- ✅ Service startup in correct order
- ✅ Real-time health checks
- ✅ Progress indicators
- ✅ Browser auto-launch
- ✅ Resource monitoring

**Usage:**
```bash
# Start all services
./start.sh

# Start with verbose output
./start.sh --verbose

# Skip browser auto-launch
./start.sh --no-browser
```

**What it does:**
1. Checks Docker daemon status
2. Starts services in dependency order
3. Monitors startup progress
4. Validates health endpoints
5. Opens browser automatically (optional)
6. Displays access URLs

**Time:** ~2-3 minutes

---

### stop.sh - Stop Services

**Purpose:** Gracefully stop all services.

**Features:**
- ✅ Graceful 30-second shutdown
- ✅ Optional data cleanup
- ✅ Resource cleanup
- ✅ Safety confirmations

**Usage:**
```bash
# Stop services
./stop.sh

# Stop and clean all data (DESTRUCTIVE!)
./stop.sh --clean

# Force stop (no timeout)
./stop.sh --force
```

**What it does:**
1. Sends graceful shutdown signal
2. Waits 30 seconds for clean shutdown
3. Optionally removes data volumes
4. Cleans up Docker resources
5. Validates cleanup

**Time:** ~30-60 seconds

---

### rollback.sh - Disaster Recovery

**Purpose:** Rollback to previous working state.

**Features:**
- ✅ List available backups
- ✅ Backup integrity validation
- ✅ Automatic service restore
- ✅ Configuration restoration
- ✅ Volume restoration

**Usage:**
```bash
# List available backups
./rollback.sh --list

# Rollback to latest backup
./rollback.sh --latest

# Rollback to specific backup
./rollback.sh backup_20250108_171930
```

**What it does:**
1. Validates backup integrity
2. Stops current services
3. Restores configuration files
4. Restores Docker volumes
5. Restarts services
6. Validates rollback success

**Time:** ~5-10 minutes

---

### status.sh - System Monitoring

**Purpose:** Monitor system health and status.

**Features:**
- ✅ Service health status
- ✅ Endpoint health checks
- ✅ Resource usage tracking
- ✅ Deployment information
- ✅ Quick diagnostics

**Usage:**
```bash
# Complete status overview
./status.sh

# Service status only
./status.sh --services

# Endpoint health only
./status.sh --health

# Resource usage only
./status.sh --resources

# Deployment info only
./status.sh --deployment

# Quick diagnostics
./status.sh --diagnostics
```

**Output:**
```
🚀 ASTRON AGENT - SYSTEM STATUS

▶ Service Status
  SERVICE    STATUS     HEALTH    UPTIME
  nginx      running    healthy   2h
  casdoor    running    healthy   2h

▶ Endpoint Health
  Frontend   online     200
  Casdoor    online     200

▶ Resource Usage
  Memory: 3.2 / 8 GiB (40%)
  Disk: 45.6 / 100 GiB (45%)
```

**Time:** <5 seconds

---

### logs.sh - Log Analysis

**Purpose:** Intelligent log viewing and analysis.

**Features:**
- ✅ Service-specific logs
- ✅ Real-time log following
- ✅ Error highlighting
- ✅ Pattern search
- ✅ Error analysis
- ✅ Log export

**Usage:**
```bash
# List services
./logs.sh

# View service logs
./logs.sh nginx

# Follow logs in real-time
./logs.sh nginx -f

# Last 200 lines
./logs.sh nginx -n 200

# Search for pattern
./logs.sh nginx --search "error"

# View all services
./logs.sh --all

# Error analysis
./logs.sh --errors

# Export logs
./logs.sh --export nginx
```

**Features:**
- 🎨 Color-coded output (ERROR=red, WARNING=yellow, INFO=green)
- 🔍 Pattern search across logs
- 📊 Error counting and analysis
- 📤 One-command export for support

**Time:** <5 seconds

---

### update.sh - Safe Updates

**Purpose:** Update services with zero downtime.

**Features:**
- ✅ Zero-downtime updates
- ✅ Automatic backup before update
- ✅ Version validation
- ✅ Health checks after update
- ✅ Automatic rollback on failure

**Usage:**
```bash
# Update to latest version
./update.sh

# Update to specific version
./update.sh --version v1.2.3

# Preview update (dry-run)
./update.sh --dry-run

# Force update
./update.sh --force
```

**What it does:**
1. Creates pre-update backup
2. Fetches latest version
3. Validates version availability
4. Applies updates
5. Restarts services (zero-downtime)
6. Validates update success
7. Auto-rollback on failure

**Time:** ~10-15 minutes

---

## 🔧 Troubleshooting

### Common Issues

#### 1. **Deployment Fails**

**Symptoms:** deploy.sh exits with error

**Solutions:**
```bash
# Check prerequisites
./status.sh --diagnostics

# View detailed logs
tail -f deployment_*.log

# Check available disk space
df -h

# Check Docker status
docker ps
systemctl status docker

# Rollback to previous state
./rollback.sh --latest
```

#### 2. **Services Won't Start**

**Symptoms:** start.sh reports unhealthy services

**Solutions:**
```bash
# Check service status
./status.sh --services

# View service logs
./logs.sh <service>

# Check for port conflicts
sudo lsof -i :80
sudo lsof -i :8000

# Restart specific service
cd docker/astronAgent
docker compose restart <service>
```

#### 3. **High Memory Usage**

**Symptoms:** System slowdown

**Solutions:**
```bash
# Check resource usage
./status.sh --resources

# View container resources
docker stats

# Restart memory-heavy service
docker compose restart <service>

# Check logs for memory leaks
./logs.sh --errors <service>
```

#### 4. **Update Fails**

**Symptoms:** update.sh reports failure

**Solutions:**
```bash
# Check update logs
cat update_*.log

# Manual rollback
./rollback.sh --latest

# Check disk space
df -h

# Validate configuration
./deploy.sh --validate-config
```

### Getting Help

1. **Check logs first:**
   ```bash
   ./logs.sh --errors
   ```

2. **Review deployment log:**
   ```bash
   cat deployment_*.log
   ```

3. **Check system status:**
   ```bash
   ./status.sh
   ```

4. **Export logs for support:**
   ```bash
   ./logs.sh --export
   ```

5. **Contact support with:**
   - Deployment log file
   - Exported service logs
   - Output of `./status.sh`

---

## ✅ Best Practices

### 1. **Pre-Deployment**

```bash
# Always validate configuration first
./deploy.sh --validate-config

# Use dry-run for safety
./deploy.sh --dry-run

# Check disk space
df -h

# Ensure backups are working
./rollback.sh --list
```

### 2. **Regular Operations**

```bash
# Check status daily
./status.sh

# Monitor errors
./logs.sh --errors

# Keep backups clean (automatic in scripts)
# Backups auto-cleanup: keeps last 5
```

### 3. **Before Updates**

```bash
# Check current status
./status.sh

# Preview update
./update.sh --dry-run

# Verify backups available
./rollback.sh --list

# Update during low-traffic
./update.sh
```

### 4. **Security**

```bash
# Change default passwords immediately
nano docker/astronAgent/.env

# Use strong secrets (32+ characters)
# Rotate secrets regularly

# Never commit .env to Git
echo ".env" >> .gitignore

# Validate security settings
./deploy.sh --validate-config
```

### 5. **Monitoring**

```bash
# Regular health checks
./status.sh --diagnostics

# Monitor logs for errors
./logs.sh --errors

# Check resource usage
./status.sh --resources

# Export logs weekly for audit
./logs.sh --export
```

---

## 📊 Performance

### Resource Requirements

**Minimum:**
- CPU: 2 cores
- RAM: 4 GB
- Disk: 20 GB free
- Network: 10 Mbps

**Recommended:**
- CPU: 4+ cores
- RAM: 8+ GB
- Disk: 50+ GB free
- Network: 100+ Mbps

### Script Performance

| Script | Execution Time | Resource Usage |
|--------|----------------|----------------|
| deploy.sh | 15-20 min (first run) | High CPU, medium disk I/O |
| start.sh | 2-3 min | Low CPU, low I/O |
| stop.sh | 30-60 sec | Low CPU, low I/O |
| status.sh | <5 sec | Minimal |
| logs.sh | <5 sec | Minimal |
| rollback.sh | 5-10 min | Medium CPU, high disk I/O |
| update.sh | 10-15 min | Medium CPU, medium I/O |

---

## 🔄 Update History

### Version 1.0.0 (2025-01-08)

**Initial Release:**
- ✅ deploy.sh with backup and validation
- ✅ start.sh with health monitoring
- ✅ stop.sh with graceful shutdown
- ✅ rollback.sh for disaster recovery
- ✅ status.sh for system monitoring
- ✅ logs.sh for log analysis
- ✅ update.sh for safe updates

**Features:**
- 3,175+ lines of production code
- Complete lifecycle management
- Automatic error recovery
- Zero-downtime operations
- Production-grade reliability

---

## 📞 Support

**Documentation:**
- [Ubuntu Deployment Guide](UBUNTU_DEPLOYMENT_GUIDE.md)
- [Quick Reference](QUICK_REFERENCE.md)
- [Deployment Scripts README](DEPLOYMENT_SCRIPTS_README.md)

**Issues:**
- GitHub Issues: https://github.com/your-org/astron-agent/issues

**Community:**
- Discord: [Join our community]
- Forum: [Community forum]

---

## 📄 License

See [LICENSE](LICENSE) file for details.

---

**Built with ❤️ for production deployments**

**Last Updated:** 2025-01-08  
**Version:** 1.0.0

