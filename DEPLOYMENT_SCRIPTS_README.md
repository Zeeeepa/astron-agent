# 🚀 Astron Agent Deployment Scripts

## Overview

This repository includes **three powerful scripts** that make deploying and managing Astron Agent on Ubuntu incredibly simple:

1. **`deploy.sh`** - Complete automated deployment with AI-powered error resolution
2. **`start.sh`** - Smart startup with health checks and browser auto-launch
3. **`stop.sh`** - Graceful shutdown with optional cleanup

---

## 🎯 Quick Start (TL;DR)

```bash
# Make scripts executable
chmod +x deploy.sh start.sh stop.sh

# Deploy everything
./deploy.sh

# Start the platform
./start.sh

# Stop the platform
./stop.sh
```

**That's it!** Open http://localhost/ and you're ready to go! 🎉

---

## 📜 Script Details

### 1. `deploy.sh` - Complete Deployment Script

**What it does:**
- ✅ Checks system requirements (CPU, RAM, disk)
- ✅ Installs all dependencies (Docker, Git, etc.)
- ✅ Clones/updates the repository
- ✅ Configures environment variables
- ✅ Deploys all services with Docker Compose
- ✅ Validates deployment with health checks
- ✅ **AI-powered error resolution** (unique feature!)

**Usage:**
```bash
./deploy.sh
```

**Features:**
- 🤖 **AI Error Resolver**: Automatically diagnoses and suggests fixes
- 🔄 **Smart Updates**: Detects existing installation and updates
- 📊 **Progress Indicators**: Visual feedback during installation
- 📝 **Detailed Logging**: Everything logged to timestamped file
- 🎨 **Colored Output**: Easy-to-read terminal output
- ⚡ **Automatic Fallbacks**: Handles errors gracefully

**AI Configuration:**
The script includes built-in AI error resolution using:
```bash
export ANTHROPIC_BASE_URL=https://api.z.ai/api/anthropic
export ANTHROPIC_MODEL=glm-4.6
export ANTHROPIC_AUTH_TOKEN=ae034cdcfefe4227879e6962493bc113.mRURYmJrKOFSEaY0
```

When an error occurs, the AI analyzes it and provides:
- Root cause analysis
- Specific fix commands
- Prevention tips

**Output Example:**
```
╔═══════════════════════════════════════════════════════════════╗
║          🎉 DEPLOYMENT COMPLETED SUCCESSFULLY! 🎉            ║
╚═══════════════════════════════════════════════════════════════╝

Next Steps:
1. Run ./start.sh to start the platform with health checks
2. Run ./stop.sh to stop all services
3. Access the application at http://localhost/
4. Default Casdoor login: admin / 123
```

---

### 2. `start.sh` - Smart Startup Script

**What it does:**
- ✅ Performs pre-flight checks (Docker, repository)
- ✅ Starts all services with Docker Compose
- ✅ Monitors service health with progress bar
- ✅ Tests URL accessibility
- ✅ Displays all access URLs (local + remote)
- ✅ Shows container status and resource usage
- ✅ Opens browser automatically (optional)

**Usage:**
```bash
./start.sh
```

**Features:**
- 🏥 **Health Monitoring**: Real-time service health checks
- 📊 **Progress Bar**: Visual progress during startup
- 🌐 **Auto URL Detection**: Finds all service URLs
- 🖥️ **Browser Launch**: Opens frontend automatically
- 📱 **Remote Access**: Shows URLs for network access
- 🎨 **Beautiful UI**: Colored, formatted output

**Output Example:**
```
╔═══════════════════════════════════════════════════════════════╗
║               🚀 ASTRON AGENT IS RUNNING! 🚀                 ║
╚═══════════════════════════════════════════════════════════════╝

📍 Access URLs:

Local Access:
  🌐 Astron Agent:    http://localhost/
  🔐 Casdoor Admin:   http://localhost:8000
     └─ Credentials:  admin / 123

Remote Access (from other devices):
  🌐 Astron Agent:    http://192.168.1.100/
  🔐 Casdoor Admin:   http://192.168.1.100:8000

📊 Container Status:
✓ astron-nginx (Up 2 minutes)
✓ astron-casdoor (Up 2 minutes)
✓ astron-mysql (Up 2 minutes)
✓ astron-redis (Up 2 minutes)

💡 Quick Commands:
  View logs:         docker compose -f docker-compose-with-auth.yaml logs -f
  Stop services:     ./stop.sh
  Restart service:   docker compose -f docker-compose-with-auth.yaml restart <service>
```

