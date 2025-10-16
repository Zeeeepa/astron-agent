# 🚀 Astron Deployment Scripts

Three professional deployment scripts for the Astron platform ecosystem, based on the official repository documentation and Docker configurations.

## 📋 Available Scripts

### 1. `deploy-astron-agent.sh` - AI Agent Platform
Deploy the enterprise-grade AI agent development platform with full microservices architecture.

**Features:**
- ✅ 9 core services (tenant, memory, agent, knowledge, workflow, etc.)
- ✅ Complete infrastructure (PostgreSQL, MySQL, Redis, Elasticsearch, Kafka, MinIO)
- ✅ Optional Casdoor authentication integration
- ✅ Optional RagFlow knowledge base integration
- ✅ Production-ready with health checks and monitoring

**Usage:**
```bash
# Basic deployment
./deploy-astron-agent.sh

# With authentication and knowledge base
./deploy-astron-agent.sh --with-casdoor --with-ragflow

# Production mode
./deploy-astron-agent.sh --production --skip-aliases
```

**Access URLs:**
- 🖥️ Console Frontend: http://localhost:1881
- 🔧 Console Hub API: http://localhost:8080
- 🤖 Agent Core: http://localhost:17870
- 🔄 Workflow Service: http://localhost:7880
- 🧠 Knowledge Service: http://localhost:20010

### 2. `deploy-astron-rpa.sh` - RPA Automation Platform
Deploy the robotic process automation platform with AI-powered automation capabilities.

**Features:**
- ✅ 5 core RPA services (AI, OpenAPI, Resource, Robot, Frontend)
- ✅ Complete infrastructure (MySQL, Redis, MinIO)
- ✅ AI-powered automation with DeepSeek integration
- ✅ Visual process designer and execution monitoring
- ✅ Development tools support (Node.js, Python, Java)

**Usage:**
```bash
# Basic deployment
./deploy-astron-rpa.sh

# Production mode
./deploy-astron-rpa.sh --production

# Skip development tools
./deploy-astron-rpa.sh --production --skip-aliases
```

**Access URLs:**
- 🖥️ RPA Frontend: http://localhost:8080
- 🤖 AI Service: http://localhost:8010
- 🔧 OpenAPI Service: http://localhost:8020
- 📊 Resource Service: http://localhost:8030
- 🤖 Robot Service: http://localhost:8040
- 📖 API Documentation: http://localhost:8020/docs

### 3. `deploy-unified.sh` - Complete Platform Integration
Deploy both platforms together with proper integration and shared infrastructure.

**Features:**
- ✅ Full platform integration (Agent + RPA)
- ✅ Shared Docker networks for inter-service communication
- ✅ Unified management commands and aliases
- ✅ Flexible deployment options (both, agent-only, rpa-only)
- ✅ Optimized resource allocation and port management

**Usage:**
```bash
# Deploy both platforms (recommended)
./deploy-unified.sh

# Deploy only astron-agent
./deploy-unified.sh --agent-only

# Deploy only astron-rpa
./deploy-unified.sh --rpa-only

# Full deployment with all features
./deploy-unified.sh --with-casdoor --with-ragflow --production
```

## 🛠️ Common Options

All scripts support these common options:

| Option | Description |
|--------|-------------|
| `--skip-deps` | Skip system dependency checks |
| `--force-recreate` | Force recreate all containers |
| `--skip-docker` | Skip Docker installation |
| `--skip-aliases` | Skip shell alias setup |
| `--production` | Enable production mode |
| `--help` | Show detailed help message |

## 📋 System Requirements

### Minimum Requirements
- **OS:** Linux, macOS, or Windows (WSL/Git Bash)
- **Docker:** 20.10+ with Docker Compose
- **Memory:** 4GB+ RAM (8GB+ for Agent, 12GB+ for both)
- **Disk:** 10GB+ free space (20GB+ for Agent, 30GB+ for both)
- **Network:** Stable internet connection for image downloads

### Recommended Requirements
- **Memory:** 16GB+ RAM for optimal performance
- **Disk:** 50GB+ SSD storage
- **CPU:** 4+ cores
- **Network:** High-speed internet for faster deployment

## 🚀 Quick Start

### Option 1: Full Platform (Recommended)
```bash
# Download and run unified deployment
curl -fsSL https://raw.githubusercontent.com/Zeeeepa/astron-agent/main/deploy-unified.sh -o deploy-unified.sh
chmod +x deploy-unified.sh
./deploy-unified.sh
```

### Option 2: Agent Only
```bash
# Download and run agent deployment
curl -fsSL https://raw.githubusercontent.com/Zeeeepa/astron-agent/main/deploy-astron-agent.sh -o deploy-astron-agent.sh
chmod +x deploy-astron-agent.sh
./deploy-astron-agent.sh
```

### Option 3: RPA Only
```bash
# Download and run RPA deployment
curl -fsSL https://raw.githubusercontent.com/Zeeeepa/astron-agent/main/deploy-astron-rpa.sh -o deploy-astron-rpa.sh
chmod +x deploy-astron-rpa.sh
./deploy-astron-rpa.sh
```

## 🔧 Management Commands

After deployment, use these aliases for easy management:

### Unified Commands (deploy-unified.sh)
```bash
astron-status        # Check all services status
astron-console       # Show all access URLs
astron-start-all     # Start all services
astron-stop-all      # Stop all services
astron-restart-all   # Restart all services

# Platform-specific commands
astron-rpa-*         # RPA specific commands
astron-agent-*       # Agent specific commands
```

