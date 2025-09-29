# 🚀 Quick Start Commands: astron-agent + astron-rpa

## 📥 Initial Setup Commands

### 1. Clone and Setup Repository
```bash
# Clone the repository
git clone https://github.com/Zeeeepa/astron-agent.git
cd astron-agent

# Checkout the deployment branch
git checkout codegen-bot/unified-deployment-1759128224

# Make scripts executable
chmod +x *.sh scripts/*.sh

# One-command deployment
./deploy.sh
```

### 2. Alternative Manual Setup
```bash
# If deploy.sh fails, use manual deployment
docker compose -f docker-compose.unified.yml --env-file .env.unified up -d

# Or with specific options
./deploy.sh --skip-deps          # Skip dependency installation
./deploy.sh --production         # Production mode
./deploy.sh --force-recreate     # Force recreate containers
```

## 🌐 Access URLs and Ports

After deployment, access these interfaces:

| Service | URL | Port | Description |
|---------|-----|------|-------------|
| **🤖 RPA Platform** | http://localhost/rpa/ | 80 | Complete RPA interface |
| **🧠 Agent Console** | http://localhost/agent/ | 80 | Agent management console |
| **🔐 Authentication** | http://localhost/auth/ | 80 | Casdoor auth service |
| **💾 MinIO Console** | http://localhost/minio/ | 80 | Object storage admin |
| **📊 System Health** | http://localhost/health | 80 | Health check endpoint |

### Direct Service Access (Development)
| Service | URL | Port | Purpose |
|---------|-----|------|---------|
| RPA AI Service | http://localhost:8010 | 8010 | AI processing |
| RPA OpenAPI | http://localhost:8020 | 8020 | RPA API gateway |
| RPA Resource | http://localhost:8030 | 8030 | Resource management |
| RPA Robot | http://localhost:8040 | 8040 | Robot execution |
| Agent Core | http://localhost:17870 | 17870 | Core agent service |
| Agent RPA Plugin | http://localhost:8003 | 8003 | RPA integration |
| Agent Console API | http://localhost:8080 | 8080 | Console backend |
| Agent Frontend | http://localhost:1881 | 1881 | Agent web UI |
| RPA Frontend | http://localhost:32742 | 32742 | RPA web UI |

## 🛠️ Management Commands

### Service Control
```bash
# Start all services
./scripts/manage-services.sh start

# Stop all services
./scripts/manage-services.sh stop

# Restart all services
./scripts/manage-services.sh restart

# Check status
./scripts/manage-services.sh status

# View logs
./scripts/manage-services.sh logs

# Health check
./scripts/health-check.sh
```

### Service Groups
```bash
# Infrastructure only (MySQL, Redis, MinIO, etc.)
./scripts/manage-services.sh start infra

# RPA services only
./scripts/manage-services.sh start rpa

# Agent services only
./scripts/manage-services.sh start agent

# Proxy only (Nginx)
./scripts/manage-services.sh start proxy
```

## 🔄 Docker Compose Commands

### Basic Operations
```bash
# Start all services
docker compose -f docker-compose.unified.yml --env-file .env.unified up -d

# Stop all services
docker compose -f docker-compose.unified.yml --env-file .env.unified down

# Restart services
docker compose -f docker-compose.unified.yml --env-file .env.unified restart

# View logs
docker compose -f docker-compose.unified.yml --env-file .env.unified logs -f

# Check status
docker compose -f docker-compose.unified.yml --env-file .env.unified ps
```

### Specific Service Control
```bash
# Start specific services
docker compose -f docker-compose.unified.yml --env-file .env.unified up -d mysql redis minio

# Restart specific service
docker compose -f docker-compose.unified.yml --env-file .env.unified restart rpa-ai-service

# View specific service logs
docker compose -f docker-compose.unified.yml --env-file .env.unified logs -f agent-core-agent
```

## 📊 Status and Monitoring Commands

