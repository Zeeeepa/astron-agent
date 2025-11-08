#!/usr/bin/env python3
"""
Astron Agent Setup & Deployment Script

Consolidates all deployment logic from:
- deploy.sh
- validate-config.sh  
- lib/error-handler.sh

Usage:
    python3 setup.py install           # Full installation
    python3 setup.py configure         # Configure environment
    python3 setup.py verify            # Verify installation
    python3 setup.py uninstall         # Remove everything
"""

import os
import sys
import subprocess
import shutil
import json
import time
import hashlib
import secrets
from pathlib import Path
from typing import Dict, List, Optional, Tuple
from dataclasses import dataclass, field

# Minimum versions
MIN_PYTHON_VERSION = (3, 8)
MIN_DOCKER_VERSION = "20.10"

@dataclass
class SystemRequirements:
    """System requirements for deployment"""
    min_disk_gb: int = 20
    min_memory_gb: int = 4
    min_cpu_cores: int = 2
    required_ports: List[int] = field(default_factory=lambda: [80, 8000, 3306, 6379])
    
@dataclass
class Configuration:
    """Application configuration"""
    app_name: str = "astron-agent"
    app_env: str = "production"
    debug: bool = False
    
    # Ports
    nginx_port: int = 80
    api_port: int = 8000
    web_port: int = 3000
    mysql_port: int = 3306
    redis_port: int = 6379
    
    # Database
    mysql_root_password: str = ""
    mysql_database: str = "astron_db"
    mysql_user: str = "astron_user"
    mysql_password: str = ""
    
    # Redis
    redis_password: str = ""
    
    # Security
    secret_key: str = ""
    jwt_secret: str = ""
    session_secret: str = ""
    
    # Optional: AI Integration
    anthropic_token: str = ""
    anthropic_url: str = ""
    openai_key: str = ""
    
    # Optional: OAuth2
    oauth_client_id: str = ""
    oauth_client_secret: str = ""
    oauth_redirect_uri: str = ""
    
    # Paths
    backup_dir: Path = Path("./backups")
    log_dir: Path = Path("./logs")
    data_dir: Path = Path("./data")


class Colors:
    """Terminal colors"""
    RED = "\033[0;31m"
    GREEN = "\033[0;32m"
    YELLOW = "\033[1;33m"
    BLUE = "\033[0;34m"
    CYAN = "\033[0;36m"
    NC = "\033[0m"  # No Color


class Logger:
    """Logging utility"""
    
    @staticmethod
    def info(msg: str):
        print(f"{Colors.CYAN}[INFO]{Colors.NC} {msg}")
    
    @staticmethod
    def success(msg: str):
        print(f"{Colors.GREEN}[SUCCESS]{Colors.NC} {msg}")
    
    @staticmethod
    def warning(msg: str):
        print(f"{Colors.YELLOW}[WARNING]{Colors.NC} {msg}")
    
    @staticmethod
    def error(msg: str):
        print(f"{Colors.RED}[ERROR]{Colors.NC} {msg}")
    
    @staticmethod
    def step(step: int, total: int, msg: str):
        print(f"{Colors.BLUE}[{step}/{total}]{Colors.NC} {msg}")


