#!/usr/bin/env python3
"""
Self-Healing Monitoring System

This module implements autonomous monitoring and self-healing capabilities for
the Astron-Agent + Astron-RPA integrated platform.

Features:
- Real-time health monitoring
- Automatic issue detection
- Self-healing actions
- Predictive scaling
- Integration with Codegen platform
"""

import asyncio
import json
import logging
import time
from typing import Dict, Any, List, Optional, Callable
from datetime import datetime, timedelta
from dataclasses import dataclass, asdict
from enum import Enum
import aiohttp
import requests
from concurrent.futures import ThreadPoolExecutor
import os
import yaml

# Configure logging
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)

class HealthStatus(Enum):
    HEALTHY = "healthy"
    WARNING = "warning"
    DEGRADED = "degraded"
    CRITICAL = "critical"
    UNKNOWN = "unknown"

class ActionType(Enum):
    RESTART_SERVICE = "restart_service"
    SCALE_UP = "scale_up"
    SCALE_DOWN = "scale_down"
    ROLLBACK = "rollback"
    ALERT = "alert"
    CODEGEN_INTERVENTION = "codegen_intervention"

@dataclass
class HealthMetric:
    name: str
    value: float
    threshold: float
    status: HealthStatus
    timestamp: datetime
    service: str
    
@dataclass
class HealingAction:
    action_type: ActionType
    target_service: str
    parameters: Dict[str, Any]
    priority: int
    estimated_duration: int  # seconds
    success_probability: float
    
@dataclass
class ServiceHealth:
    service_name: str
    status: HealthStatus
    metrics: List[HealthMetric]
    last_check: datetime
    consecutive_failures: int
    