### Quick Status Check
```bash
# System health
curl -s http://localhost/health && echo " - System OK" || echo " - System DOWN"

# Service endpoints
curl -s http://localhost/rpa/ > /dev/null && echo "✅ RPA Platform: UP" || echo "❌ RPA Platform: DOWN"
curl -s http://localhost/agent/ > /dev/null && echo "✅ Agent Console: UP" || echo "❌ Agent Console: DOWN"
curl -s http://localhost:8020/health > /dev/null && echo "✅ RPA API: UP" || echo "❌ RPA API: DOWN"
curl -s http://localhost:17870/health > /dev/null && echo "✅ Agent Core: UP" || echo "❌ Agent Core: DOWN"
```

### Detailed Status
```bash
# Comprehensive health check
./scripts/health-check.sh

# Container status
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"

# Resource usage
docker stats --no-stream --format "table {{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}"
```

## 🔧 WSL2 Bashrc Setup

Add these to your `~/.bashrc` for automatic startup and aliases:

```bash
# Add to ~/.bashrc
cat >> ~/.bashrc << 'EOF'

# ============================================================================
# ASTRON UNIFIED DEPLOYMENT - WSL2 STARTUP
# ============================================================================

# Function to check if astron services are running
check_astron_status() {
    if command -v docker &> /dev/null && docker info &> /dev/null; then
        local running_containers=$(docker ps --filter "name=astron" --filter "name=unified" --filter "name=rpa" --filter "name=agent" -q | wc -l)
        if [ "$running_containers" -gt 0 ]; then
            echo "🟢 Astron services: $running_containers containers running"
            echo "   🌐 Access: http://localhost/rpa/ | http://localhost/agent/"
        else
            echo "🔴 Astron services: Not running"
            echo "   ▶️  Type 'start' to start all services"
            echo "   📊 Type 'status' to check system status"
        fi
    else
        echo "🔴 Docker: Not available"
    fi
}

# Function to start astron services
start_astron() {
    echo "🚀 Starting Astron unified services..."
    cd ~/astron-agent 2>/dev/null || {
        echo "❌ astron-agent directory not found. Please clone the repository first:"
        echo "   git clone https://github.com/Zeeeepa/astron-agent.git ~/astron-agent"
        return 1
    }
    
    if [ -f "docker-compose.unified.yml" ]; then
        docker compose -f docker-compose.unified.yml --env-file .env.unified up -d
        echo "✅ Services started! Access:"
        echo "   🤖 RPA Platform: http://localhost/rpa/"
        echo "   🧠 Agent Console: http://localhost/agent/"
        echo "   🔐 Authentication: http://localhost/auth/"
    else
        echo "❌ Deployment files not found. Run ./quick-setup.sh first"
    fi
}

# Function to stop astron services
stop_astron() {
    echo "⏹️ Stopping Astron services..."
    cd ~/astron-agent 2>/dev/null || return 1
    if [ -f "docker-compose.unified.yml" ]; then
        docker compose -f docker-compose.unified.yml --env-file .env.unified down
        echo "✅ Services stopped"
    fi
}

# Function to show astron status
show_astron_status() {
    cd ~/astron-agent 2>/dev/null || return 1
    if [ -f "scripts/health-check.sh" ]; then
        ./scripts/health-check.sh
    else
        docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" | grep -E "(astron|rpa|agent|unified)"
    fi
}

# Function to show astron logs
show_astron_logs() {
    cd ~/astron-agent 2>/dev/null || return 1
    if [ -f "docker-compose.unified.yml" ]; then
        docker compose -f docker-compose.unified.yml --env-file .env.unified logs -f --tail=50
    fi
}

# Aliases for easy management
alias start='start_astron'
alias stop='stop_astron'
alias status='show_astron_status'
alias logs='show_astron_logs'
alias astron-start='start_astron'
alias astron-stop='stop_astron'
alias astron-status='show_astron_status'
alias astron-logs='show_astron_logs'

# Quick access aliases
alias rpa='echo "🤖 RPA Platform: http://localhost/rpa/" && xdg-open http://localhost/rpa/ 2>/dev/null || echo "Open manually: http://localhost/rpa/"'
alias agent='echo "🧠 Agent Console: http://localhost/agent/" && xdg-open http://localhost/agent/ 2>/dev/null || echo "Open manually: http://localhost/agent/"'
alias health='curl -s http://localhost/health && echo " ✅" || echo "❌ System not responding"'

# Show status on WSL startup (only if Docker is available)
if command -v docker &> /dev/null && docker info &> /dev/null 2>&1; then
    echo ""
    echo "🚀 Astron Unified Platform Status:"
    check_astron_status
    echo ""
    echo "💡 Quick commands: start | stop | status | logs | rpa | agent"
    echo ""
fi

EOF

# Reload bashrc
source ~/.bashrc
```

