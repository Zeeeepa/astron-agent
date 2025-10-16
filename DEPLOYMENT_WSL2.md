# Astron Agent - WSL2 Deployment Guide

Complete guide for deploying Astron Agent on Windows Subsystem for Linux 2 (WSL2) with full English language support.

## 📋 Table of Contents

- [Prerequisites](#prerequisites)
- [Quick Start](#quick-start)
- [Detailed Installation](#detailed-installation)
- [Configuration](#configuration)
- [Accessing the Platform](#accessing-the-platform)
- [Management Commands](#management-commands)
- [Troubleshooting](#troubleshooting)
- [Advanced Configuration](#advanced-configuration)

---

## Prerequisites

### System Requirements

**Minimum:**
- Windows 10 version 2004+ or Windows 11
- WSL2 installed and enabled
- 8GB RAM available for WSL2
- 30GB free disk space
- Internet connection for downloading Docker images

**Recommended:**
- 16GB+ RAM
- 50GB+ free disk space
- SSD storage for better performance

### WSL2 Setup

If you haven't installed WSL2 yet:

1. **Open PowerShell as Administrator** and run:
   ```powershell
   wsl --install -d Ubuntu
   ```

2. **Restart your computer** when prompted

3. **Open Ubuntu** from Start Menu and complete initial setup:
   - Create username and password
   - Update system packages:
     ```bash
     sudo apt update && sudo apt upgrade -y
     ```

4. **Verify WSL2 version:**
   ```bash
   wsl --list --verbose
   ```
   Ensure your distro shows VERSION 2

---

## Quick Start

### Step 1: Clone Repository

```bash
cd ~
git clone https://github.com/iflytek/astron-agent.git
cd astron-agent
```

### Step 2: Run Setup Script

This will install Docker, configure the environment, and prepare everything:

```bash
./setup.sh
```

**What it does:**
- ✅ Checks WSL2 environment and system resources
- ✅ Installs Docker Engine and Docker Compose
- ✅ Configures Docker daemon and user permissions
- ✅ Creates `.env` configuration with secure passwords
- ✅ **Builds frontend with English as default language** (5-10 minutes)
- ✅ Updates docker-compose to use English frontend
- ✅ Validates port availability
- ✅ Creates helper scripts for management

**⏱️ Total setup time:** 15-20 minutes (includes frontend build)

**Note:** If prompted about systemd, you'll need to:
1. Run `wsl --shutdown` in PowerShell
2. Restart your WSL terminal
3. Run `./setup.sh` again

If you see "permission denied" for Docker commands:
```bash
newgrp docker
# Then run setup.sh again
```

### Step 3: Start Services

```bash
./start.sh
```

**This will:**
- ✅ Pull all required Docker images (~5-10 minutes first time)
- ✅ Start infrastructure services (PostgreSQL, MySQL, Redis, Elasticsearch, Kafka, MinIO)
- ✅ Start core application services (Tenant, Database, RPA, Link, AITools, Agent, Knowledge, Workflow)
- ✅ Start console services (Frontend, Hub, Nginx)
- ✅ Verify all services are healthy
- ✅ Display access information

**Total time:** 10-15 minutes on first run

### Step 4: Access the Platform

Open your browser and navigate to:

```
http://localhost
```

🎉 **You're ready to use Astron Agent!**

**Note:** The console UI will default to **English** if the frontend was built during setup. If not, you can:
- Manually switch language using the language selector (top-right corner)
- Run setup again to build the English frontend: `./setup.sh`

---

## Language Configuration

### English as Default Language

The deployment scripts configure Astron Agent to default to **English**:

1. **Frontend i18n:** Modified to use English as the default language
2. **Backend Service Location:** Set to `SERVICE_LOCATION=en` in `.env`
3. **Custom Build:** Frontend Docker image built with English defaults

### Building English Frontend

The `setup.sh` script automatically builds the frontend with English defaults during the setup process.

**The build process:**
- Creates a Docker image with English i18n defaults
- Tags it as `astron-agent-console-frontend-en:latest`
- Takes 5-10 minutes depending on your system
- Is fully integrated into the setup workflow

### Verifying English Default

To verify the console defaults to English:

1. Open browser in **incognito/private mode** (to clear localStorage)
2. Navigate to `http://localhost`
3. The UI should display in English by default

### Switching Languages Manually

Users can always switch languages using:
- **Language selector** in the top-right corner of the console
- Preference is saved in browser localStorage
- Supports: English (en) and Chinese (zh)

### Skipping Frontend Build

If you want to use the standard image (Chinese default) and skip the build:

```bash
# Edit setup.sh and comment out:
#   build_frontend_english
#   update_docker_compose

# Then run setup
./setup.sh
```

---

## Detailed Installation

### Setup Script Details

The `setup.sh` script performs the following checks and installations:

#### 1. Environment Validation
- Confirms WSL2 environment
- Checks Linux distribution (optimized for Ubuntu/Debian)
- Validates system resources (RAM, disk space)
- Ensures systemd is enabled

#### 2. Docker Installation
- Installs Docker Engine (not Docker Desktop)
- Installs Docker Compose plugin
- Configures Docker daemon with optimal settings:
  - JSON file logging with rotation
  - Overlay2 storage driver
  - Automatic startup on boot

#### 3. Docker Configuration
- Adds user to `docker` group for non-root access
- Enables Docker service via systemd
- Validates installation with test container

#### 4. Port Availability
Checks these ports are available:
- **80** - Nginx (web interface)
- **3306** - MySQL
- **5432** - PostgreSQL
- **6379** - Redis
- **9092** - Kafka
- **9200** - Elasticsearch
- **9000/9001** - MinIO (API/Console)

#### 5. Environment Configuration
- Copies `.env.example` to `.env`
- Generates secure random passwords for:
  - PostgreSQL
  - MySQL
  - Redis
  - MinIO
- Configures English locale
- Sets localhost as deployment domain
- Optionally configures iFLYTEK API keys

#### 6. Helper Scripts
Creates management scripts:
- `status.sh` - Check service status
- `logs.sh` - View service logs
- `stop.sh` - Stop all services
- `cleanup.sh` - Complete removal

### Start Script Details

The `start.sh` script orchestrates service startup in three phases:

#### Phase 1: Infrastructure Services
Starts in order with health checks:
1. **PostgreSQL** - Main relational database
2. **MySQL** - Additional database for specific services
3. **Redis** - Caching and session management
4. **Elasticsearch** - Search and analytics
5. **Kafka** - Message queue for async processing
6. **MinIO** - Object storage (S3-compatible)

Each service waits until healthy before proceeding.

#### Phase 2: Core Services
Starts application microservices:
1. **Tenant Service** - Multi-tenancy management
2. **Memory Database Service** - Vector/graph database
3. **RPA Plugin Service** - Robotic process automation
4. **Link Plugin Service** - External tool integration
5. **AITools Plugin Service** - AI capability plugins
6. **Agent Service** - Core agent orchestration
7. **Knowledge Service** - Knowledge base management
8. **Workflow Service** - Workflow engine

#### Phase 3: Console Services
Starts user interface:
1. **Console Frontend** - React-based web UI
2. **Console Hub** - Backend API server (Spring Boot)
3. **Nginx** - Reverse proxy and load balancer

### Service Dependencies

```
Infrastructure Layer:
  PostgreSQL ────┐
  MySQL ─────────┼───> Core Services ───> Console Services ───> Nginx
  Redis ─────────┤
  Elasticsearch ─┤
  Kafka ─────────┤
  MinIO ─────────┘
```

---

## Configuration

### Environment Variables

All configuration is in `docker/astronAgent/.env`:

#### Database Configuration
```bash
# PostgreSQL
POSTGRES_USER=spark
POSTGRES_PASSWORD=<auto-generated>

# MySQL
MYSQL_USER=root
MYSQL_PASSWORD=<auto-generated>

# Redis (optional password)
REDIS_PASSWORD=<auto-generated>
```

#### Object Storage (MinIO)
```bash
MINIO_ROOT_USER=minioadmin
MINIO_ROOT_PASSWORD=<auto-generated>
OSS_ENDPOINT=http://minio:9000
```

#### Service Ports
```bash
EXPOSE_NGINX_PORT=80
EXPOSE_KAFKA_PORT=9092
EXPOSE_MINIO_PORT=9000
EXPOSE_MINIO_CONSOLE_PORT=9001
```

#### Application Settings
```bash
# Locale/Region
SERVICE_LOCATION=en  # English locale

# Domain
CONSOLE_DOMAIN=http://localhost

# Core Service Ports
CORE_TENANT_PORT=5052
CORE_DATABASE_PORT=7990
CORE_AGENT_PORT=17870
CORE_WORKFLOW_PORT=7880
# ... and more
```

#### iFLYTEK API Keys (Optional)

To enable AI model features, configure:

```bash
PLATFORM_APP_ID=your-app-id
PLATFORM_API_KEY=your-api-key
PLATFORM_API_SECRET=your-api-secret
SPARK_API_PASSWORD=your-api-password
```

Get these from: https://www.xfyun.cn/ (iFLYTEK Open Platform)

**Note:** Platform works without these, but AI features will be limited.

### Customizing Configuration

1. **Edit configuration:**
   ```bash
   cd docker/astronAgent
   nano .env
   ```

2. **Apply changes:**
   ```bash
   cd ~/astron-agent
   ./stop.sh
   ./start.sh
   ```

### Resource Limits

To adjust Docker resource limits for WSL2:

1. Create/edit `C:\Users\<YourUsername>\.wslconfig`:
   ```ini
   [wsl2]
   memory=16GB
   processors=4
   swap=8GB
   ```

2. Restart WSL2:
   ```powershell
   wsl --shutdown
   ```

---

## Accessing the Platform

### Web Interface

**URL:** http://localhost

**Features:**
- Agent workflow builder
- Knowledge base management
- Tool/plugin configuration
- Model management
- Monitoring dashboards

### MinIO Console

**URL:** http://localhost:9001

**Purpose:** Object storage management
- File uploads
- Bucket management
- Access policies

**Credentials:**
- Username: `minioadmin`
- Password: Check `.env` file (`MINIO_ROOT_PASSWORD`)

### Service APIs

Core services expose REST APIs:

| Service | Port | Endpoint |
|---------|------|----------|
| Tenant | 5052 | http://localhost:5052 |
| Database | 7990 | http://localhost:7990 |
| Agent | 17870 | http://localhost:17870 |
| Workflow | 7880 | http://localhost:7880 |
| Knowledge | 20010 | http://localhost:20010 |

**Note:** These are internal ports, access via Nginx at port 80 is recommended.

---

## Management Commands

### Check Service Status

```bash
./status.sh
```

Shows all running containers, their status, and ports.

**Example output:**
```
NAME                            STATUS                    PORTS
astron-agent-postgres           Up 10 minutes (healthy)   5432/tcp
astron-agent-mysql              Up 10 minutes (healthy)   3306/tcp
astron-agent-redis              Up 10 minutes (healthy)   6379/tcp
...
```

### View Logs

**All services:**
```bash
./logs.sh
```

**Specific service:**
```bash
./logs.sh nginx
./logs.sh core-agent
./logs.sh mysql
```

**Follow logs in real-time:**
```bash
./logs.sh -f nginx
```

### Stop Services

**Graceful shutdown:**
```bash
./stop.sh
```

Stops all containers without removing data.

### Restart Services

```bash
./stop.sh
./start.sh
```

Or restart specific service:
```bash
cd docker/astronAgent
docker compose restart core-agent
```

### Complete Cleanup

⚠️ **Warning:** This removes all containers and data!

```bash
./cleanup.sh
```

Prompts for confirmation, then:
- Stops all containers
- Removes containers
- Deletes volumes (all data!)
- Cleans up networks

To redeploy after cleanup:
```bash
./start.sh
```

### Update Platform

```bash
cd ~/astron-agent
git pull
./stop.sh
cd docker/astronAgent
docker compose pull  # Pull latest images
cd ~/astron-agent
./start.sh
```

---

## Troubleshooting

### Services Won't Start

**Check Docker status:**
```bash
docker info
systemctl status docker
```

**If Docker isn't running:**
```bash
sudo systemctl start docker
sudo systemctl enable docker
```

**Check service logs:**
```bash
./logs.sh [service-name]
```

### Port Already in Use

**Find process using port:**
```bash
sudo netstat -tlnp | grep :80
sudo lsof -i :80
```

**Kill process or change port in `.env`:**
```bash
cd docker/astronAgent
nano .env
# Change EXPOSE_NGINX_PORT=80 to different port
cd ~/astron-agent
./start.sh
```

### Out of Memory

**Check memory usage:**
```bash
docker stats
free -h
```

**Increase WSL2 memory:**
Edit `C:\Users\<YourUsername>\.wslconfig`:
```ini
[wsl2]
memory=16GB
```

Then restart WSL2:
```powershell
wsl --shutdown
```

### Database Connection Errors

**Check database is running:**
```bash
./status.sh | grep -E "(postgres|mysql)"
```

**Test database connection:**
```bash
cd docker/astronAgent
docker compose exec mysql mysqladmin ping
docker compose exec postgres pg_isready -U spark
```

**Reset databases:**
```bash
./stop.sh
cd docker/astronAgent
docker compose down -v postgres mysql  # Only remove DB volumes
cd ~/astron-agent
./start.sh
```

### Services Fail Health Checks

**Wait longer:**
Some services (especially Elasticsearch) can take 3-5 minutes to initialize.

**Check service logs:**
```bash
./logs.sh [service-name]
```

**Common causes:**
- Insufficient memory
- Disk space full
- Port conflicts
- Corrupted data volumes

**Solution - reset specific service:**
```bash
cd docker/astronAgent
docker compose down [service-name]
docker volume rm astron-agent_[service-name]_data
cd ~/astron-agent
./start.sh
```

### Can't Access Web Interface

**Check Nginx status:**
```bash
./status.sh | grep nginx
```

**Test Nginx directly:**
```bash
curl -I http://localhost
```

**Check Nginx logs:**
```bash
./logs.sh nginx
```

**Verify frontend is running:**
```bash
./status.sh | grep console
```

### Docker Permission Denied

**Add user to docker group:**
```bash
sudo usermod -aG docker $USER
newgrp docker
```

Or log out and back in.

### WSL2 Network Issues

**Reset WSL2 network:**

In PowerShell as Administrator:
```powershell
wsl --shutdown
netsh winsock reset
netsh int ip reset all
netsh winhttp reset proxy
```

Then restart WSL2.

### Elasticsearch Won't Start

**Increase virtual memory:**
```bash
sudo sysctl -w vm.max_map_count=262144
# Make permanent:
echo "vm.max_map_count=262144" | sudo tee -a /etc/sysctl.conf
```

**Check Elasticsearch logs:**
```bash
./logs.sh elasticsearch
```

---

## Advanced Configuration

### Enable HTTPS

1. **Generate SSL certificate:**
   ```bash
   cd docker/astronAgent/nginx
   openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
     -keyout server.key -out server.crt
   ```

2. **Update nginx.conf** to use SSL

3. **Update .env:**
   ```bash
   CONSOLE_DOMAIN=https://localhost
   ```

### External Database

To use external PostgreSQL/MySQL instead of containers:

1. **Edit `.env`:**
   ```bash
   POSTGRES_HOST=external-postgres-host
   POSTGRES_PORT=5432
   MYSQL_HOST=external-mysql-host
   MYSQL_PORT=3306
   ```

2. **Comment out postgres/mysql in docker-compose.yaml**

3. **Restart:**
   ```bash
   ./start.sh
   ```

### Custom Domain

1. **Update `.env`:**
   ```bash
   CONSOLE_DOMAIN=http://astron-agent.local
   ```

2. **Add to Windows hosts file:**
   `C:\Windows\System32\drivers\etc\hosts`
   ```
   127.0.0.1 astron-agent.local
   ```

3. **Restart services:**
   ```bash
   ./stop.sh
   ./start.sh
   ```

### Monitoring and Observability

Enable OpenTelemetry tracing:

```bash
# In .env
OTLP_ENABLE=1
OTLP_ENDPOINT=your-collector:4317
```

### Backup and Restore

**Backup volumes:**
```bash
cd docker/astronAgent
docker compose down
sudo tar -czf backup-$(date +%Y%m%d).tar.gz \
  -C /var/lib/docker/volumes/ \
  astron-agent_postgres_data \
  astron-agent_mysql_data \
  astron-agent_minio_data
```

**Restore volumes:**
```bash
./stop.sh
sudo tar -xzf backup-20250101.tar.gz -C /var/lib/docker/volumes/
./start.sh
```

### Performance Tuning

**Elasticsearch:**
```bash
# In .env
ES_JAVA_OPTS='-Xms2g -Xmx2g'  # Increase heap size
```

**Kafka:**
```bash
# In .env
KAFKA_REPLICATION_FACTOR=3  # For production
```

**Database connection pools:**
```bash
# In .env
DATABASE_MAX_OPEN_CONNS=20
DATABASE_MAX_IDLE_CONNS=10
```

---

## Security Considerations

### Change Default Passwords

The setup script generates random passwords, but you can change them:

1. **Edit `.env`** with strong passwords
2. **Restart services:**
   ```bash
   ./stop.sh
   ./start.sh
   ```

### Firewall Configuration

If exposing to network:

```bash
# Allow only specific IPs
sudo ufw allow from 192.168.1.0/24 to any port 80
sudo ufw enable
```

### Regular Updates

```bash
# Update system packages
sudo apt update && sudo apt upgrade -y

# Update Docker images
cd ~/astron-agent
./stop.sh
cd docker/astronAgent
docker compose pull
cd ~/astron-agent
./start.sh
```

---

## Support and Resources

- **Documentation:** https://github.com/iflytek/astron-agent/docs
- **Issues:** https://github.com/iflytek/astron-agent/issues
- **Discussions:** https://github.com/iflytek/astron-agent/discussions
- **iFLYTEK Platform:** https://www.xfyun.cn/

---

## License

This project is licensed under the Apache 2.0 License.

---

**Developed and maintained by iFLYTEK**

For questions or issues with this deployment guide, please open an issue on GitHub.
