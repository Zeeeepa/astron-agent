#!/usr/bin/env python3
"""
Astron Agent Management Script

Consolidates all operational commands from:
- start.sh, stop.sh, status.sh, logs.sh
- update.sh, rollback.sh, validate-config.sh

Usage:
    python3 manage.py start           # Start all services
    python3 manage.py stop            # Stop all services
    python3 manage.py status          # Show status
    python3 manage.py logs            # View logs
    python3 manage.py update          # Update system
    python3 manage.py rollback        # Rollback to previous version
    python3 manage.py validate        # Validate configuration
"""

import os
import sys
import subprocess
import json
import time
import shutil
from pathlib import Path
from datetime import datetime
from typing import List, Dict, Optional

class Colors:
    """Terminal colors"""
    RED = "\033[0;31m"
    GREEN = "\033[0;32m"
    YELLOW = "\033[1;33m"
    BLUE = "\033[0;34m"
    CYAN = "\033[0;36m"
    NC = "\033[0m"

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

class DockerService:
    """Docker service management"""
    
    @staticmethod
    def get_containers() -> List[Dict]:
        """Get all project containers"""
        try:
            result = subprocess.run(
                ["docker", "ps", "-a", "--format", "{{json .}}"],
                capture_output=True,
                text=True,
                check=True
            )
            containers = []
            for line in result.stdout.strip().split('\n'):
                if line:
                    containers.append(json.loads(line))
            return containers
        except:
            return []
    
    @staticmethod
    def start_services():
        """Start all services"""
        Logger.info("Starting services...")
        try:
            subprocess.run(
                ["docker-compose", "up", "-d"],
                check=True
            )
            Logger.success("Services started successfully")
            return True
        except subprocess.CalledProcessError as e:
            Logger.error(f"Failed to start services: {e}")
            return False
    
    @staticmethod
    def stop_services():
        """Stop all services"""
        Logger.info("Stopping services...")
        try:
            subprocess.run(
                ["docker-compose", "down"],
                check=True
            )
            Logger.success("Services stopped successfully")
            return True
        except subprocess.CalledProcessError as e:
            Logger.error(f"Failed to stop services: {e}")
            return False
    
    @staticmethod
    def restart_services():
        """Restart all services"""
        Logger.info("Restarting services...")
        DockerService.stop_services()
        time.sleep(2)
        return DockerService.start_services()
    
    @staticmethod
    def show_status():
        """Show service status"""
        containers = DockerService.get_containers()
        
        if not containers:
            Logger.warning("No containers found")
            return
        
        print(f"\n{'Service':<20} {'Status':<15} {'Ports'}")
        print("=" * 60)
        
        for container in containers:
            name = container.get('Names', 'Unknown')
            status = container.get('Status', 'Unknown')
            ports = container.get('Ports', '')
            
            # Color code status
            if 'Up' in status:
                status_color = Colors.GREEN
            elif 'Exited' in status:
                status_color = Colors.RED
            else:
                status_color = Colors.YELLOW
            
            print(f"{name:<20} {status_color}{status:<15}{Colors.NC} {ports}")
        
        print()
    
    @staticmethod
    def show_logs(service: Optional[str] = None, follow: bool = False, tail: int = 100):
        """Show service logs"""
        cmd = ["docker-compose", "logs"]
        
        if follow:
            cmd.append("-f")
        
        cmd.extend(["--tail", str(tail)])
        
        if service:
            cmd.append(service)
        
        try:
            subprocess.run(cmd)
        except KeyboardInterrupt:
            Logger.info("\nStopped following logs")

class BackupManager:
    """Backup and restore management"""
    
    def __init__(self, backup_dir: Path = Path("./backups")):
        self.backup_dir = backup_dir
        self.backup_dir.mkdir(parents=True, exist_ok=True)
    
    def create_backup(self, tag: str = "") -> Optional[str]:
        """Create a backup"""
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        backup_name = f"backup_{timestamp}"
        if tag:
            backup_name += f"_{tag}"
        
        backup_path = self.backup_dir / backup_name
        backup_path.mkdir(parents=True, exist_ok=True)
        
        Logger.info(f"Creating backup: {backup_name}")
        
        # Backup .env
        if Path(".env").exists():
            shutil.copy(".env", backup_path / ".env")
            Logger.info("  - Backed up .env")
        
        # Backup docker-compose.yml
        if Path("docker-compose.yml").exists():
            shutil.copy("docker-compose.yml", backup_path / "docker-compose.yml")
            Logger.info("  - Backed up docker-compose.yml")
        
        # Backup database
        try:
            subprocess.run(
                ["docker-compose", "exec", "-T", "mysql", "mysqldump",
                 "-u", "root", "-p${MYSQL_ROOT_PASSWORD}",
                 "astron_db"],
                stdout=open(backup_path / "database.sql", 'w'),
                check=True
            )
            Logger.info("  - Backed up database")
        except:
            Logger.warning("  - Database backup failed (container may be down)")
        
        Logger.success(f"Backup created: {backup_name}")
        return backup_name
    
    def list_backups(self) -> List[str]:
        """List available backups"""
        if not self.backup_dir.exists():
            return []
        
        backups = [d.name for d in self.backup_dir.iterdir() if d.is_dir()]
        backups.sort(reverse=True)
        return backups
    
    def restore_backup(self, backup_name: str) -> bool:
        """Restore from backup"""
        backup_path = self.backup_dir / backup_name
        
        if not backup_path.exists():
            Logger.error(f"Backup not found: {backup_name}")
            return False
        
        Logger.info(f"Restoring from backup: {backup_name}")
        
        # Restore .env
        env_backup = backup_path / ".env"
        if env_backup.exists():
            shutil.copy(env_backup, ".env")
            Logger.info("  - Restored .env")
        
        # Restore docker-compose.yml
        compose_backup = backup_path / "docker-compose.yml"
        if compose_backup.exists():
            shutil.copy(compose_backup, "docker-compose.yml")
            Logger.info("  - Restored docker-compose.yml")
        
        # Restore database
        db_backup = backup_path / "database.sql"
        if db_backup.exists():
            try:
                subprocess.run(
                    ["docker-compose", "exec", "-T", "mysql", "mysql",
                     "-u", "root", "-p${MYSQL_ROOT_PASSWORD}",
                     "astron_db"],
                    stdin=open(db_backup),
                    check=True
                )
                Logger.info("  - Restored database")
            except:
                Logger.warning("  - Database restore failed")
        
        Logger.success("Restore completed")
        return True

