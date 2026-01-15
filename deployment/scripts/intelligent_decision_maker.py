#!/usr/bin/env python3
"""
Intelligent Deployment Decision Maker

This module implements AI-powered deployment decision making based on:
- Code change analysis
- System health metrics
- Risk assessment
- Historical deployment data
- Astron-RPA compatibility
"""

import json
import argparse
import logging
from typing import Dict, Any, List, Tuple
from datetime import datetime, timedelta
from dataclasses import dataclass
from enum import Enum
import requests
import os

# Configure logging
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)

class RiskLevel(Enum):
    LOW = "low"
    MEDIUM = "medium"
    HIGH = "high"
    CRITICAL = "critical"

class DeploymentStrategy(Enum):
    BLUE_GREEN = "blue-green"
    CANARY = "canary"
    ROLLING = "rolling"
    IMMEDIATE = "immediate"
    SKIP = "skip"

@dataclass
class DeploymentDecision:
    should_deploy: bool
    strategy: DeploymentStrategy
    risk_level: RiskLevel
    confidence: float
    reasoning: List[str]
    plan: Dict[str, Any]
    rollback_plan: Dict[str, Any]
    monitoring_config: Dict[str, Any]

class IntelligentDecisionMaker:
    """AI-powered deployment decision maker"""
    
    def __init__(self, deployment_mode: str = "intelligent"):
        self.deployment_mode = deployment_mode
        self.risk_weights = {
            'code_changes': 0.3,
            'system_health': 0.25,
            'compatibility': 0.2,
            'historical_success': 0.15,
            'time_factors': 0.1
        }
        
    def analyze_and_decide(
        self,
        changes_data: Dict[str, Any],
        health_data: Dict[str, Any],
        compatibility_data: Dict[str, Any]
    ) -> DeploymentDecision:
        """Main decision-making logic"""
        
        logger.info("🧠 Starting intelligent deployment analysis...")
        
        # Force deployment mode overrides
        if self.deployment_mode == "force":
            return self._force_deployment_decision()
        elif self.deployment_mode == "rollback":
            return self._rollback_decision()
            
        # Analyze different factors
        code_risk = self._analyze_code_changes(changes_data)
        health_risk = self._analyze_system_health(health_data)
        compatibility_risk = self._analyze_compatibility(compatibility_data)
        historical_risk = self._analyze_historical_data()
        time_risk = self._analyze_time_factors()
        
        # Calculate overall risk
        overall_risk = self._calculate_overall_risk({
            'code_changes': code_risk,
            'system_health': health_risk,
            'compatibility': compatibility_risk,
            'historical_success': historical_risk,
            'time_factors': time_risk
        })
        
        # Make deployment decision
        decision = self._make_deployment_decision(
            overall_risk,
            changes_data,
            health_data,
            compatibility_data
        )
        
        logger.info(f"🎯 Decision: {'DEPLOY' if decision.should_deploy else 'SKIP'} "
                   f"(Risk: {decision.risk_level.value}, Strategy: {decision.strategy.value})")
        
        return decision
    
    def _analyze_code_changes(self, changes_data: Dict[str, Any]) -> float:
        """Analyze code changes to assess deployment risk"""
        
        risk_score = 0.0
        
        # File change analysis
        files_changed = changes_data.get('files_changed', 0)
        lines_changed = changes_data.get('lines_changed', 0)
        
        # Risk factors
        if files_changed > 50:
            risk_score += 0.3
        elif files_changed > 20:
            risk_score += 0.2
        elif files_changed > 10:
            risk_score += 0.1
            
        if lines_changed > 1000:
            risk_score += 0.3
        elif lines_changed > 500:
            risk_score += 0.2
        elif lines_changed > 100:
            risk_score += 0.1
            
        # Critical file changes
        critical_files = changes_data.get('critical_files_changed', [])
        if critical_files:
            risk_score += len(critical_files) * 0.1
            
        # Database schema changes
        if changes_data.get('database_changes', False):
            risk_score += 0.2
            
        # Configuration changes
        if changes_data.get('config_changes', False):
            risk_score += 0.15
            
        # API breaking changes
        if changes_data.get('breaking_changes', False):
            risk_score += 0.4
            
        # Test coverage
        test_coverage = changes_data.get('test_coverage', 100)
        if test_coverage < 80:
            risk_score += 0.2
        elif test_coverage < 90:
            risk_score += 0.1
            
        return min(risk_score, 1.0)
    
    def _analyze_system_health(self, health_data: Dict[str, Any]) -> float:
        """Analyze current system health"""
        
        risk_score = 0.0
        
        # Overall health status
        overall_health = health_data.get('overall_health', 'unknown')
        if overall_health == 'critical':
            risk_score += 0.8
        elif overall_health == 'degraded':
            risk_score += 0.4
        elif overall_health == 'warning':
            risk_score += 0.2
            
        # Service availability
        service_availability = health_data.get('service_availability', 100)
        if service_availability < 95:
            risk_score += 0.3
        elif service_availability < 99:
            risk_score += 0.1
            
        # Error rates
        error_rate = health_data.get('error_rate', 0)
        if error_rate > 5:
            risk_score += 0.4
        elif error_rate > 1:
            risk_score += 0.2
            
        # Response times
        avg_response_time = health_data.get('avg_response_time', 0)
        if avg_response_time > 2000:  # 2 seconds
            risk_score += 0.3
        elif avg_response_time > 1000:  # 1 second
            risk_score += 0.1
            
        # Resource utilization
        cpu_usage = health_data.get('cpu_usage', 0)
        memory_usage = health_data.get('memory_usage', 0)
        
        if cpu_usage > 80 or memory_usage > 80:
            risk_score += 0.2
        elif cpu_usage > 70 or memory_usage > 70:
            risk_score += 0.1
            
        return min(risk_score, 1.0)
    
    def _analyze_compatibility(self, compatibility_data: Dict[str, Any]) -> float:
        """Analyze Astron-RPA compatibility"""
        
        risk_score = 0.0
        
        if not compatibility_data.get('compatible', True):
            risk_score += 0.6
            
        # Version compatibility
        version_compatibility = compatibility_data.get('version_compatibility', 'full')
        if version_compatibility == 'none':
            risk_score += 0.8
        elif version_compatibility == 'partial':
            risk_score += 0.4
        elif version_compatibility == 'deprecated':
            risk_score += 0.3
            
        # API compatibility
        api_compatibility = compatibility_data.get('api_compatibility', True)
        if not api_compatibility:
            risk_score += 0.3
            
        # Plugin compatibility
        plugin_compatibility = compatibility_data.get('plugin_compatibility', True)
        if not plugin_compatibility:
            risk_score += 0.2
            
        return min(risk_score, 1.0)
    
    def _analyze_historical_data(self) -> float:
        """Analyze historical deployment success rates"""
        
        # This would typically query a database or monitoring system
        # For now, we'll simulate based on recent deployment patterns
        
        risk_score = 0.0
        
        # Simulate recent deployment success rate
        recent_success_rate = 0.85  # 85% success rate
        
        if recent_success_rate < 0.7:
            risk_score += 0.4
        elif recent_success_rate < 0.8:
            risk_score += 0.2
        elif recent_success_rate < 0.9:
            risk_score += 0.1
            
        return risk_score
    
    def _analyze_time_factors(self) -> float:
        """Analyze time-based risk factors"""
        
        risk_score = 0.0
        current_time = datetime.now()
        
        # Avoid deployments during peak hours (9 AM - 5 PM weekdays)
        if (current_time.weekday() < 5 and  # Monday to Friday
            9 <= current_time.hour <= 17):
            risk_score += 0.3
            
        # Avoid Friday deployments
        if current_time.weekday() == 4:  # Friday
            risk_score += 0.2
            
        # Avoid deployments before holidays (simplified check)
        # This would typically check against a holiday calendar
        
        return risk_score
    
    def _calculate_overall_risk(self, risk_factors: Dict[str, float]) -> float:
        """Calculate weighted overall risk score"""
        
        overall_risk = 0.0
        for factor, risk in risk_factors.items():
            weight = self.risk_weights.get(factor, 0)
            overall_risk += risk * weight
            
        return min(overall_risk, 1.0)
    
    def _make_deployment_decision(
        self,
        overall_risk: float,
        changes_data: Dict[str, Any],
        health_data: Dict[str, Any],
        compatibility_data: Dict[str, Any]
    ) -> DeploymentDecision:
        """Make the final deployment decision"""
        
        reasoning = []
        
        # Determine risk level
        if overall_risk >= 0.7:
            risk_level = RiskLevel.CRITICAL
            should_deploy = False
            strategy = DeploymentStrategy.SKIP
            reasoning.append("Critical risk level detected - deployment skipped")
        elif overall_risk >= 0.5:
            risk_level = RiskLevel.HIGH
            should_deploy = True
            strategy = DeploymentStrategy.BLUE_GREEN
            reasoning.append("High risk - using blue-green deployment for safety")
        elif overall_risk >= 0.3:
            risk_level = RiskLevel.MEDIUM
            should_deploy = True
            strategy = DeploymentStrategy.CANARY
            reasoning.append("Medium risk - using canary deployment")
        else:
            risk_level = RiskLevel.LOW
            should_deploy = True
            strategy = DeploymentStrategy.ROLLING
            reasoning.append("Low risk - using rolling deployment")
            
        # Override for compatibility issues
        if not compatibility_data.get('compatible', True):
            should_deploy = False
            strategy = DeploymentStrategy.SKIP
            reasoning.append("Astron-RPA compatibility issues detected")
            
        # Override for critical system health
        if health_data.get('overall_health') == 'critical':
            should_deploy = False
            strategy = DeploymentStrategy.SKIP
            reasoning.append("System health is critical - deployment blocked")
            
        # Calculate confidence
        confidence = 1.0 - overall_risk
        
        # Create deployment plan
        plan = self._create_deployment_plan(strategy, changes_data, health_data)
        rollback_plan = self._create_rollback_plan(strategy)
        monitoring_config = self._create_monitoring_config(risk_level)
        
        return DeploymentDecision(
            should_deploy=should_deploy,
            strategy=strategy,
            risk_level=risk_level,
            confidence=confidence,
            reasoning=reasoning,
            plan=plan,
            rollback_plan=rollback_plan,
            monitoring_config=monitoring_config
        )
    
    def _create_deployment_plan(
        self,
        strategy: DeploymentStrategy,
        changes_data: Dict[str, Any],
        health_data: Dict[str, Any]
    ) -> Dict[str, Any]:
        """Create detailed deployment plan"""
        
        plan = {
            "strategy": strategy.value,
            "phases": [],
            "validation_steps": [],
            "rollback_triggers": []
        }
        
        if strategy == DeploymentStrategy.BLUE_GREEN:
            plan["phases"] = [
                {"name": "prepare_green", "duration": "5m"},
                {"name": "deploy_green", "duration": "10m"},
                {"name": "validate_green", "duration": "15m"},
                {"name": "switch_traffic", "duration": "2m"},
                {"name": "monitor", "duration": "30m"}
            ]
        elif strategy == DeploymentStrategy.CANARY:
            plan["phases"] = [
                {"name": "deploy_canary", "duration": "5m", "traffic_percentage": 10},
                {"name": "validate_canary", "duration": "10m"},
                {"name": "increase_traffic", "duration": "15m", "traffic_percentage": 50},
                {"name": "full_deployment", "duration": "10m", "traffic_percentage": 100}
            ]
        elif strategy == DeploymentStrategy.ROLLING:
            plan["phases"] = [
                {"name": "rolling_update", "duration": "15m", "batch_size": "25%"},
                {"name": "validation", "duration": "10m"}
            ]
            
        plan["validation_steps"] = [
            "health_check_endpoints",
            "integration_tests",
            "performance_validation",
            "rpa_integration_test"
        ]
        
        plan["rollback_triggers"] = [
            "error_rate > 5%",
            "response_time > 2000ms",
            "availability < 99%",
            "rpa_integration_failure"
        ]
        
        return plan
    
    def _create_rollback_plan(self, strategy: DeploymentStrategy) -> Dict[str, Any]:
        """Create rollback plan"""
        
        return {
            "strategy": "immediate",
            "steps": [
                "stop_new_deployment",
                "revert_traffic_routing",
                "restore_previous_version",
                "validate_rollback",
                "notify_stakeholders"
            ],
            "estimated_duration": "5m",
            "validation_required": True
        }
    
    def _create_monitoring_config(self, risk_level: RiskLevel) -> Dict[str, Any]:
        """Create monitoring configuration based on risk level"""
        
        base_config = {
            "metrics": [
                "response_time",
                "error_rate",
                "throughput",
                "availability",
                "resource_usage"
            ],
            "alerts": []
        }
        
        if risk_level in [RiskLevel.HIGH, RiskLevel.CRITICAL]:
            base_config["check_interval"] = "30s"
            base_config["alert_threshold"] = "strict"
            base_config["alerts"].extend([
                "error_rate > 1%",
                "response_time > 1000ms",
                "availability < 99.5%"
            ])
        elif risk_level == RiskLevel.MEDIUM:
            base_config["check_interval"] = "60s"
            base_config["alert_threshold"] = "normal"
            base_config["alerts"].extend([
                "error_rate > 2%",
                "response_time > 1500ms",
                "availability < 99%"
            ])
        else:
            base_config["check_interval"] = "120s"
            base_config["alert_threshold"] = "relaxed"
            base_config["alerts"].extend([
                "error_rate > 5%",
                "response_time > 2000ms",
                "availability < 98%"
            ])
            
        return base_config
    
    def _force_deployment_decision(self) -> DeploymentDecision:
        """Force deployment regardless of risk"""
        
        return DeploymentDecision(
            should_deploy=True,
            strategy=DeploymentStrategy.IMMEDIATE,
            risk_level=RiskLevel.HIGH,
            confidence=0.5,
            reasoning=["Force deployment mode enabled - bypassing safety checks"],
            plan={"strategy": "immediate", "phases": [{"name": "deploy", "duration": "10m"}]},
            rollback_plan=self._create_rollback_plan(DeploymentStrategy.IMMEDIATE),
            monitoring_config=self._create_monitoring_config(RiskLevel.HIGH)
        )
    
    def _rollback_decision(self) -> DeploymentDecision:
        """Rollback decision"""
        
        return DeploymentDecision(
            should_deploy=False,
            strategy=DeploymentStrategy.SKIP,
            risk_level=RiskLevel.CRITICAL,
            confidence=1.0,
            reasoning=["Rollback mode enabled - initiating rollback procedure"],
            plan={"strategy": "rollback", "action": "revert_to_previous_version"},
            rollback_plan={"immediate": True},
            monitoring_config=self._create_monitoring_config(RiskLevel.CRITICAL)
        )

