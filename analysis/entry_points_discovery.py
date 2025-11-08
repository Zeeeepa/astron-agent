#!/usr/bin/env python3
"""
Entry Points Discovery Tool
Automated discovery and analysis of all system entry points
"""

import asyncio
import json
import os
import re
import subprocess
import sys
from pathlib import Path
from typing import Dict, List, Any, Optional, Set
import yaml
import aiohttp
import socket
from dataclasses import dataclass, asdict
from datetime import datetime


@dataclass
class EntryPoint:
    """Data class for entry point information"""
    name: str
    type: str
    protocol: str
    port: Optional[int]
    path: Optional[str]
    method: Optional[str]
    authentication: str
    security_level: str
    description: str
    discovered_by: str
    timestamp: str


class EntryPointsDiscovery:
    """Comprehensive entry points discovery and analysis"""
    
    def __init__(self):
        self.entry_points: List[EntryPoint] = []
        self.base_path = Path.cwd()
        self.discovery_timestamp = datetime.now().isoformat()
        
    async def discover_all_entry_points(self) -> Dict[str, Any]:
        """Main discovery method - finds all entry points"""
        print("🔍 Starting comprehensive entry points discovery...")
        
        results = {
            "discovery_timestamp": self.discovery_timestamp,
            "total_entry_points": 0,
            "categories": {},
            "security_analysis": {},
            "recommendations": []
        }
        
        # Discover different categories of entry points
        await self._discover_http_endpoints()
        await self._discover_container_interfaces()
        await self._discover_cli_commands()
        await self._discover_configuration_points()
        await self._discover_database_interfaces()
        await self._discover_file_system_interfaces()
        await self._discover_background_processing()
        await self._discover_network_protocols()
        
        # Analyze and categorize results
        results["total_entry_points"] = len(self.entry_points)
        results["categories"] = self._categorize_entry_points()
        results["security_analysis"] = self._analyze_security()
        results["recommendations"] = self._generate_recommendations()
        
        return results
    
    async def _discover_http_endpoints(self):
        """Discover all HTTP API endpoints"""
        print("  🌐 Discovering HTTP endpoints...")
        
        # Scan Python files for FastAPI routes
        python_files = list(self.base_path.rglob("*.py"))
        
        for file_path in python_files:
            try:
                with open(file_path, 'r', encoding='utf-8') as f:
                    content = f.read()
                    
                # Find FastAPI route decorators
                route_patterns = [
                    r'@(\w+)\.(?:get|post|put|delete|patch)\(["\']([^"\']+)["\']',
                    r'@app\.(?:get|post|put|delete|patch)\(["\']([^"\']+)["\']',
                    r'@router\.(?:get|post|put|delete|patch)\(["\']([^"\']+)["\']'
                ]
                
                for pattern in route_patterns:
                    matches = re.findall(pattern, content)
                    for match in matches:
                        if len(match) == 2:
                            router_name, endpoint = match
                            method = self._extract_http_method(content, endpoint)
                        else:
                            endpoint = match[0] if match else ""
                            method = "GET"
                            
                        if endpoint:
                            self.entry_points.append(EntryPoint(
                                name=f"HTTP {method} {endpoint}",
                                type="HTTP_ENDPOINT",
                                protocol="HTTP/HTTPS",
                                port=self._determine_port(file_path),
                                path=endpoint,
                                method=method,
                                authentication="TBD",
                                security_level="MEDIUM",
                                description=f"HTTP endpoint discovered in {file_path.name}",
                                discovered_by="code_analysis",
                                timestamp=self.discovery_timestamp
                            ))
                            
            except Exception as e:
                print(f"    ⚠️ Error analyzing {file_path}: {e}")
    
    async def _discover_container_interfaces(self):
        """Discover Docker container interfaces"""
        print("  🐳 Discovering container interfaces...")
        
        # Find Docker Compose files
        compose_files = list(self.base_path.glob("docker-compose*.yml")) + \
                      list(self.base_path.glob("docker-compose*.yaml"))
        
        for compose_file in compose_files:
            try:
                with open(compose_file, 'r') as f:
                    compose_data = yaml.safe_load(f)
                    
                services = compose_data.get('services', {})
                for service_name, service_config in services.items():
                    # Port mappings
                    ports = service_config.get('ports', [])
                    for port_mapping in ports:
                        if isinstance(port_mapping, str):
                            external_port = port_mapping.split(':')[0]
                            internal_port = port_mapping.split(':')[1]
                        else:
                            external_port = str(port_mapping)
                            internal_port = str(port_mapping)
                            
                        self.entry_points.append(EntryPoint(
                            name=f"Container {service_name} Port {external_port}",
                            type="CONTAINER_PORT",
                            protocol="TCP",
                            port=int(external_port.replace('${', '').split('-')[0].split(':')[0]) if external_port.isdigit() else None,
                            path=None,
                            method=None,
                            authentication="CONTAINER",
                            security_level="HIGH",
                            description=f"Docker container port mapping for {service_name}",
                            discovered_by="docker_compose_analysis",
                            timestamp=self.discovery_timestamp
                        ))
                    
                    # Volume mounts
                    volumes = service_config.get('volumes', [])
                    for volume in volumes:
                        if isinstance(volume, str) and ':' in volume:
                            host_path, container_path = volume.split(':', 1)
                            self.entry_points.append(EntryPoint(
                                name=f"Volume Mount {host_path}",
                                type="VOLUME_MOUNT",
                                protocol="FILE_SYSTEM",
                                port=None,
                                path=host_path,
                                method=None,
                                authentication="FILE_SYSTEM",
                                security_level="HIGH",
                                description=f"Docker volume mount for {service_name}",
                                discovered_by="docker_compose_analysis",
                                timestamp=self.discovery_timestamp
                            ))
                            
            except Exception as e:
                print(f"    ⚠️ Error analyzing {compose_file}: {e}")
    
    async def _discover_cli_commands(self):
        """Discover command-line interfaces"""
        print("  🖥️ Discovering CLI commands...")
        
        # Analyze Makefile
        makefile_path = self.base_path / "Makefile"
        if makefile_path.exists():
            try:
                with open(makefile_path, 'r') as f:
                    content = f.read()
                    
                # Find make targets
                targets = re.findall(r'^([a-zA-Z_-]+):', content, re.MULTILINE)
                for target in targets:
                    if not target.startswith('.') and target not in ['help', 'DEFAULT_GOAL']:
                        self.entry_points.append(EntryPoint(
                            name=f"make {target}",
                            type="CLI_COMMAND",
                            protocol="SHELL",
                            port=None,
                            path=None,
                            method=None,
                            authentication="SHELL_ACCESS",
                            security_level="MEDIUM",
                            description=f"Makefile target: {target}",
                            discovered_by="makefile_analysis",
                            timestamp=self.discovery_timestamp
                        ))
                        
            except Exception as e:
                print(f"    ⚠️ Error analyzing Makefile: {e}")
        
        # Find Python entry points
        python_files = [
            "core/agent/api/app.py",
            "start_debug_services.py",
            "comprehensive_api_test.py",
            "test_rpa_basic.py",
            "playwright_interface_test.py"
        ]
        
        for py_file in python_files:
            file_path = self.base_path / py_file
            if file_path.exists():
                self.entry_points.append(EntryPoint(
                    name=f"python {py_file}",
                    type="PYTHON_SCRIPT",
                    protocol="SHELL",
                    port=None,
                    path=str(file_path),
                    method=None,
                    authentication="SHELL_ACCESS",
                    security_level="MEDIUM",
                    description=f"Python script entry point",
                    discovered_by="file_system_scan",
                    timestamp=self.discovery_timestamp
                ))
    
    async def _discover_configuration_points(self):
        """Discover configuration entry points"""
        print("  ⚙️ Discovering configuration points...")
        
        # Environment variables from .env.example
        env_example = self.base_path / ".env.example"
        if env_example.exists():
            try:
                with open(env_example, 'r') as f:
                    content = f.read()
                    
                env_vars = re.findall(r'^([A-Z_][A-Z0-9_]*)=', content, re.MULTILINE)
                for var in env_vars:
                    self.entry_points.append(EntryPoint(
                        name=f"ENV {var}",
                        type="ENVIRONMENT_VARIABLE",
                        protocol="ENVIRONMENT",
                        port=None,
                        path=None,
                        method=None,
                        authentication="ENVIRONMENT_ACCESS",
                        security_level="HIGH",
                        description=f"Environment variable configuration",
                        discovered_by="env_file_analysis",
                        timestamp=self.discovery_timestamp
                    ))
                    
            except Exception as e:
                print(f"    ⚠️ Error analyzing .env.example: {e}")
        
        # YAML configuration files
        yaml_files = list(self.base_path.rglob("*.yml")) + list(self.base_path.rglob("*.yaml"))
        for yaml_file in yaml_files:
            if yaml_file.name not in ['docker-compose.yml', 'docker-compose.yaml']:
                self.entry_points.append(EntryPoint(
                    name=f"Config {yaml_file.name}",
                    type="CONFIG_FILE",
                    protocol="FILE_SYSTEM",
                    port=None,
                    path=str(yaml_file),
                    method=None,
                    authentication="FILE_SYSTEM",
                    security_level="MEDIUM",
                    description=f"YAML configuration file",
                    discovered_by="file_system_scan",
                    timestamp=self.discovery_timestamp
                ))
    
    async def _discover_database_interfaces(self):
        """Discover database access points"""
        print("  🗄️ Discovering database interfaces...")
        
        # MySQL connections
        mysql_ports = [3306]
        for port in mysql_ports:
            self.entry_points.append(EntryPoint(
                name=f"MySQL Database Port {port}",
                type="DATABASE_CONNECTION",
                protocol="MYSQL",
                port=port,
                path=None,
                method=None,
                authentication="USERNAME_PASSWORD",
                security_level="HIGH",
                description="MySQL database server connection",
                discovered_by="infrastructure_analysis",
                timestamp=self.discovery_timestamp
            ))
        
        # Redis connections
        redis_ports = [6379]
        for port in redis_ports:
            self.entry_points.append(EntryPoint(
                name=f"Redis Cache Port {port}",
                type="CACHE_CONNECTION",
                protocol="REDIS",
                port=port,
                path=None,
                method=None,
                authentication="OPTIONAL_PASSWORD",
                security_level="HIGH",
                description="Redis cache server connection",
                discovered_by="infrastructure_analysis",
                timestamp=self.discovery_timestamp
            ))
    
    async def _discover_file_system_interfaces(self):
        """Discover file system access points"""
        print("  📁 Discovering file system interfaces...")
        
        # Log directories
        log_dirs = ["./logs", "/app/logs", "/var/log"]
        for log_dir in log_dirs:
            self.entry_points.append(EntryPoint(
                name=f"Log Directory {log_dir}",
                type="LOG_DIRECTORY",
                protocol="FILE_SYSTEM",
                port=None,
                path=log_dir,
                method=None,
                authentication="FILE_SYSTEM",
                security_level="MEDIUM",
                description="Application log directory access",
                discovered_by="file_system_analysis",
                timestamp=self.discovery_timestamp
            ))
        
        # Config directories
        config_dirs = ["./config", "/app/config", "core/agent/infra/config"]
        for config_dir in config_dirs:
            self.entry_points.append(EntryPoint(
                name=f"Config Directory {config_dir}",
                type="CONFIG_DIRECTORY",
                protocol="FILE_SYSTEM",
                port=None,
                path=config_dir,
                method=None,
                authentication="FILE_SYSTEM",
                security_level="HIGH",
                description="Configuration directory access",
                discovered_by="file_system_analysis",
                timestamp=self.discovery_timestamp
            ))
    
    async def _discover_background_processing(self):
        """Discover background processing entry points"""
        print("  🔄 Discovering background processing...")
        
        # FastAPI background tasks
        python_files = list(self.base_path.rglob("*.py"))
        for file_path in python_files:
            try:
                with open(file_path, 'r', encoding='utf-8') as f:
                    content = f.read()
                    
                if "BackgroundTasks" in content or "background_tasks.add_task" in content:
                    tasks = re.findall(r'background_tasks\.add_task\(([^,]+)', content)
                    for task in tasks:
                        self.entry_points.append(EntryPoint(
                            name=f"Background Task {task}",
                            type="BACKGROUND_TASK",
                            protocol="ASYNC_PROCESSING",
                            port=None,
                            path=None,
                            method=None,
                            authentication="INTERNAL",
                            security_level="MEDIUM",
                            description=f"FastAPI background task in {file_path.name}",
                            discovered_by="code_analysis",
                            timestamp=self.discovery_timestamp
                        ))
                        
            except Exception as e:
                print(f"    ⚠️ Error analyzing {file_path}: {e}")
    
    async def _discover_network_protocols(self):
        """Discover network protocol interfaces"""
        print("  🌐 Discovering network protocols...")
        
        # Common service ports
        common_ports = {
            80: "HTTP",
            443: "HTTPS",
            9000: "MinIO_API",
            9001: "MinIO_Console",
            9090: "Prometheus",
            3000: "Grafana",
            16686: "Jaeger"
        }
        
        for port, service in common_ports.items():
            self.entry_points.append(EntryPoint(
                name=f"{service} Port {port}",
                type="NETWORK_SERVICE",
                protocol=service,
                port=port,
                path=None,
                method=None,
                authentication="VARIES",
                security_level="MEDIUM",
                description=f"{service} network service",
                discovered_by="port_analysis",
                timestamp=self.discovery_timestamp
            ))
    
    def _extract_http_method(self, content: str, endpoint: str) -> str:
        """Extract HTTP method from route definition"""
        methods = ["GET", "POST", "PUT", "DELETE", "PATCH"]
        for method in methods:
            if f".{method.lower()}(" in content and endpoint in content:
                return method
        return "GET"
    
    def _determine_port(self, file_path: Path) -> Optional[int]:
        """Determine the port for a service based on file path"""
        if "rpa" in str(file_path).lower():
            return 8020
        elif "agent" in str(file_path).lower():
            return 8000
        elif "engine" in str(file_path).lower():
            return 8021
        return None
    
    def _categorize_entry_points(self) -> Dict[str, Any]:
        """Categorize discovered entry points"""
        categories = {}
        
        for entry_point in self.entry_points:
            category = entry_point.type
            if category not in categories:
                categories[category] = {
                    "count": 0,
                    "security_levels": {},
                    "entry_points": []
                }
            
            categories[category]["count"] += 1
            
            security_level = entry_point.security_level
            if security_level not in categories[category]["security_levels"]:
                categories[category]["security_levels"][security_level] = 0
            categories[category]["security_levels"][security_level] += 1
            
            categories[category]["entry_points"].append(asdict(entry_point))
        
        return categories
    
    def _analyze_security(self) -> Dict[str, Any]:
        """Analyze security implications of discovered entry points"""
        security_analysis = {
            "high_risk_count": 0,
            "medium_risk_count": 0,
            "low_risk_count": 0,
            "critical_findings": [],
            "recommendations": []
        }
        
        for entry_point in self.entry_points:
            if entry_point.security_level == "HIGH":
                security_analysis["high_risk_count"] += 1
                if entry_point.type in ["DATABASE_CONNECTION", "CONTAINER_PORT", "ENVIRONMENT_VARIABLE"]:
                    security_analysis["critical_findings"].append({
                        "name": entry_point.name,
                        "type": entry_point.type,
                        "risk": "Direct access to sensitive resources",
                        "recommendation": "Implement strict access controls and monitoring"
                    })
            elif entry_point.security_level == "MEDIUM":
                security_analysis["medium_risk_count"] += 1
            else:
                security_analysis["low_risk_count"] += 1
        
        return security_analysis
    
    def _generate_recommendations(self) -> List[str]:
        """Generate security and operational recommendations"""
        recommendations = [
            "Implement API authentication for all HTTP endpoints",
            "Enable SSL/TLS encryption for all network communications",
            "Restrict container exec access to authorized users only",
            "Implement input validation for all configuration entry points",
            "Add rate limiting to prevent abuse of API endpoints",
            "Enable audit logging for all administrative access",
            "Implement network segmentation for internal services",
            "Regular security scanning of all discovered entry points",
            "Monitor all entry points for unusual activity",
            "Implement backup and recovery procedures for critical services"
        ]
        
        return recommendations
    
    async def generate_report(self, output_file: str = "entry_points_discovery_report.json"):
        """Generate comprehensive discovery report"""
        print("📊 Generating comprehensive discovery report...")
        
        results = await self.discover_all_entry_points()
        
        # Save detailed report
        with open(output_file, 'w') as f:
            json.dump(results, f, indent=2, default=str)
        
        # Generate summary
        summary = {
            "discovery_summary": {
                "timestamp": results["discovery_timestamp"],
                "total_entry_points": results["total_entry_points"],
                "categories": {k: v["count"] for k, v in results["categories"].items()},
                "security_summary": {
                    "high_risk": results["security_analysis"]["high_risk_count"],
                    "medium_risk": results["security_analysis"]["medium_risk_count"],
                    "low_risk": results["security_analysis"]["low_risk_count"]
                }
            }
        }
        
        print(f"\n✅ Discovery complete!")
        print(f"📊 Total entry points discovered: {results['total_entry_points']}")
        print(f"🔴 High risk: {results['security_analysis']['high_risk_count']}")
        print(f"🟡 Medium risk: {results['security_analysis']['medium_risk_count']}")
        print(f"🟢 Low risk: {results['security_analysis']['low_risk_count']}")
        print(f"📄 Detailed report saved to: {output_file}")
        
        return results


async def main():
    """Main execution function"""
    print("🚀 Starting Astron-Agent Entry Points Discovery")
    print("=" * 60)
    
    discovery = EntryPointsDiscovery()
    results = await discovery.generate_report()
    
    print("\n" + "=" * 60)
    print("🎯 Discovery Summary:")
    print(f"   Total Entry Points: {results['total_entry_points']}")
    print(f"   Categories: {len(results['categories'])}")
    print(f"   Critical Findings: {len(results['security_analysis']['critical_findings'])}")
    print("=" * 60)


if __name__ == "__main__":
    asyncio.run(main())
