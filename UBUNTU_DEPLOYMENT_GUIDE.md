# 🚀 Astron Agent - Complete Ubuntu Deployment Guide

## 📋 Table of Contents

1. [Quick Start](#quick-start)
2. [Prerequisites](#prerequisites)
3. [Installation Methods](#installation-methods)
4. [Detailed Setup Instructions](#detailed-setup-instructions)
5. [Configuration](#configuration)
6. [Usage Commands](#usage-commands)
7. [Troubleshooting](#troubleshooting)
8. [Advanced Topics](#advanced-topics)
9. [AI-Powered Error Resolution](#ai-powered-error-resolution)

---

## 🎯 Quick Start

### One-Command Deployment

```bash
# Download and run the deployment script
curl -fsSL https://raw.githubusercontent.com/iflytek/astron-agent/main/deploy.sh | bash
```

### Standard Deployment (Recommended)

```bash
# 1. Clone the repository
git clone https://github.com/iflytek/astron-agent.git
cd astron-agent

# 2. Make scripts executable
chmod +x deploy.sh start.sh stop.sh

# 3. Deploy (installs all dependencies)
./deploy.sh

# 4. Start the platform
./start.sh

# 5. Stop when done
./stop.sh
```

**That's it!** The platform will be running at http://localhost/

---

## 📦 Prerequisites

### System Requirements

| Component | Minimum | Recommended |
|-----------|---------|-------------|
| **OS** | Ubuntu 20.04+ | Ubuntu 22.04 LTS |
| **CPU** | 2 cores | 4+ cores |
| **RAM** | 4 GB | 8+ GB |
| **Disk** | 50 GB | 100+ GB |
| **Network** | Internet connection | High-speed connection |

### Software Requirements

The `deploy.sh` script automatically installs:
- ✅ Docker Engine (latest)
- ✅ Docker Compose V2
- ✅ Git
- ✅ curl, wget, jq
- ✅ All system dependencies

**No manual installation required!**

---

## 🛠️ Installation Methods

### Method 1: Automated Deployment (Easiest)

```bash
# Single command - downloads and runs deployment
bash <(curl -fsSL https://raw.githubusercontent.com/iflytek/astron-agent/main/deploy.sh)
```

### Method 2: Manual Clone + Deploy (Recommended)

```bash
# Step 1: Clone repository
git clone https://github.com/iflytek/astron-agent.git
cd astron-agent

# Step 2: Make scripts executable
chmod +x *.sh

# Step 3: Run deployment
./deploy.sh
```

### Method 3: Existing Repository

If you already have the repository:

```bash
cd astron-agent

# Update repository
git pull origin main

# Re-run deployment
./deploy.sh
```

---

## 📖 Detailed Setup Instructions

### Step 1: Run Deployment Script

The `deploy.sh` script performs the following:

1. ✅ **System Checks**
   - Verifies Ubuntu OS
   - Checks CPU, RAM, disk space
   - Validates system requirements

2. ✅ **Dependency Installation**
   - Installs Docker Engine
   - Installs Docker Compose
   - Installs Git and utilities
   - Configures Docker permissions

3. ✅ **Repository Management**
   - Clones repository if not present
   - Updates existing repository
   - Validates repository structure

4. ✅ **Configuration**
   - Creates `.env` file from template
   - Prompts for credentials (optional)
   - Validates configuration

5. ✅ **Service Deployment**
   - Pulls Docker images
   - Starts all services
   - Waits for health checks
   - Validates deployment

6. ✅ **AI Error Handling**
   - Automatically detects errors
   - Calls AI resolver for solutions
   - Provides actionable fixes

### Step 2: Configure Credentials

During deployment, you'll be prompted to configure iFLYTEK platform credentials:

```
=== Environment Configuration ===

To get credentials:
1. Visit: https://www.xfyun.cn
2. Register and create an application
3. Get APP_ID, API_KEY, API_SECRET
4. For Spark API, get SPARK_API_PASSWORD from: https://xinghuo.xfyun.cn/sparkapi

Do you want to configure credentials now? (y/N)
```

#### Option A: Configure Now (Recommended)

Enter your credentials when prompted:

```bash
Enter PLATFORM_APP_ID: your_app_id_here
Enter PLATFORM_API_KEY: your_api_key_here
Enter PLATFORM_API_SECRET: your_api_secret_here
Enter SPARK_API_PASSWORD: your_spark_password_here
```

#### Option B: Configure Later

Skip the prompt and manually edit the `.env` file:

```bash
cd astron-agent/docker/astronAgent
nano .env

# Edit these lines:
PLATFORM_APP_ID=your_app_id_here
PLATFORM_API_KEY=your_api_key_here
PLATFORM_API_SECRET=your_api_secret_here
SPARK_API_PASSWORD=your_spark_password_here
```

### Step 3: Start the Platform

```bash
./start.sh
```

This script:
- ✅ Performs pre-flight checks
- ✅ Starts all services
- ✅ Monitors health status
- ✅ Verifies service accessibility
- ✅ Displays all URLs
- ✅ Opens browser automatically

**Expected Output:**

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
```

---

## ⚙️ Configuration

### Environment Variables

All configuration is in `astron-agent/docker/astronAgent/.env`:

#### Required Configuration

```env
# iFLYTEK Platform Credentials (REQUIRED)
PLATFORM_APP_ID=your_app_id
PLATFORM_API_KEY=your_api_key
PLATFORM_API_SECRET=your_api_secret
SPARK_API_PASSWORD=your_spark_password

# Real-time Speech Recognition (if using voice features)
SPARK_RTASR_API_KEY=your_rtasr_key
```

#### Optional Configuration

```env
# RAGFlow Knowledge Base (Optional)
RAGFLOW_BASE_URL=http://localhost:18080
RAGFLOW_API_TOKEN=your_ragflow_token
RAGFLOW_TIMEOUT=60
RAGFLOW_DEFAULT_GROUP=星辰知识库

# Spark RAG Cloud Service (Optional)
SPARK_DATASET_ID=your_dataset_id

# Database Configuration (Advanced)
MYSQL_ROOT_PASSWORD=custom_password
MYSQL_DATABASE=astron_db
REDIS_PASSWORD=custom_redis_pass
```

### Port Configuration

Default ports can be changed in `docker-compose-with-auth.yaml`:

| Service | Default Port | Description |
|---------|--------------|-------------|
| Astron Agent | 80 | Main frontend application |
| Casdoor | 8000 | Authentication service |
| API Gateway | 8080 | Backend API |
| MySQL | 3306 | Database |
| Redis | 6379 | Cache |
| RagFlow | 18080 | Knowledge base (optional) |

---

## 🎮 Usage Commands

### Starting the Platform

```bash
# Start all services with health checks
./start.sh

# Services will start automatically and browser will open
# Default URL: http://localhost/
```

### Stopping the Platform

```bash
# Graceful shutdown (keeps data)
./stop.sh

# Clean shutdown (removes all data)
./stop.sh --clean
```

### Managing Services

```bash
cd astron-agent/docker/astronAgent

# View logs
docker compose -f docker-compose-with-auth.yaml logs -f

# View specific service logs
docker compose -f docker-compose-with-auth.yaml logs -f <service_name>

# Restart a service
docker compose -f docker-compose-with-auth.yaml restart <service_name>

# Check service status
docker compose -f docker-compose-with-auth.yaml ps

# Execute command in container
docker compose -f docker-compose-with-auth.yaml exec <service_name> bash
```

### System Maintenance

```bash
# View Docker resource usage
docker system df

# Clean up unused resources
docker system prune -f

# Clean up everything (including volumes)
docker system prune -af --volumes

# Update to latest version
cd astron-agent
git pull origin main
./deploy.sh
```

---

## 🔧 Troubleshooting

### Common Issues

#### 1. Docker Permission Denied

**Error:**
```
Got permission denied while trying to connect to the Docker daemon socket
```

**Solution:**
```bash
# Add user to docker group
sudo usermod -aG docker $USER

# Apply group changes
newgrp docker

# Or log out and back in
```

#### 2. Port Already in Use

**Error:**
```
Error starting userland proxy: listen tcp 0.0.0.0:80: bind: address already in use
```

**Solution:**
```bash
# Check what's using the port
sudo lsof -i :80

# Stop the conflicting service
sudo systemctl stop apache2  # or nginx

# Or change port in docker-compose-with-auth.yaml
```

#### 3. Services Not Starting

**Solution:**
```bash
# Check logs
cd astron-agent/docker/astronAgent
docker compose -f docker-compose-with-auth.yaml logs

# Restart all services
docker compose -f docker-compose-with-auth.yaml restart

# Clean restart
docker compose -f docker-compose-with-auth.yaml down
docker compose -f docker-compose-with-auth.yaml up -d
```

#### 4. Cannot Access Frontend

**Solution:**
```bash
# Check if services are running
docker ps

# Check nginx logs
docker logs <nginx_container_name>

# Verify firewall
sudo ufw status
sudo ufw allow 80/tcp
```

#### 5. Database Connection Errors

**Solution:**
```bash
# Check MySQL container
docker ps | grep mysql

# Restart MySQL
docker compose -f docker-compose-with-auth.yaml restart mysql

# Check MySQL logs
docker compose -f docker-compose-with-auth.yaml logs mysql

# Reset database (WARNING: Data loss)
./stop.sh --clean
./start.sh
```

### AI-Powered Error Resolution

The deployment script includes **AI-powered error resolution**:

```bash
# Configure AI resolver (optional - already configured)
export ANTHROPIC_BASE_URL=https://api.z.ai/api/anthropic
export ANTHROPIC_MODEL=glm-4.6
export ANTHROPIC_AUTH_TOKEN=ae034cdcfefe4227879e6962493bc113.mRURYmJrKOFSEaY0
```

When an error occurs during deployment:
1. ✅ Error is automatically detected
2. ✅ Context is collected from logs
3. ✅ AI analyzes the error
4. ✅ Specific solution is provided
5. ✅ Commands are suggested

**Example AI Response:**

```
═══ AI Assistant Response ═══
Root Cause: Docker daemon is not running or user lacks permissions.

Solution:
1. Start Docker daemon: sudo systemctl start docker
2. Add user to docker group: sudo usermod -aG docker $USER
3. Apply changes: newgrp docker

Prevention:
- Ensure Docker starts on boot: sudo systemctl enable docker
- Verify access after user changes: docker ps
════════════════════════════
```

---

## 📚 Advanced Topics

### Custom Docker Compose Configuration

Create a custom compose file:

```bash
cd astron-agent/docker/astronAgent

# Copy existing config
cp docker-compose-with-auth.yaml docker-compose-custom.yaml

# Edit configuration
nano docker-compose-custom.yaml

# Use custom config
docker compose -f docker-compose-custom.yaml up -d
```

### SSL/HTTPS Configuration

#### Method 1: Using Let's Encrypt

```bash
# Install certbot
sudo apt-get install certbot

# Get certificate
sudo certbot certonly --standalone -d yourdomain.com

# Update nginx configuration in docker compose
# Add certificate volumes
```

#### Method 2: Using Reverse Proxy

Deploy with a reverse proxy like Traefik or Caddy for automatic SSL.

### Production Deployment Checklist

- [ ] Use strong passwords in `.env`
- [ ] Change default Casdoor credentials
- [ ] Configure SSL/TLS
- [ ] Set up backup for volumes
- [ ] Configure firewall rules
- [ ] Enable Docker logging
- [ ] Set up monitoring (Prometheus/Grafana)
- [ ] Configure resource limits
- [ ] Set up automatic updates
- [ ] Document custom configuration

### Backup and Restore

#### Backup

```bash
cd astron-agent/docker/astronAgent

# Backup all volumes
docker compose -f docker-compose-with-auth.yaml down
sudo tar -czf astron-backup-$(date +%Y%m%d).tar.gz \
  /var/lib/docker/volumes/

# Backup specific volumes
docker run --rm -v astronagent_mysql_data:/data \
  -v $(pwd):/backup ubuntu \
  tar -czf /backup/mysql-backup.tar.gz /data
```

#### Restore

```bash
# Restore from backup
sudo tar -xzf astron-backup-20250108.tar.gz -C /

# Or restore specific volume
docker run --rm -v astronagent_mysql_data:/data \
  -v $(pwd):/backup ubuntu \
  tar -xzf /backup/mysql-backup.tar.gz -C /
```

### Monitoring Setup

#### Using Docker Stats

```bash
# Real-time resource monitoring
docker stats

# Monitor specific containers
docker stats <container_name>
```

#### Using Portainer (Recommended)

```bash
# Deploy Portainer
docker volume create portainer_data
docker run -d -p 9000:9000 --name portainer \
  --restart always \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -v portainer_data:/data \
  portainer/portainer-ce

# Access at http://localhost:9000
```

### Scaling Services

```bash
# Scale specific service
docker compose -f docker-compose-with-auth.yaml up -d --scale api=3

# Load balancing configuration needed for multi-instance
```

---

## 🎓 Getting Started After Deployment

### 1. First Login

1. Open http://localhost/
2. You'll be redirected to Casdoor
3. Login with: **admin** / **123**
4. Change default password immediately

### 2. Create Your First Agent

1. Navigate to **Management** → **Bot API**
2. Click **Create Bot**
3. Configure:
   - Name: "My First Agent"
   - Model: Select available LLM
   - System prompt: Define agent behavior
4. Click **Save**
5. Test in chat interface

### 3. Build a Workflow

1. Go to **Workflow Editor**
2. Drag nodes from left panel:
   - Chat Node - For conversational interactions
   - CoT Node - For reasoning tasks
   - Tool Node - For external integrations
3. Connect nodes by dragging between ports
4. Configure each node
5. Click **Save & Test**

### 4. Configure Plugins

Available plugins:
- 🧠 **Knowledge Base** - RAG integration
- 🔗 **Link Management** - URL handling
- 🖥️ **RPA Automation** - Desktop automation
- 🔧 **MCP** - Model Context Protocol

---

## 📞 Support and Resources

### Documentation

- 📘 [Official Documentation](https://www.xfyun.cn/doc/spark/Agent02-快速开始.html)
- 🚀 [Deployment Guide](https://github.com/iflytek/astron-agent/blob/main/docs/DEPLOYMENT_GUIDE_WITH_AUTH.md)
- 💡 [Best Practices](https://www.xfyun.cn/doc/spark/AgentNew-技术实践案例.html)
- ❓ [FAQ](https://www.xfyun.cn/doc/spark/Agent06-FAQ.html)

### Community

- 💬 [GitHub Discussions](https://github.com/iflytek/astron-agent/discussions)
- 🐛 [Issue Tracker](https://github.com/iflytek/astron-agent/issues)
- 🌟 [GitHub Repository](https://github.com/iflytek/astron-agent)

### Getting Help

1. Check this documentation
2. Review logs: `docker compose logs`
3. Search GitHub issues
4. Ask in GitHub Discussions
5. Use AI error resolver (built-in)

---

## 📝 Changelog

### v1.0.0 (Current)
- ✅ One-command deployment
- ✅ AI-powered error resolution
- ✅ Automatic health checks
- ✅ Browser auto-launch
- ✅ Comprehensive logging
- ✅ Clean shutdown options

---

## 📜 License

This project is licensed under the [Apache 2.0 License](LICENSE).

Free for commercial use without restrictions.

---

## 🙏 Acknowledgments

Built with:
- Docker & Docker Compose
- FastAPI & React
- Casdoor Authentication
- RagFlow Knowledge Base
- iFLYTEK Spark AI

---

**Happy Deploying! 🚀**

For issues or questions, please visit:
https://github.com/iflytek/astron-agent/issues