## 🚀 Complete Setup Script

Here's a complete script to set everything up:

```bash
#!/bin/bash
# save as setup-astron.sh and run: chmod +x setup-astron.sh && ./setup-astron.sh

echo "🚀 Setting up Astron Unified Platform..."

# 1. Clone repository
if [ ! -d "astron-agent" ]; then
    git clone https://github.com/Zeeeepa/astron-agent.git
    cd astron-agent
    git checkout codegen-bot/unified-deployment-1759128224
else
    cd astron-agent
    git pull origin codegen-bot/unified-deployment-1759128224
fi

# 2. Make scripts executable
chmod +x *.sh scripts/*.sh

# 3. Deploy services
echo "🔧 Starting deployment..."
./quick-setup.sh

# 4. Add aliases to bashrc (if not already added)
if ! grep -q "start_astron" ~/.bashrc; then
    echo "📝 Adding aliases to ~/.bashrc..."
    cat >> ~/.bashrc << 'BASHRC_EOF'

# Astron Platform Aliases
alias start='cd ~/astron-agent && docker compose -f docker-compose.unified.yml --env-file .env.unified up -d'
alias stop='cd ~/astron-agent && docker compose -f docker-compose.unified.yml --env-file .env.unified down'
alias status='cd ~/astron-agent && ./scripts/health-check.sh'
alias logs='cd ~/astron-agent && docker compose -f docker-compose.unified.yml --env-file .env.unified logs -f'
alias rpa='echo "🤖 RPA: http://localhost/rpa/"'
alias agent='echo "🧠 Agent: http://localhost/agent/"'

BASHRC_EOF
    source ~/.bashrc
fi

echo "✅ Setup complete!"
echo ""
echo "🌐 Access URLs:"
echo "   🤖 RPA Platform: http://localhost/rpa/"
echo "   🧠 Agent Console: http://localhost/agent/"
echo "   🔐 Authentication: http://localhost/auth/"
echo ""
echo "💡 Commands:"
echo "   start  - Start all services"
echo "   stop   - Stop all services"
echo "   status - Check system health"
echo "   logs   - View service logs"
```

## 🔍 Troubleshooting Commands

### If Services Don't Start
```bash
# Check Docker status
docker info

# Check for port conflicts
netstat -tuln | grep -E "(80|443|3306|5432|6379|9000)"

# Check disk space
df -h

# Check memory
free -h

# Restart Docker (if needed)
sudo systemctl restart docker

# Clean up and restart
docker system prune -f
./scripts/manage-services.sh restart
```

### If Web Interfaces Don't Load
```bash
# Check nginx status
docker ps | grep nginx

# Check nginx logs
docker logs unified-nginx

# Test direct service access
curl http://localhost:8020/health  # RPA API
curl http://localhost:17870/health # Agent Core
curl http://localhost:8080/health  # Agent Console
```

## 📋 Daily Usage Commands

```bash
# Morning startup
start

# Check everything is working
status

# View what's happening
logs

# Access platforms
rpa    # Opens RPA platform
agent  # Opens Agent console

# Evening shutdown
stop
```

This setup gives you complete control over the unified astron-agent + astron-rpa deployment with simple commands and automatic status checking! 🚀