---

### 3. `stop.sh` - Graceful Shutdown Script

**What it does:**
- ✅ Shows current service status
- ✅ Confirms shutdown with user
- ✅ Gracefully stops all services (30s timeout)
- ✅ Removes containers and networks
- ✅ Optionally removes volumes (clean mode)
- ✅ Shows Docker resource usage
- ✅ Offers to clean unused resources

**Usage:**
```bash
# Normal stop (keeps data)
./stop.sh

# Clean stop (removes all data)
./stop.sh --clean
```

**Features:**
- 🛑 **Graceful Shutdown**: 30-second timeout for services
- 💾 **Data Preservation**: Normal mode keeps all data
- 🧹 **Clean Mode**: Option to remove everything
- ⚠️ **Safety Prompts**: Confirms destructive actions
- 📊 **Resource Display**: Shows disk usage before/after
- 🎨 **Status Colors**: Visual feedback on shutdown

**Output Example:**
```
╔═══════════════════════════════════════════════════════════════╗
║          🛑 ALL SERVICES STOPPED SUCCESSFULLY! 🛑            ║
╚═══════════════════════════════════════════════════════════════╝

Next Steps:
  Start services:    ./start.sh
  Full redeployment: ./deploy.sh
  Clean volumes:     ./stop.sh --clean
```

---

## 🔍 Detailed Features

### AI-Powered Error Resolution

The `deploy.sh` script includes **unique AI-powered troubleshooting**:

1. **Automatic Detection**: Catches errors during deployment
2. **Context Collection**: Gathers relevant log information
3. **AI Analysis**: Sends error + context to AI model
4. **Solution Generation**: Receives actionable fixes
5. **Display**: Shows solution in terminal

**Example AI Response:**
```
═══ AI Assistant Response ═══
Root Cause: Docker daemon is not accessible to current user.

Solution:
1. Add user to docker group:
   sudo usermod -aG docker $USER

2. Apply changes:
   newgrp docker

3. Verify access:
   docker ps

Prevention:
- Run deployment after logging out and back in
- Ensure Docker service is running: sudo systemctl status docker
════════════════════════════
```

### Health Check System

The `start.sh` script includes **comprehensive health monitoring**:

```bash
# Real-time progress
[████████████████████████░░░░░░░░░░░░░░] 75% (6/8 services ready)

# Service status with colors
✓ nginx (healthy)
✓ mysql (healthy)
◐ api-gateway (starting)
✗ worker (failed)
```

### Resource Management

All scripts include **Docker resource tracking**:

```bash
# Disk usage display
TYPE            TOTAL    ACTIVE   SIZE      RECLAIMABLE
Images          15       8        4.5GB     2.1GB (46%)
Containers      8        8        1.2GB     0B (0%)
Local Volumes   10       5        3.8GB     1.5GB (39%)
```

---

## 📚 Configuration

### Environment Variables (AI Resolver)

Configure in `deploy.sh` or export before running:

```bash
# AI Error Resolver Configuration
export ANTHROPIC_BASE_URL=https://api.z.ai/api/anthropic
export ANTHROPIC_MODEL=glm-4.6
export ANTHROPIC_AUTH_TOKEN=your_token_here
```

### Application Configuration

Edit the `.env` file after deployment:

```bash
cd astron-agent/docker/astronAgent
nano .env
```

Required settings:
```env
PLATFORM_APP_ID=your_app_id
PLATFORM_API_KEY=your_api_key
PLATFORM_API_SECRET=your_api_secret
SPARK_API_PASSWORD=your_spark_password
```

---

## 🛠️ Advanced Usage

### Continuous Deployment

```bash
# Create a deployment script
cat > deploy-and-start.sh << 'EOF'
#!/bin/bash
./deploy.sh && ./start.sh
EOF

chmod +x deploy-and-start.sh
./deploy-and-start.sh
```

### Automated Updates

```bash
# Create update script
cat > update.sh << 'EOF'
#!/bin/bash
cd astron-agent
git pull origin main
./stop.sh
./deploy.sh
./start.sh
EOF

chmod +x update.sh
```

### Scheduled Restarts

```bash
# Add to crontab for weekly restart
crontab -e

# Add line:
0 2 * * 0 cd /path/to/astron-agent && ./stop.sh && ./start.sh
```

### Custom Health Checks

Modify `start.sh` to add custom checks:

