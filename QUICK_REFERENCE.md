# 🎯 Astron Agent - Quick Reference Card

## ⚡ One-Line Commands

```bash
# Deploy everything (first time)
./deploy.sh

# Start platform
./start.sh

# Stop platform
./stop.sh

# Stop + clean all data
./stop.sh --clean

# Rollback to previous state
./rollback.sh --latest

# List available backups
./rollback.sh --list

# Rollback to specific backup
./rollback.sh backup_20250108_171930

# Check system status
./status.sh

# View service logs
./logs.sh nginx

# Follow logs in real-time
./logs.sh nginx -f

# Analyze errors
./logs.sh --errors
```

---

## 🔗 Access URLs

| Service | URL | Credentials |
|---------|-----|-------------|
| **Astron Agent** | http://localhost/ | Via Casdoor |
| **Casdoor Admin** | http://localhost:8000 | admin / 123 |
| **API Gateway** | http://localhost:8080/docs | - |
| **RagFlow** (optional) | http://localhost:18080 | - |

---

## 📂 Important Files

```
astron-agent/
├── deploy.sh                           # Complete deployment (with backup)
├── start.sh                            # Start with health checks
├── stop.sh                             # Graceful shutdown
├── rollback.sh                         # Rollback to previous state
├── status.sh                           # System status checker ⭐ NEW
├── logs.sh                             # Intelligent log analyzer ⭐ NEW
├── backups/                            # Automatic backups directory
├── UBUNTU_DEPLOYMENT_GUIDE.md          # Full documentation
├── QUICK_REFERENCE.md                  # This file
└── docker/astronAgent/
    ├── .env                            # Configuration file
    └── docker-compose-with-auth.yaml   # Service definitions
```

---

## 🔍 Operational Tools (NEW!)

### Status Checking
```bash
./status.sh                    # Complete system overview
./status.sh --services         # Service health only
./status.sh --health           # Endpoint checks only
./status.sh --resources        # CPU/memory/disk usage
./status.sh --diagnostics      # Quick health check
```

### Log Analysis
```bash
./logs.sh                      # List available services
./logs.sh nginx                # View nginx logs (last 50)
./logs.sh nginx -f             # Follow nginx logs live
./logs.sh nginx -n 200         # Last 200 lines
./logs.sh --all                # All service logs
./logs.sh --errors             # Error summary (all)
./logs.sh --errors nginx       # Error summary (nginx)
./logs.sh --deployment         # View deployment logs
./logs.sh --export             # Export logs to file
```

### Troubleshooting Workflow
```bash
# 1. Check overall status
./status.sh

# 2. Identify problematic service
./status.sh --services

# 3. Analyze its errors
./logs.sh --errors <service>

# 4. View detailed logs
./logs.sh <service> -n 100

# 5. Export for support if needed
./logs.sh --export <service>
```

---

## ⚙️ Essential Docker Commands

```bash
cd astron-agent/docker/astronAgent

# View all services
docker compose -f docker-compose-with-auth.yaml ps

# View logs (all services)
docker compose -f docker-compose-with-auth.yaml logs -f

# View logs (specific service)
docker compose -f docker-compose-with-auth.yaml logs -f <service>

# Restart service
docker compose -f docker-compose-with-auth.yaml restart <service>

# Execute command in container
docker compose -f docker-compose-with-auth.yaml exec <service> bash

# Stop all
docker compose -f docker-compose-with-auth.yaml stop

# Remove containers
docker compose -f docker-compose-with-auth.yaml down

# Remove containers + volumes (WARNING: Data loss!)
docker compose -f docker-compose-with-auth.yaml down -v
```

---

## 🔍 Service Names

Common service names for logs/restart commands:

- `nginx` - Frontend web server
- `casdoor` - Authentication service
- `api-gateway` - Backend API
- `mysql` - Database
- `redis` - Cache
- `ragflow` - Knowledge base (if deployed)

---

## 🚨 Quick Troubleshooting

### Problem: Can't access frontend
```bash
docker ps                    # Check if services running
docker logs <container>      # Check logs
sudo ufw allow 80/tcp        # Check firewall
```