def main():
    parser = argparse.ArgumentParser(description='Intelligent Deployment Decision Maker')
    parser.add_argument('--changes-file', required=True, help='Path to changes analysis JSON file')
    parser.add_argument('--health-file', required=True, help='Path to health status JSON file')
    parser.add_argument('--compatibility-file', required=True, help='Path to compatibility status JSON file')
    parser.add_argument('--deployment-mode', default='intelligent', choices=['intelligent', 'force', 'rollback'])
    parser.add_argument('--output-format', default='json', choices=['json', 'yaml'])
    
    args = parser.parse_args()
    
    try:
        # Load input data
        with open(args.changes_file, 'r') as f:
            changes_data = json.load(f)
            
        with open(args.health_file, 'r') as f:
            health_data = json.load(f)
            
        with open(args.compatibility_file, 'r') as f:
            compatibility_data = json.load(f)
            
        # Make decision
        decision_maker = IntelligentDecisionMaker(args.deployment_mode)
        decision = decision_maker.analyze_and_decide(changes_data, health_data, compatibility_data)
        
        # Output decision
        output = {
            "should_deploy": decision.should_deploy,
            "strategy": decision.strategy.value,
            "risk_level": decision.risk_level.value,
            "confidence": decision.confidence,
            "reasoning": decision.reasoning,
            "plan": decision.plan,
            "rollback_plan": decision.rollback_plan,
            "monitoring_config": decision.monitoring_config,
            "timestamp": datetime.now().isoformat(),
            "decision_maker_version": "1.0.0"
        }
        
        print(json.dumps(output, indent=2))
        
    except Exception as e:
        logger.error(f"Error making deployment decision: {e}")
        # Output safe default (no deployment)
        safe_output = {
            "should_deploy": False,
            "strategy": "skip",
            "risk_level": "critical",
            "confidence": 0.0,
            "reasoning": [f"Error in decision making: {str(e)}"],
            "plan": {},
            "rollback_plan": {},
            "monitoring_config": {},
            "error": str(e)
        }
        print(json.dumps(safe_output, indent=2))
        exit(1)

if __name__ == "__main__":
    main()