class SystemChecker:
    """System requirements checker"""
    
    def __init__(self, requirements: SystemRequirements):
        self.requirements = requirements
        self.errors: List[str] = []
        self.warnings: List[str] = []
    
    def check_python_version(self) -> bool:
        """Check Python version"""
        if sys.version_info < MIN_PYTHON_VERSION:
            self.errors.append(
                f"Python {MIN_PYTHON_VERSION[0]}.{MIN_PYTHON_VERSION[1]}+ required. "
                f"Current: {sys.version_info.major}.{sys.version_info.minor}"
            )
            return False
        return True
    
    def check_docker(self) -> bool:
        """Check Docker installation"""
        try:
            result = subprocess.run(
                ["docker", "--version"],
                capture_output=True,
                text=True,
                check=True
            )
            Logger.success(f"Docker found: {result.stdout.strip()}")
            return True
        except (subprocess.CalledProcessError, FileNotFoundError):
            self.errors.append("Docker not installed or not in PATH")
            return False
    
    def check_docker_compose(self) -> bool:
        """Check Docker Compose installation"""
        try:
            result = subprocess.run(
                ["docker-compose", "--version"],
                capture_output=True,
                text=True,
                check=True
            )
            Logger.success(f"Docker Compose found: {result.stdout.strip()}")
            return True
        except (subprocess.CalledProcessError, FileNotFoundError):
            self.errors.append("Docker Compose not installed or not in PATH")
            return False
    
    def check_ports(self) -> bool:
        """Check if required ports are available"""
        import socket
        
        all_available = True
        for port in self.requirements.required_ports:
            sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
            result = sock.connect_ex(('localhost', port))
            sock.close()
            
            if result == 0:
                self.warnings.append(f"Port {port} is already in use")
                all_available = False
            else:
                Logger.info(f"Port {port} is available")
        
        return all_available
    
    def check_disk_space(self) -> bool:
        """Check available disk space"""
        stat = shutil.disk_usage(".")
        available_gb = stat.free / (1024**3)
        
        if available_gb < self.requirements.min_disk_gb:
            self.errors.append(
                f"Insufficient disk space. Required: {self.requirements.min_disk_gb}GB, "
                f"Available: {available_gb:.1f}GB"
            )
            return False
        
        Logger.success(f"Disk space: {available_gb:.1f}GB available")
        return True
    
    def check_all(self) -> bool:
        """Run all checks"""
        Logger.info("Running system requirements checks...")
        
        checks = [
            self.check_python_version(),
            self.check_docker(),
            self.check_docker_compose(),
            self.check_ports(),
            self.check_disk_space()
        ]
        
        if self.warnings:
            Logger.warning(f"Found {len(self.warnings)} warnings:")
            for warning in self.warnings:
                Logger.warning(f"  - {warning}")
        
        if self.errors:
            Logger.error(f"Found {len(self.errors)} errors:")
            for error in self.errors:
                Logger.error(f"  - {error}")
            return False
        
        Logger.success("All system requirements checks passed!")
        return True