class SelfHealingMonitor:
    """Autonomous monitoring and self-healing system"""
    
    def __init__(self, config_path: str = "deployment/config/monitoring.yml"):
        self.config = self._load_config(config_path)
        self.services = {}
        self.healing_actions = []
        self.codegen_client = CodegenClient(self.config.get('codegen', {}))
        self.executor = ThreadPoolExecutor(max_workers=10)
        self.running = False
        
        # Service endpoints
        self.service_endpoints = {
            'astron-agent-core': 'http://localhost:8000/health',
            'astron-agent-workflow': 'http://localhost:8001/health',
            'astron-agent-knowledge': 'http://localhost:8002/health',
            'astron-agent-console': 'http://localhost:8080/actuator/health',
            'astron-agent-tenant': 'http://localhost:9000/health',
            'astron-rpa-engine': 'http://localhost:19999/health',
            'astron-rpa-ai-service': 'http://localhost:8081/actuator/health',
            'astron-rpa-openapi': 'http://localhost:8082/actuator/health',
            'astron-rpa-resource': 'http://localhost:8083/actuator/health',
            'astron-rpa-robot': 'http://localhost:8084/actuator/health',
        }
        
        # Healing strategies
        self.healing_strategies = {
            HealthStatus.WARNING: self._handle_warning,
            HealthStatus.DEGRADED: self._handle_degraded,
            HealthStatus.CRITICAL: self._handle_critical
        }
        
    def _load_config(self, config_path: str) -> Dict[str, Any]:
        """Load monitoring configuration"""
        try:
            with open(config_path, 'r') as f:
                return yaml.safe_load(f)
        except FileNotFoundError:
            logger.warning(f"Config file {config_path} not found, using defaults")
            return self._default_config()
            
    def _default_config(self) -> Dict[str, Any]:
        """Default monitoring configuration"""
        return {
            'check_interval': 30,
            'thresholds': {
                'response_time': 2000,
                'error_rate': 5.0,
                'cpu_usage': 80.0,
                'memory_usage': 80.0,
                'availability': 99.0
            },
            'healing': {
                'max_restart_attempts': 3,
                'restart_cooldown': 300,
                'scale_up_threshold': 0.8,
                'scale_down_threshold': 0.3
            },
            'codegen': {
                'api_key': os.getenv('CODEGEN_API_KEY'),
                'base_url': 'https://api.codegen.com',
                'intervention_threshold': 'critical'
            }
        }
        
    async def start_monitoring(self):
        """Start the monitoring loop"""
        logger.info("🚀 Starting self-healing monitoring system...")
        self.running = True
        
        # Start monitoring tasks
        tasks = [
            asyncio.create_task(self._health_check_loop()),
            asyncio.create_task(self._healing_action_loop()),
            asyncio.create_task(self._predictive_scaling_loop()),
            asyncio.create_task(self._codegen_feedback_loop())
        ]
        
        try:
            await asyncio.gather(*tasks)
        except KeyboardInterrupt:
            logger.info("🛑 Stopping monitoring system...")
            self.running = False
            
    async def _health_check_loop(self):
        """Main health checking loop"""
        while self.running:
            try:
                await self._check_all_services()
                await asyncio.sleep(self.config['check_interval'])
            except Exception as e:
                logger.error(f"Error in health check loop: {e}")
                await asyncio.sleep(5)
                
    async def _check_all_services(self):
        """Check health of all services"""
        tasks = []
        for service_name, endpoint in self.service_endpoints.items():
            task = asyncio.create_task(self._check_service_health(service_name, endpoint))
            tasks.append(task)
            
        results = await asyncio.gather(*tasks, return_exceptions=True)
        
        for i, result in enumerate(results):
            service_name = list(self.service_endpoints.keys())[i]
            if isinstance(result, Exception):
                logger.error(f"Error checking {service_name}: {result}")
                self._update_service_health(service_name, HealthStatus.UNKNOWN, [])
            else:
                self._update_service_health(service_name, result[0], result[1])
                
    async def _check_service_health(self, service_name: str, endpoint: str) -> tuple:
        """Check individual service health"""
        try:
            async with aiohttp.ClientSession(timeout=aiohttp.ClientTimeout(total=10)) as session:
                start_time = time.time()
                async with session.get(endpoint) as response:
                    response_time = (time.time() - start_time) * 1000
                    
                    if response.status == 200:
                        data = await response.json()
                        metrics = self._extract_metrics(service_name, data, response_time)
                        status = self._calculate_service_status(metrics)
                        return status, metrics
                    else:
                        return HealthStatus.DEGRADED, []
                        
        except asyncio.TimeoutError:
            return HealthStatus.CRITICAL, []
        except Exception as e:
            logger.error(f"Health check failed for {service_name}: {e}")
            return HealthStatus.UNKNOWN, []
            
    def _extract_metrics(self, service_name: str, data: Dict[str, Any], response_time: float) -> List[HealthMetric]:
        """Extract metrics from health check response"""
        metrics = []
        now = datetime.now()
        
        # Response time metric
        metrics.append(HealthMetric(
            name="response_time",
            value=response_time,
            threshold=self.config['thresholds']['response_time'],
            status=HealthStatus.HEALTHY if response_time < self.config['thresholds']['response_time'] else HealthStatus.WARNING,
            timestamp=now,
            service=service_name
        ))
        
        # Extract additional metrics from response
        if 'metrics' in data:
            for metric_name, metric_value in data['metrics'].items():
                if metric_name in self.config['thresholds']:
                    threshold = self.config['thresholds'][metric_name]
                    status = HealthStatus.HEALTHY if metric_value < threshold else HealthStatus.WARNING
                    
                    metrics.append(HealthMetric(
                        name=metric_name,
                        value=metric_value,
                        threshold=threshold,
                        status=status,
                        timestamp=now,
                        service=service_name
                    ))
                    
        return metrics
        
    def _calculate_service_status(self, metrics: List[HealthMetric]) -> HealthStatus:
        """Calculate overall service status from metrics"""
        if not metrics:
            return HealthStatus.UNKNOWN
            
        statuses = [metric.status for metric in metrics]
        
        if HealthStatus.CRITICAL in statuses:
            return HealthStatus.CRITICAL
        elif HealthStatus.DEGRADED in statuses:
            return HealthStatus.DEGRADED
        elif HealthStatus.WARNING in statuses:
            return HealthStatus.WARNING
        else:
            return HealthStatus.HEALTHY
            
    def _update_service_health(self, service_name: str, status: HealthStatus, metrics: List[HealthMetric]):
        """Update service health status"""
        if service_name not in self.services:
            self.services[service_name] = ServiceHealth(
                service_name=service_name,
                status=status,
                metrics=metrics,
                last_check=datetime.now(),
                consecutive_failures=0
            )
        else:
            service = self.services[service_name]
            
            # Update consecutive failures
            if status in [HealthStatus.DEGRADED, HealthStatus.CRITICAL]:
                service.consecutive_failures += 1
            else:
                service.consecutive_failures = 0
                
            service.status = status
            service.metrics = metrics
            service.last_check = datetime.now()
            
        # Trigger healing if needed
        if status in [HealthStatus.WARNING, HealthStatus.DEGRADED, HealthStatus.CRITICAL]:
            self._trigger_healing(service_name, status)
            
    def _trigger_healing(self, service_name: str, status: HealthStatus):
        """Trigger appropriate healing actions"""
        if status in self.healing_strategies:
            actions = self.healing_strategies[status](service_name)
            self.healing_actions.extend(actions)
            
    def _handle_warning(self, service_name: str) -> List[HealingAction]:
        """Handle warning status"""
        return [
            HealingAction(
                action_type=ActionType.ALERT,
                target_service=service_name,
                parameters={'severity': 'warning', 'message': f'{service_name} is showing warning signs'},
                priority=3,
                estimated_duration=0,
                success_probability=1.0
            )
        ]
        
    def _handle_degraded(self, service_name: str) -> List[HealingAction]:
        """Handle degraded status"""
        service = self.services[service_name]
        actions = []
        
        # Scale up if resource constrained
        for metric in service.metrics:
            if metric.name in ['cpu_usage', 'memory_usage'] and metric.value > 70:
                actions.append(HealingAction(
                    action_type=ActionType.SCALE_UP,
                    target_service=service_name,
                    parameters={'replicas': 1},
                    priority=2,
                    estimated_duration=120,
                    success_probability=0.8
                ))
                break
                
        # Restart if consecutive failures
        if service.consecutive_failures >= 2:
            actions.append(HealingAction(
                action_type=ActionType.RESTART_SERVICE,
                target_service=service_name,
                parameters={},
                priority=2,
                estimated_duration=60,
                success_probability=0.7
            ))
            
        return actions
        
    def _handle_critical(self, service_name: str) -> List[HealingAction]:
        """Handle critical status"""
        service = self.services[service_name]
        actions = []
        
        # Immediate restart
        actions.append(HealingAction(
            action_type=ActionType.RESTART_SERVICE,
            target_service=service_name,
            parameters={'force': True},
            priority=1,
            estimated_duration=60,
            success_probability=0.6
        ))
        
        # Scale up aggressively
        actions.append(HealingAction(
            action_type=ActionType.SCALE_UP,
            target_service=service_name,
            parameters={'replicas': 2},
            priority=1,
            estimated_duration=120,
            success_probability=0.8
        ))
        
        # Trigger Codegen intervention if configured
        if (self.config['codegen'].get('intervention_threshold') == 'critical' and
            service.consecutive_failures >= 3):
            actions.append(HealingAction(
                action_type=ActionType.CODEGEN_INTERVENTION,
                target_service=service_name,
                parameters={'issue_type': 'critical_service_failure'},
                priority=1,
                estimated_duration=300,
                success_probability=0.9
            ))
            
        return actions
        
    async def _healing_action_loop(self):
        """Execute healing actions"""
        while self.running:
            if self.healing_actions:
                # Sort by priority
                self.healing_actions.sort(key=lambda x: x.priority)
                action = self.healing_actions.pop(0)
                
                try:
                    await self._execute_healing_action(action)
                except Exception as e:
                    logger.error(f"Error executing healing action: {e}")
                    
            await asyncio.sleep(5)
            
    async def _execute_healing_action(self, action: HealingAction):
        """Execute a specific healing action"""
        logger.info(f"🔧 Executing healing action: {action.action_type.value} on {action.target_service}")
        
        if action.action_type == ActionType.RESTART_SERVICE:
            await self._restart_service(action.target_service, action.parameters)
        elif action.action_type == ActionType.SCALE_UP:
            await self._scale_service(action.target_service, action.parameters)
        elif action.action_type == ActionType.SCALE_DOWN:
            await self._scale_service(action.target_service, action.parameters)
        elif action.action_type == ActionType.ROLLBACK:
            await self._rollback_service(action.target_service, action.parameters)
        elif action.action_type == ActionType.ALERT:
            await self._send_alert(action.target_service, action.parameters)
        elif action.action_type == ActionType.CODEGEN_INTERVENTION:
            await self._trigger_codegen_intervention(action.target_service, action.parameters)
            
    async def _restart_service(self, service_name: str, parameters: Dict[str, Any]):
        """Restart a service"""
        try:
            # This would integrate with your container orchestration system
            # For Docker Compose:
            cmd = f"docker-compose restart {service_name}"
            
            # For Kubernetes:
            # cmd = f"kubectl rollout restart deployment/{service_name}"
            
            process = await asyncio.create_subprocess_shell(
                cmd,
                stdout=asyncio.subprocess.PIPE,
                stderr=asyncio.subprocess.PIPE
            )
            
            stdout, stderr = await process.communicate()
            
            if process.returncode == 0:
                logger.info(f"✅ Successfully restarted {service_name}")
            else:
                logger.error(f"❌ Failed to restart {service_name}: {stderr.decode()}")
                
        except Exception as e:
            logger.error(f"Error restarting service {service_name}: {e}")
            
    async def _scale_service(self, service_name: str, parameters: Dict[str, Any]):
        """Scale a service"""
        try:
            replicas = parameters.get('replicas', 1)
            
            # For Docker Compose:
            cmd = f"docker-compose up -d --scale {service_name}={replicas}"
            
            # For Kubernetes:
            # cmd = f"kubectl scale deployment/{service_name} --replicas={replicas}"
            
            process = await asyncio.create_subprocess_shell(
                cmd,
                stdout=asyncio.subprocess.PIPE,
                stderr=asyncio.subprocess.PIPE
            )
            
            stdout, stderr = await process.communicate()
            
            if process.returncode == 0:
                logger.info(f"✅ Successfully scaled {service_name} to {replicas} replicas")
            else:
                logger.error(f"❌ Failed to scale {service_name}: {stderr.decode()}")
                
        except Exception as e:
            logger.error(f"Error scaling service {service_name}: {e}")
            
    async def _rollback_service(self, service_name: str, parameters: Dict[str, Any]):
        """Rollback a service to previous version"""
        try:
            # For Kubernetes:
            cmd = f"kubectl rollout undo deployment/{service_name}"
            
            process = await asyncio.create_subprocess_shell(
                cmd,
                stdout=asyncio.subprocess.PIPE,
                stderr=asyncio.subprocess.PIPE
            )
            
            stdout, stderr = await process.communicate()
            
            if process.returncode == 0:
                logger.info(f"✅ Successfully rolled back {service_name}")
            else:
                logger.error(f"❌ Failed to rollback {service_name}: {stderr.decode()}")
                
        except Exception as e:
            logger.error(f"Error rolling back service {service_name}: {e}")
            
    async def _send_alert(self, service_name: str, parameters: Dict[str, Any]):
        """Send alert notification"""
        try:
            alert_data = {
                'service': service_name,
                'severity': parameters.get('severity', 'warning'),
                'message': parameters.get('message', f'Service {service_name} needs attention'),
                'timestamp': datetime.now().isoformat()
            }
            
            # Send to webhook if configured
            webhook_url = self.config.get('alert_webhook')
            if webhook_url:
                async with aiohttp.ClientSession() as session:
                    async with session.post(webhook_url, json=alert_data) as response:
                        if response.status == 200:
                            logger.info(f"✅ Alert sent for {service_name}")
                        else:
                            logger.error(f"❌ Failed to send alert for {service_name}")
                            
        except Exception as e:
            logger.error(f"Error sending alert for {service_name}: {e}")
            
    async def _trigger_codegen_intervention(self, service_name: str, parameters: Dict[str, Any]):
        """Trigger Codegen platform intervention"""
        try:
            await self.codegen_client.create_intervention_request(
                service_name=service_name,
                issue_type=parameters.get('issue_type', 'service_failure'),
                context=self._get_service_context(service_name)
            )
            logger.info(f"✅ Codegen intervention triggered for {service_name}")
            
        except Exception as e:
            logger.error(f"Error triggering Codegen intervention for {service_name}: {e}")
            
    def _get_service_context(self, service_name: str) -> Dict[str, Any]:
        """Get service context for Codegen intervention"""
        service = self.services.get(service_name)
        if not service:
            return {}
            
        return {
            'service_name': service_name,
            'status': service.status.value,
            'consecutive_failures': service.consecutive_failures,
            'last_check': service.last_check.isoformat(),
            'metrics': [asdict(metric) for metric in service.metrics],
            'recent_actions': [action for action in self.healing_actions if action.target_service == service_name]
        }
        
    async def _predictive_scaling_loop(self):
        """Predictive scaling based on trends"""
        while self.running:
            try:
                await self._analyze_scaling_needs()
                await asyncio.sleep(300)  # Check every 5 minutes
            except Exception as e:
                logger.error(f"Error in predictive scaling loop: {e}")
                await asyncio.sleep(60)
                
    async def _analyze_scaling_needs(self):
        """Analyze if services need scaling based on trends"""
        for service_name, service in self.services.items():
            if service.status == HealthStatus.HEALTHY:
                # Check if we should scale down
                cpu_metrics = [m for m in service.metrics if m.name == 'cpu_usage']
                if cpu_metrics and cpu_metrics[0].value < 30:
                    # Consider scaling down
                    self.healing_actions.append(HealingAction(
                        action_type=ActionType.SCALE_DOWN,
                        target_service=service_name,
                        parameters={'replicas': -1},
                        priority=4,
                        estimated_duration=60,
                        success_probability=0.9
                    ))
                    
    async def _codegen_feedback_loop(self):
        """Send feedback to Codegen platform"""
        while self.running:
            try:
                await self._send_codegen_feedback()
                await asyncio.sleep(3600)  # Send feedback every hour
            except Exception as e:
                logger.error(f"Error in Codegen feedback loop: {e}")
                await asyncio.sleep(300)
                
    async def _send_codegen_feedback(self):
        """Send system health feedback to Codegen"""
        try:
            feedback_data = {
                'timestamp': datetime.now().isoformat(),
                'overall_health': self._calculate_overall_health(),
                'services': {name: asdict(service) for name, service in self.services.items()},
                'healing_actions_count': len(self.healing_actions),
                'recommendations': self._generate_recommendations()
            }
            
            await self.codegen_client.send_feedback(feedback_data)
            logger.info("✅ Feedback sent to Codegen platform")
            
        except Exception as e:
            logger.error(f"Error sending Codegen feedback: {e}")
            
    def _calculate_overall_health(self) -> str:
        """Calculate overall system health"""
        if not self.services:
            return HealthStatus.UNKNOWN.value
            
        statuses = [service.status for service in self.services.values()]
        
        if HealthStatus.CRITICAL in statuses:
            return HealthStatus.CRITICAL.value
        elif HealthStatus.DEGRADED in statuses:
            return HealthStatus.DEGRADED.value
        elif HealthStatus.WARNING in statuses:
            return HealthStatus.WARNING.value
        else:
            return HealthStatus.HEALTHY.value
            
    def _generate_recommendations(self) -> List[str]:
        """Generate optimization recommendations"""
        recommendations = []
        
        # Analyze patterns and suggest improvements
        for service_name, service in self.services.items():
            if service.consecutive_failures > 0:
                recommendations.append(f"Consider reviewing {service_name} configuration - {service.consecutive_failures} consecutive failures")
                
        return recommendations