```bash
# Add after line 200
custom_health_check() {
    log_info "Running custom health checks..."
    
    # Your custom checks here
    if curl -s http://localhost/health | grep -q "ok"; then
        log_success "Custom check passed"
    else
        log_error "Custom check failed"
    fi
}
```

---

## 🐛 Troubleshooting

### Script Won't Execute

```bash
# Make executable
chmod +x deploy.sh start.sh stop.sh

# Check permissions
ls -la *.sh
```

### Docker Not Found

```bash
# Install Docker manually
curl -fsSL https://get.docker.com | sudo bash
sudo usermod -aG docker $USER
newgrp docker
```

### Services Not Starting

```bash
# Check logs
cd astron-agent/docker/astronAgent
docker compose -f docker-compose-with-auth.yaml logs

# Check system resources
free -h
df -h
```

### Port Conflicts

```bash
# Find what's using the port
sudo lsof -i :80
sudo lsof -i :8000

# Stop conflicting services
sudo systemctl stop apache2
sudo systemctl stop nginx
```

---

## 📊 Comparison

| Feature | deploy.sh | start.sh | stop.sh |
|---------|-----------|----------|---------|
| **First-time setup** | ✅ | ❌ | ❌ |
| **Install dependencies** | ✅ | ❌ | ❌ |
| **Start services** | ✅ | ✅ | ❌ |
| **Health checks** | ✅ | ✅ | ❌ |
| **Stop services** | ❌ | ❌ | ✅ |
| **AI error resolution** | ✅ | ❌ | ❌ |
| **Browser launch** | ❌ | ✅ | ❌ |
| **Clean volumes** | ❌ | ❌ | ✅ |
| **Progress indicators** | ✅ | ✅ | ✅ |

---

## 🔄 Workflow Recommendations

### First Time Setup
```bash
./deploy.sh     # Install everything
./start.sh      # Start and verify
```

### Daily Usage
```bash
./start.sh      # Start working
# ... do your work ...
./stop.sh       # Stop when done
```

### Updates
```bash
./stop.sh       # Stop services
git pull        # Update code
./deploy.sh     # Redeploy
./start.sh      # Start again
```

### Clean Reinstall
```bash
./stop.sh --clean   # Remove everything
rm -rf astron-agent # Delete repository
./deploy.sh         # Fresh install
```

---

## 📝 Logging

All scripts generate logs:

- **deploy.sh**: `deployment_YYYYMMDD_HHMMSS.log`
- **start.sh**: Console output only
- **stop.sh**: Console output only

View deployment logs:
```bash
ls -lh deployment_*.log
tail -f deployment_*.log
```

---

## 🎯 Best Practices

1. **Always use `./deploy.sh` for first-time setup**
   - Handles all dependencies automatically
   - Configures environment properly

2. **Use `./start.sh` for daily operations**
   - Fast startup with validation
   - Auto-opens browser
   - Shows all important information

3. **Use `./stop.sh` without `--clean` normally**
   - Preserves your data
   - Quick restart possible
   - Safe for daily use

4. **Only use `./stop.sh --clean` when needed**
   - Removes all data (databases, configs)
   - Use for troubleshooting
   - Use before fresh install

5. **Keep scripts updated**
   - Run `git pull` regularly
   - Scripts improve over time
   - New features added

---

## 🚀 Performance Tips

### Faster Deployment
```bash
# Use existing images
docker compose -f docker-compose-with-auth.yaml pull

# Then deploy
./deploy.sh
```

### Faster Startup
```bash
# Increase Docker resources
# Edit: Docker Desktop > Settings > Resources
# CPU: 4+ cores
# Memory: 8+ GB
```

### Reduce Disk Usage
```bash
# Clean unused resources regularly
docker system prune -f

# Or use in stop script
./stop.sh --clean
```

---

## 📞 Support

- 📖 [Full Documentation](UBUNTU_DEPLOYMENT_GUIDE.md)
- 🎯 [Quick Reference](QUICK_REFERENCE.md)
- 🐛 [Report Issues](https://github.com/iflytek/astron-agent/issues)
- 💬 [Discussions](https://github.com/iflytek/astron-agent/discussions)

---

## 📜 License

Apache 2.0 License - Free for commercial use

---

## 🙏 Credits

Scripts created for Astron Agent by iFLYTEK

**Features:**
- AI-powered error resolution
- Comprehensive health checks
- Beautiful terminal UI
- Production-ready automation

---

**Ready to deploy?**

```bash
chmod +x *.sh && ./deploy.sh
```

🚀 **Let's go!**