class ConfigGenerator:
    """Configuration file generator"""
    
    def __init__(self, config: Configuration):
        self.config = config
    
    def prompt_user_input(self, interactive: bool = True):
        """Prompt user for configuration values"""
        if not interactive:
            self.generate_secrets()
            return
        
        Logger.info("=" * 60)
        Logger.info("Interactive Configuration Setup")
        Logger.info("=" * 60)
        print()
        
        # Application Settings
        Logger.info("📦 Application Settings")
        print("-" * 60)
        
        app_name = input(f"Application name [{self.config.app_name}]: ").strip()
        if app_name:
            self.config.app_name = app_name
        
        app_env = input(f"Environment (production/development/staging) [{self.config.app_env}]: ").strip()
        if app_env:
            self.config.app_env = app_env
        
        debug = input(f"Enable debug mode? (yes/no) [no]: ").strip().lower()
        self.config.debug = debug in ['yes', 'y', 'true']
        print()
        
        # Port Configuration
        Logger.info("🔌 Port Configuration")
        print("-" * 60)
        
        nginx_port = input(f"Nginx port [{self.config.nginx_port}]: ").strip()
        if nginx_port:
            self.config.nginx_port = int(nginx_port)
        
        api_port = input(f"API port [{self.config.api_port}]: ").strip()
        if api_port:
            self.config.api_port = int(api_port)
        
        web_port = input(f"Web UI port [{self.config.web_port}]: ").strip()
        if web_port:
            self.config.web_port = int(web_port)
        print()
        
        # Database Configuration
        Logger.info("🗄️  Database Configuration")
        print("-" * 60)
        
        mysql_database = input(f"Database name [{self.config.mysql_database}]: ").strip()
        if mysql_database:
            self.config.mysql_database = mysql_database
        
        mysql_user = input(f"Database user [{self.config.mysql_user}]: ").strip()
        if mysql_user:
            self.config.mysql_user = mysql_user
        
        # Password prompts
        print()
        Logger.info("🔐 Password Configuration")
        print("-" * 60)
        Logger.warning("Leave passwords blank to auto-generate secure random passwords")
        print()
        
        mysql_root_password = input("MySQL root password [auto-generate]: ").strip()
        if mysql_root_password:
            self.config.mysql_root_password = mysql_root_password
        else:
            self.config.mysql_root_password = secrets.token_urlsafe(24)
            Logger.success(f"Auto-generated MySQL root password")
        
        mysql_password = input("MySQL user password [auto-generate]: ").strip()
        if mysql_password:
            self.config.mysql_password = mysql_password
        else:
            self.config.mysql_password = secrets.token_urlsafe(24)
            Logger.success(f"Auto-generated MySQL user password")
        
        redis_password = input("Redis password [auto-generate]: ").strip()
        if redis_password:
            self.config.redis_password = redis_password
        else:
            self.config.redis_password = secrets.token_urlsafe(24)
            Logger.success(f"Auto-generated Redis password")
        print()
        
        # Security Keys
        Logger.info("🔑 Security Keys")
        print("-" * 60)
        Logger.warning("Leave blank to auto-generate secure random keys (RECOMMENDED)")
        print()
        
        secret_key = input("Application secret key [auto-generate]: ").strip()
        if secret_key:
            self.config.secret_key = secret_key
        else:
            self.config.secret_key = secrets.token_urlsafe(32)
            Logger.success(f"Auto-generated application secret key")
        
        jwt_secret = input("JWT secret key [auto-generate]: ").strip()
        if jwt_secret:
            self.config.jwt_secret = jwt_secret
        else:
            self.config.jwt_secret = secrets.token_urlsafe(32)
            Logger.success(f"Auto-generated JWT secret key")
        
        session_secret = input("Session secret key [auto-generate]: ").strip()
        if session_secret:
            self.config.session_secret = session_secret
        else:
            self.config.session_secret = secrets.token_urlsafe(32)
            Logger.success(f"Auto-generated session secret key")
        print()
        
        # Optional: AI Integration
        Logger.info("🤖 AI Integration (OPTIONAL)")
        print("-" * 60)
        Logger.info("Configure AI providers for error resolution and automation")
        print()
        
        configure_ai = input("Configure AI integration? (yes/no) [no]: ").strip().lower()
        if configure_ai in ['yes', 'y']:
            print()
            anthropic_token = input("Anthropic API token (optional): ").strip()
            if anthropic_token:
                self.config.anthropic_token = anthropic_token
            
            anthropic_url = input("Anthropic base URL (optional) [https://api.z.ai/api/anthropic]: ").strip()
            if anthropic_url:
                self.config.anthropic_url = anthropic_url
            elif hasattr(self.config, 'anthropic_token') and self.config.anthropic_token:
                self.config.anthropic_url = "https://api.z.ai/api/anthropic"
            
            openai_key = input("OpenAI API key (optional): ").strip()
            if openai_key:
                self.config.openai_key = openai_key
        print()
        
        # Optional: OAuth2
        Logger.info("🔐 OAuth2 Configuration (OPTIONAL)")
        print("-" * 60)
        Logger.info("Configure OAuth2 for external authentication")
        print()
        
        configure_oauth = input("Configure OAuth2? (yes/no) [no]: ").strip().lower()
        if configure_oauth in ['yes', 'y']:
            print()
            oauth_client_id = input("OAuth2 Client ID (optional): ").strip()
            if oauth_client_id:
                self.config.oauth_client_id = oauth_client_id
            
            oauth_client_secret = input("OAuth2 Client Secret (optional): ").strip()
            if oauth_client_secret:
                self.config.oauth_client_secret = oauth_client_secret
            
            oauth_redirect = input("OAuth2 Redirect URI (optional) [http://localhost/auth/callback]: ").strip()
            if oauth_redirect:
                self.config.oauth_redirect_uri = oauth_redirect
            elif hasattr(self.config, 'oauth_client_id'):
                self.config.oauth_redirect_uri = "http://localhost/auth/callback"
        print()
        
        Logger.success("Configuration input complete!")
        print()
    
    def generate_secrets(self):
        """Generate secure random secrets"""
        if not self.config.secret_key:
            self.config.secret_key = secrets.token_urlsafe(32)
        if not self.config.jwt_secret:
            self.config.jwt_secret = secrets.token_urlsafe(32)
        if not self.config.session_secret:
            self.config.session_secret = secrets.token_urlsafe(32)
        if not self.config.mysql_root_password:
            self.config.mysql_root_password = secrets.token_urlsafe(24)
        if not self.config.mysql_password:
            self.config.mysql_password = secrets.token_urlsafe(24)
        if not self.config.redis_password:
            self.config.redis_password = secrets.token_urlsafe(24)
    
    def generate_env_file(self) -> str:
        """Generate .env file content"""
        env_content = f"""# Astron Agent Configuration
# Generated by setup.py

# Application Settings
APP_NAME={self.config.app_name}
APP_ENV={self.config.app_env}
DEBUG={str(self.config.debug).lower()}
LOG_LEVEL=INFO

# Server Configuration
API_HOST=0.0.0.0
API_PORT={self.config.api_port}
WEB_PORT={self.config.web_port}
NGINX_PORT={self.config.nginx_port}

# Database Configuration
MYSQL_ROOT_PASSWORD={self.config.mysql_root_password}
MYSQL_DATABASE={self.config.mysql_database}
MYSQL_USER={self.config.mysql_user}
MYSQL_PASSWORD={self.config.mysql_password}
MYSQL_HOST=mysql
MYSQL_PORT={self.config.mysql_port}

# Redis Configuration
REDIS_HOST=redis
REDIS_PORT={self.config.redis_port}
REDIS_PASSWORD={self.config.redis_password}

# Security Settings
SECRET_KEY={self.config.secret_key}
JWT_SECRET={self.config.jwt_secret}
SESSION_SECRET={self.config.session_secret}
"""
        
        # Add optional AI Integration
        if self.config.anthropic_token or self.config.openai_key:
            env_content += """
# AI Integration (Optional)"""
            if self.config.anthropic_token:
                env_content += f"""
ANTHROPIC_AUTH_TOKEN={self.config.anthropic_token}"""
            if self.config.anthropic_url:
                env_content += f"""
ANTHROPIC_BASE_URL={self.config.anthropic_url}"""
            if self.config.openai_key:
                env_content += f"""
OPENAI_API_KEY={self.config.openai_key}"""
            env_content += "\n"
        
        # Add optional OAuth2
        if self.config.oauth_client_id:
            env_content += f"""
# OAuth2 Configuration (Optional)
OAUTH2_CLIENT_ID={self.config.oauth_client_id}"""
            if self.config.oauth_client_secret:
                env_content += f"""
OAUTH2_CLIENT_SECRET={self.config.oauth_client_secret}"""
            if self.config.oauth_redirect_uri:
                env_content += f"""
OAUTH2_REDIRECT_URI={self.config.oauth_redirect_uri}"""
            env_content += "\n"
        
        # Add advanced configuration
        env_content += f"""
# Circuit Breaker Configuration
CIRCUIT_THRESHOLD=5
CIRCUIT_TIMEOUT=60

# Retry Configuration
RETRY_MAX_DELAY=60
RETRY_INITIAL_DELAY=1
RETRY_MULTIPLIER=2

# Backup Configuration
BACKUP_DIR={self.config.backup_dir}
BACKUP_RETENTION_DAYS=30
AUTO_BACKUP_ENABLED=true
"""
        
        return env_content
    
    def write_env_file(self, path: Path = Path(".env")):
        """Write .env file"""
        self.generate_secrets()
        content = self.generate_env_file()
        
        # Backup existing
        if path.exists():
            backup_path = path.with_suffix(".env.backup")
            shutil.copy(path, backup_path)
            Logger.info(f"Backed up existing .env to {backup_path}")
        
        with open(path, 'w') as f:
            f.write(content)
        
        # Set permissions (readable only by owner)
        os.chmod(path, 0o600)
        Logger.success(f"Created {path} with secure permissions")