class CodegenClient:
    """Client for Codegen platform integration"""
    
    def __init__(self, config: Dict[str, Any]):
        self.api_key = config.get('api_key')
        self.base_url = config.get('base_url', 'https://api.codegen.com')
        
    async def create_intervention_request(self, service_name: str, issue_type: str, context: Dict[str, Any]):
        """Create intervention request in Codegen"""
        if not self.api_key:
            logger.warning("Codegen API key not configured")
            return
            
        try:
            async with aiohttp.ClientSession() as session:
                headers = {'Authorization': f'Bearer {self.api_key}'}
                data = {
                    'service_name': service_name,
                    'issue_type': issue_type,
                    'context': context,
                    'priority': 'high',
                    'auto_assign': True
                }
                
                async with session.post(f'{self.base_url}/interventions', 
                                      json=data, headers=headers) as response:
                    if response.status == 201:
                        logger.info("✅ Intervention request created in Codegen")
                    else:
                        logger.error(f"❌ Failed to create intervention request: {response.status}")
                        
        except Exception as e:
            logger.error(f"Error creating Codegen intervention: {e}")
            
    async def send_feedback(self, feedback_data: Dict[str, Any]):
        """Send feedback to Codegen platform"""
        if not self.api_key:
            return
            
        try:
            async with aiohttp.ClientSession() as session:
                headers = {'Authorization': f'Bearer {self.api_key}'}
                
                async with session.post(f'{self.base_url}/feedback', 
                                      json=feedback_data, headers=headers) as response:
                    if response.status == 200:
                        logger.debug("Feedback sent to Codegen")
                    else:
                        logger.error(f"Failed to send feedback: {response.status}")
                        
        except Exception as e:
            logger.error(f"Error sending Codegen feedback: {e}")

async def main():
    """Main entry point"""
    import argparse
    
    parser = argparse.ArgumentParser(description='Self-Healing Monitor')
    parser.add_argument('--config', default='deployment/config/monitoring.yml', 
                       help='Path to monitoring configuration file')
    
    args = parser.parse_args()
    
    monitor = SelfHealingMonitor(args.config)
    await monitor.start_monitoring()

if __name__ == "__main__":
    asyncio.run(main())