### Agent Commands (deploy-astron-agent.sh)
```bash
astron-status        # Check service status
astron-logs          # View service logs
astron-start         # Start all services
astron-stop          # Stop all services
astron-restart       # Restart all services
astron-console       # Show console URLs
```

### RPA Commands (deploy-astron-rpa.sh)
```bash
rpa-status           # Check service status
rpa-logs             # View service logs
rpa-start            # Start all services
rpa-stop             # Stop all services
rpa-restart          # Restart all services
rpa-console          # Show console URLs
rpa-ai               # Test AI service
rpa-api              # Test API service
```

## 🔍 Troubleshooting

### Common Issues

#### 1. Docker Not Running
```bash
# Start Docker daemon
sudo systemctl start docker  # Linux
# or restart Docker Desktop on Windows/Mac
```

#### 2. Port Conflicts
```bash
# Check what's using the port
netstat -tlnp | grep :8080

# Stop conflicting services or modify .env files
```

#### 3. Memory Issues
```bash
# Check memory usage
free -h

# Stop unnecessary services
docker system prune -f
```

#### 4. Image Pull Failures
```bash
# Check network connectivity
docker pull hello-world

# Try with different registry mirrors
# Edit /etc/docker/daemon.json
```

### Getting Help

1. **Check logs:** Use the `*-logs` aliases to view service logs
2. **Verify status:** Use the `*-status` aliases to check service health
3. **Restart services:** Use the `*-restart` aliases to restart problematic services
4. **Clean restart:** Stop all services, run `docker system prune -f`, then start again

## 📚 Architecture Overview

### astron-agent Architecture
```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│  Console Web    │    │   Agent Core    │    │   Knowledge     │
│   (Port 1881)   │    │  (Port 17870)   │    │  (Port 20010)   │
└─────────────────┘    └─────────────────┘    └─────────────────┘
         │                       │                       │
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│  Console Hub    │    │   Workflow      │    │    Memory       │
│   (Port 8080)   │    │  (Port 7880)    │    │  (Port 7990)    │
└─────────────────┘    └─────────────────┘    └─────────────────┘
         │                       │                       │
┌─────────────────────────────────────────────────────────────────┐
│              Infrastructure Layer                               │
│  PostgreSQL │ MySQL │ Redis │ Elasticsearch │ Kafka │ MinIO   │
└─────────────────────────────────────────────────────────────────┘
```

### astron-rpa Architecture
```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   RPA Frontend  │    │   AI Service    │    │  OpenAPI Svc    │
│   (Port 8080)   │    │  (Port 8010)    │    │  (Port 8020)    │
└─────────────────┘    └─────────────────┘    └─────────────────┘
         │                       │                       │
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│ Resource Service│    │  Robot Service  │    │                 │
│   (Port 8030)   │    │  (Port 8040)    │    │                 │
└─────────────────┘    └─────────────────┘    └─────────────────┘
         │                       │                       │
┌─────────────────────────────────────────────────────────────────┐
│              Infrastructure Layer                               │
│           MySQL │ Redis │ MinIO                                │
└─────────────────────────────────────────────────────────────────┘
```

### Unified Integration
```
┌─────────────────────────────────────────────────────────────────┐
│                    astron-agent Platform                       │
│  Console │ Agent Core │ Workflow │ Knowledge │ Memory │ etc.   │
└─────────────────────────────────────────────────────────────────┘
                                │
                    ┌───────────┴───────────┐
                    │   Integration Layer   │
                    │   (Docker Networks)   │
                    └───────────┬───────────┘
                                │
┌─────────────────────────────────────────────────────────────────┐
│                     astron-rpa Platform                        │
│    Frontend │ AI Service │ OpenAPI │ Resource │ Robot          │
└─────────────────────────────────────────────────────────────────┘
```

## 🎯 Use Cases

### Enterprise AI Development
- **Agent Platform:** Build sophisticated AI agents with workflow orchestration
- **Knowledge Integration:** Connect agents to enterprise knowledge bases
- **Multi-tenant Support:** Manage multiple agent deployments

### Process Automation
- **RPA Platform:** Automate repetitive business processes
- **AI-Powered Automation:** Use AI for intelligent decision making
- **Visual Design:** Create automation workflows with drag-and-drop interface

### Integrated AI + RPA
- **Complete Automation:** Combine AI reasoning with RPA execution
- **End-to-End Workflows:** From decision making to action execution
- **Enterprise Scale:** Production-ready platform for large organizations

## 📄 License

These deployment scripts are provided as-is for the Astron platform ecosystem. Please refer to the individual project repositories for their respective licenses:

- [astron-agent](https://github.com/Zeeeepa/astron-agent)
- [astron-rpa](https://github.com/Zeeeepa/astron-rpa)

## 🤝 Contributing

To improve these deployment scripts:

1. Fork the repository
2. Create a feature branch
3. Make your improvements
4. Test thoroughly
5. Submit a pull request

## 📞 Support

For issues with these deployment scripts:
1. Check the troubleshooting section above
2. Review the logs using the provided aliases
3. Open an issue in the respective repository
4. Join the community discussions

---

**🚀 Ready to deploy? Choose your script and get started with the Astron platform!**