class DockerManager:
    """Docker operations manager"""
    
    @staticmethod
    def pull_images():
        """Pull required Docker images"""
        images = [
            "nginx:latest",
            "mysql:8.0",
            "redis:7-alpine",
            "python:3.10-slim"
        ]
        
        Logger.info("Pulling Docker images...")
        for image in images:
            Logger.info(f"Pulling {image}...")
            try:
                subprocess.run(
                    ["docker", "pull", image],
                    check=True,
                    capture_output=True
                )
                Logger.success(f"Pulled {image}")
            except subprocess.CalledProcessError as e:
                Logger.error(f"Failed to pull {image}: {e}")
                return False
        
        return True
    
    @staticmethod
    def create_network():
        """Create Docker network"""
        try:
            subprocess.run(
                ["docker", "network", "create", "astron-network"],
                capture_output=True
            )
            Logger.success("Created Docker network: astron-network")
            return True
        except subprocess.CalledProcessError:
            Logger.info("Docker network astron-network already exists")
            return True
    
    @staticmethod
    def build_images():
        """Build custom Docker images"""
        Logger.info("Building Docker images...")
        try:
            subprocess.run(
                ["docker-compose", "build"],
                check=True
            )
            Logger.success("Built Docker images")
            return True
        except subprocess.CalledProcessError as e:
            Logger.error(f"Failed to build images: {e}")
            return False