class ConfigValidator:
    """Configuration validation"""
    
    @staticmethod
    def validate():
        """Validate configuration"""
        Logger.info("Validating configuration...")
        
        errors = []
        warnings = []
        
        # Check .env exists
        if not Path(".env").exists():
            errors.append(".env file not found")
        else:
            Logger.success(".env file exists")
            
            # Read .env
            with open(".env") as f:
                env_content = f.read()
            
            # Check required variables
            required_vars = [
                "MYSQL_ROOT_PASSWORD",
                "MYSQL_PASSWORD",
                "SECRET_KEY",
                "JWT_SECRET"
            ]
            
            for var in required_vars:
                if var not in env_content:
                    errors.append(f"Missing required variable: {var}")
                elif f"{var}=your" in env_content or f"{var}=example" in env_content:
                    warnings.append(f"Placeholder value in: {var}")
            
            # Check password strength
            for line in env_content.split('\n'):
                if "PASSWORD=" in line and "=" in line:
                    password = line.split('=')[1].strip()
                    if len(password) < 12:
                        warnings.append(f"Weak password (< 12 chars): {line.split('=')[0]}")
        
        # Check docker-compose.yml
        if not Path("docker-compose.yml").exists():
            errors.append("docker-compose.yml not found")
        else:
            Logger.success("docker-compose.yml exists")
        
        # Print results
        if errors:
            Logger.error(f"Found {len(errors)} errors:")
            for error in errors:
                Logger.error(f"  - {error}")
        
        if warnings:
            Logger.warning(f"Found {len(warnings)} warnings:")
            for warning in warnings:
                Logger.warning(f"  - {warning}")
        
        if not errors and not warnings:
            Logger.success("All validation checks passed!")
            return True
        
        return len(errors) == 0

def main():
    """Main entry point"""
    if len(sys.argv) < 2:
        print("Usage: python3 manage.py [command]")
        print("")
        print("Commands:")
        print("  start       - Start all services")
        print("  stop        - Stop all services")
        print("  restart     - Restart all services")
        print("  status      - Show service status")
        print("  logs        - View logs")
        print("  update      - Update system")
        print("  rollback    - Rollback to previous version")
        print("  backup      - Create backup")
        print("  restore     - Restore from backup")
        print("  validate    - Validate configuration")
        sys.exit(1)
    
    command = sys.argv[1]
    
    if command == "start":
        success = DockerService.start_services()
        sys.exit(0 if success else 1)
    
    elif command == "stop":
        success = DockerService.stop_services()
        sys.exit(0 if success else 1)
    
    elif command == "restart":
        success = DockerService.restart_services()
        sys.exit(0 if success else 1)
    
    elif command == "status":
        DockerService.show_status()
        sys.exit(0)
    
    elif command == "logs":
        follow = "--follow" in sys.argv or "-f" in sys.argv
        service = sys.argv[2] if len(sys.argv) > 2 and not sys.argv[2].startswith("-") else None
        DockerService.show_logs(service, follow)
        sys.exit(0)
    
    elif command == "backup":
        backup_mgr = BackupManager()
        tag = sys.argv[2] if len(sys.argv) > 2 else ""
        backup_mgr.create_backup(tag)
        sys.exit(0)
    
    elif command == "restore":
        backup_mgr = BackupManager()
        
        if len(sys.argv) < 3:
            # List backups
            backups = backup_mgr.list_backups()
            if not backups:
                Logger.warning("No backups found")
                sys.exit(1)
            
            print("\nAvailable backups:")
            for i, backup in enumerate(backups, 1):
                print(f"  {i}. {backup}")
            print()
            sys.exit(0)
        
        backup_name = sys.argv[2]
        success = backup_mgr.restore_backup(backup_name)
        sys.exit(0 if success else 1)
    
    elif command == "rollback":
        # Rollback is same as restore
        backup_mgr = BackupManager()
        backups = backup_mgr.list_backups()
        
        if not backups:
            Logger.error("No backups available for rollback")
            sys.exit(1)
        
        latest_backup = backups[0]
        Logger.info(f"Rolling back to: {latest_backup}")
        success = backup_mgr.restore_backup(latest_backup)
        
        if success:
            Logger.info("Restarting services...")
            DockerService.restart_services()
        
        sys.exit(0 if success else 1)
    
    elif command == "update":
        Logger.info("Creating pre-update backup...")
        backup_mgr = BackupManager()
        backup_mgr.create_backup("pre-update")
        
        Logger.info("Pulling latest images...")
        subprocess.run(["docker-compose", "pull"])
        
        Logger.info("Restarting services...")
        DockerService.restart_services()
        
        Logger.success("Update completed!")
        sys.exit(0)
    
    elif command == "validate":
        success = ConfigValidator.validate()
        sys.exit(0 if success else 1)
    
    else:
        Logger.error(f"Unknown command: {command}")
        sys.exit(1)

if __name__ == "__main__":
    main()