### Problem: Docker permission denied
```bash
sudo usermod -aG docker $USER
newgrp docker
```

### Problem: Port 80 in use
```bash
sudo lsof -i :80            # Find what's using port
sudo systemctl stop apache2  # Stop conflicting service
```

### Problem: Services unhealthy
```bash
docker compose -f docker-compose-with-auth.yaml restart
docker compose -f docker-compose-with-auth.yaml logs
```

### Problem: Need to reset everything
```bash
./stop.sh --clean           # Remove all data
./deploy.sh                 # Redeploy from scratch
```

---

## 📊 System Monitoring

```bash
# Resource usage
docker stats

# Disk usage
docker system df

# Clean unused resources
docker system prune -f

# Clean everything
docker system prune -af --volumes
```

---

## 🔐 Configuration

Edit configuration file:
```bash
cd astron-agent/docker/astronAgent
nano .env
```

Required variables:
```env
PLATFORM_APP_ID=your_app_id
PLATFORM_API_KEY=your_api_key
PLATFORM_API_SECRET=your_api_secret
SPARK_API_PASSWORD=your_spark_password
```

Get credentials at: https://www.xfyun.cn

---

## 🔄 Update Process

```bash
cd astron-agent
git pull origin main        # Get latest code
./stop.sh                   # Stop services
./deploy.sh                 # Redeploy
./start.sh                  # Start services
```

---

## 💾 Backup & Restore

### Quick Backup
```bash
cd astron-agent/docker/astronAgent
docker compose -f docker-compose-with-auth.yaml down
sudo tar -czf backup-$(date +%Y%m%d).tar.gz /var/lib/docker/volumes/
```

### Quick Restore
```bash
sudo tar -xzf backup-20250108.tar.gz -C /
```

---

## 🤖 AI Error Resolver

Configured automatically in `deploy.sh`:

```bash
export ANTHROPIC_BASE_URL=https://api.z.ai/api/anthropic
export ANTHROPIC_MODEL=glm-4.6
export ANTHROPIC_AUTH_TOKEN=ae034cdcfefe4227879e6962493bc113.mRURYmJrKOFSEaY0
```

Automatically provides solutions when errors occur during deployment.

---

## 📱 Remote Access

Find your server IP:
```bash
hostname -I
```

Access from other devices:
- Frontend: `http://<your-ip>/`
- Casdoor: `http://<your-ip>:8000`

Don't forget to configure firewall:
```bash
sudo ufw allow 80/tcp
sudo ufw allow 8000/tcp
```

---

## 🎓 First Steps After Deployment

1. **Login**: http://localhost/ (redirects to Casdoor)
   - User: `admin`
   - Pass: `123`
   - **Change password immediately!**

2. **Create Agent**:
   - Management → Bot API → Create Bot
   - Configure name, model, and prompts

3. **Test Agent**:
   - Chat interface → Select your bot
   - Start conversation

4. **Build Workflow**:
   - Workflow Editor → Drag nodes
   - Connect and configure
   - Save & Test

---

## 📞 Get Help

1. Check logs: `docker compose logs`
2. Review: [UBUNTU_DEPLOYMENT_GUIDE.md](UBUNTU_DEPLOYMENT_GUIDE.md)
3. GitHub Issues: https://github.com/iflytek/astron-agent/issues
4. Documentation: https://www.xfyun.cn/doc/spark/Agent02-快速开始.html

---

## ✅ System Requirements

| Component | Minimum | Recommended |
|-----------|---------|-------------|
| CPU | 2 cores | 4+ cores |
| RAM | 4 GB | 8+ GB |
| Disk | 50 GB | 100+ GB |
| OS | Ubuntu 20.04+ | Ubuntu 22.04 LTS |

---

## 🎯 Production Checklist

- [ ] Change default passwords
- [ ] Configure SSL/HTTPS
- [ ] Set up backups
- [ ] Configure firewall
- [ ] Monitor resources
- [ ] Set up logging
- [ ] Document configuration
- [ ] Test disaster recovery

---

**Quick Start:**
```bash
./deploy.sh && ./start.sh
```

**That's it!** 🚀

Open http://localhost/ and start building AI agents!