class Installer:
    """Main installation orchestrator"""
    
    def __init__(self):
        self.requirements = SystemRequirements()
        self.config = Configuration()
        self.checker = SystemChecker(self.requirements)
    
    def install(self) -> bool:
        """Run full installation"""
        Logger.info("=" * 60)
        Logger.info("Astron Agent Installation")
        Logger.info("=" * 60)
        
        # Step 1: Check system requirements
        Logger.step(1, 6, "Checking system requirements...")
        if not self.checker.check_all():
            Logger.error("System requirements not met. Installation aborted.")
            return False
        
        # Step 2: Create directories
        Logger.step(2, 6, "Creating directories...")
        self.create_directories()
        
        # Step 3: Generate configuration
        Logger.step(3, 6, "Generating configuration...")
        config_gen = ConfigGenerator(self.config)
        config_gen.write_env_file()
        
        # Step 4: Setup Docker
        Logger.step(4, 6, "Setting up Docker...")
        docker_mgr = DockerManager()
        if not docker_mgr.create_network():
            return False
        if not docker_mgr.pull_images():
            return False
        
        # Step 5: Build images
        Logger.step(5, 6, "Building Docker images...")
        if not docker_mgr.build_images():
            return False
        
        # Step 6: Verify installation
        Logger.step(6, 6, "Verifying installation...")
        self.verify_installation()
        
        Logger.success("=" * 60)
        Logger.success("Installation completed successfully!")
        Logger.success("=" * 60)
        Logger.info("")
        Logger.info("Next steps:")
        Logger.info("  1. Review configuration: nano .env")
        Logger.info("  2. Start services: python3 manage.py start")
        Logger.info("  3. Check status: python3 manage.py status")
        Logger.info("")
        
        return True
    
    def create_directories(self):
        """Create required directories"""
        dirs = [
            self.config.backup_dir,
            self.config.log_dir,
            self.config.data_dir,
            Path("./data/mysql"),
            Path("./data/redis"),
            Path("./docker/nginx/conf.d"),
            Path("./docker/nginx/ssl")
        ]
        
        for dir_path in dirs:
            dir_path.mkdir(parents=True, exist_ok=True)
            Logger.info(f"Created directory: {dir_path}")
    
    def verify_installation(self) -> bool:
        """Verify installation"""
        checks = [
            (".env", "Configuration file"),
            ("docker-compose.yml", "Docker Compose file"),
            (self.config.backup_dir, "Backup directory"),
            (self.config.log_dir, "Log directory")
        ]
        
        all_ok = True
        for path_str, desc in checks:
            path = Path(path_str)
            if path.exists():
                Logger.success(f"{desc}: ✓")
            else:
                Logger.error(f"{desc}: ✗")
                all_ok = False
        
        return all_ok
    
    def uninstall(self):
        """Uninstall everything"""
        Logger.warning("This will remove ALL data and containers!")
        response = input("Are you sure? (yes/no): ")
        
        if response.lower() != "yes":
            Logger.info("Uninstall cancelled")
            return
        
        Logger.info("Stopping containers...")
        subprocess.run(["docker-compose", "down", "-v"], capture_output=True)
        
        Logger.info("Removing Docker network...")
        subprocess.run(["docker", "network", "rm", "astron-network"], capture_output=True)
        
        Logger.info("Removing data directories...")
        dirs_to_remove = ["data", "logs"]
        for dir_name in dirs_to_remove:
            if Path(dir_name).exists():
                shutil.rmtree(dir_name)
                Logger.info(f"Removed {dir_name}/")
        
        Logger.success("Uninstall completed")


def main():
    """Main entry point"""
    if len(sys.argv) < 2:
        print("Usage: python3 setup.py [install|configure|verify|uninstall]")
        print("")
        print("Commands:")
        print("  install     - Full installation")
        print("  configure   - Configure environment")
        print("  verify      - Verify installation")
        print("  uninstall   - Remove everything")
        sys.exit(1)
    
    command = sys.argv[1]
    installer = Installer()
    
    if command == "install":
        success = installer.install()
        sys.exit(0 if success else 1)
    
    elif command == "configure":
        Logger.info("Starting interactive configuration...")
        print()
        config_gen = ConfigGenerator(installer.config)
        config_gen.prompt_user_input(interactive=True)
        config_gen.write_env_file()
        Logger.success("Configuration saved to .env file!")
        sys.exit(0)
    
    elif command == "verify":
        Logger.info("Verifying installation...")
        if installer.verify_installation():
            Logger.success("Verification passed!")
            sys.exit(0)
        else:
            Logger.error("Verification failed!")
            sys.exit(1)
    
    elif command == "uninstall":
        installer.uninstall()
        sys.exit(0)
    
    else:
        Logger.error(f"Unknown command: {command}")
        sys.exit(1)


if __name__ == "__main__":
    main()
