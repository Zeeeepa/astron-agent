"""
Validation Orchestrator

Orchestrates comprehensive validation of the RPA plugin architecture
by coordinating all validation components.
"""

import asyncio
import json
import time
from typing import Any, Dict, List, Optional
from datetime import datetime

from common_imports import logger, Span
from .plugin_validator import PluginArchitectureValidator
from .mcp_validator import McpProtocolValidator
from .workflow_validator import WorkflowExecutionValidator
from .integration_validator import IntegrationValidator


class ValidationOrchestrator:
    """Orchestrates comprehensive validation of the RPA plugin architecture"""
    
    def __init__(self):
        self.plugin_validator = PluginArchitectureValidator()
        self.mcp_validator = McpProtocolValidator()
        self.workflow_validator = WorkflowExecutionValidator()
        self.integration_validator = IntegrationValidator()
        self.validation_results = {}
    
    async def execute_comprehensive_validation(
        self,
        plugin_config: Dict[str, Any],
        span: Optional[Span] = None
    ) -> Dict[str, Any]:
        """Execute comprehensive validation of the entire RPA plugin architecture"""
        try:
            if span:
                span.add_info_events(action="execute_comprehensive_validation")
            
            validation_start = datetime.utcnow()
            validation_id = f"comprehensive_validation_{int(time.time())}"
            
            results = {
                "validation_id": validation_id,
                "started_at": validation_start.isoformat(),
                "plugin_config": plugin_config,
                "validation_phases": {},
                "overall_status": "running",
                "summary": {}
            }
            
            logger.info(f"Starting comprehensive validation {validation_id}")
            
            # Phase 1: Plugin Architecture Validation
            logger.info("Phase 1: Plugin Architecture Validation")
            plugin_result = await self.plugin_validator.validate_plugin_architecture(
                plugin_config, span
            )
            results["validation_phases"]["plugin_architecture"] = plugin_result
            
            # Phase 2: MCP Protocol Compliance
            logger.info("Phase 2: MCP Protocol Compliance")
            mcp_result = await self.mcp_validator.validate_mcp_compliance(
                plugin_config, span
            )
            results["validation_phases"]["mcp_protocol"] = mcp_result
            
            # Phase 3: Workflow Execution Validation
            logger.info("Phase 3: Workflow Execution Validation")
            workflow_config = self._create_test_workflow_config()
            workflow_result = await self.workflow_validator.validate_workflow_execution(
                workflow_config, plugin_config, span
            )
            results["validation_phases"]["workflow_execution"] = workflow_result
            
            # Phase 4: Integration Validation
            logger.info("Phase 4: Integration Validation")
            integration_result = await self.integration_validator.validate_complete_integration(
                plugin_config, span
            )
            results["validation_phases"]["integration"] = integration_result
            
            # Calculate comprehensive summary
            results["summary"] = self._calculate_comprehensive_summary(
                results["validation_phases"]
            )
            results["overall_status"] = "completed"
            results["completed_at"] = datetime.utcnow().isoformat()
            results["total_duration_seconds"] = (
                datetime.utcnow() - validation_start
            ).total_seconds()
            
            # Store results
            self.validation_results[validation_id] = results
            
            logger.info(f"Comprehensive validation {validation_id} completed")
            
            return results
            
        except Exception as e:
            logger.error(f"Comprehensive validation failed: {str(e)}")
            raise
    
    def _create_test_workflow_config(self) -> Dict[str, Any]:
        """Create a test workflow configuration for validation"""
        return {
            "workflow_id": "validation_test_workflow",
            "workflow_type": "comprehensive_test",
            "components": [
                "rpabrowser", "rpanetwork", "rpadatabase", 
                "rpaai", "rpasystem"
            ],
            "execution_pattern": "hybrid",
            "parameters": {
                "test_mode": True,
                "validation_level": "comprehensive",
                "timeout": 300,
                "retry_count": 2
            },
            "validation_rules": {
                "min_success_rate": 0.8,
                "max_execution_time": 600,
                "required_components": ["rpabrowser", "rpanetwork"]
            }
        }
    
    def _calculate_comprehensive_summary(
        self, 
        validation_phases: Dict[str, Any]
    ) -> Dict[str, Any]:
        """Calculate comprehensive validation summary"""
        
        phase_results = {}
        overall_scores = []
        critical_failures = []
        
        # Analyze each validation phase
        for phase_name, phase_result in validation_phases.items():
            phase_summary = self._extract_phase_summary(phase_name, phase_result)
            phase_results[phase_name] = phase_summary
            
            # Collect overall scores
            if "success_rate" in phase_summary:
                overall_scores.append(phase_summary["success_rate"])
            elif "compliance_rate" in phase_summary:
                overall_scores.append(phase_summary["compliance_rate"])
            
            # Identify critical failures
            if phase_summary.get("status") == "failed":
                critical_failures.append({
                    "phase": phase_name,
                    "reason": phase_summary.get("primary_failure_reason", "Unknown failure")
                })
        
        # Calculate overall metrics
        overall_success_rate = sum(overall_scores) / len(overall_scores) if overall_scores else 0
        
        # Determine overall status
        if len(critical_failures) == 0 and overall_success_rate >= 90:
            overall_status = "excellent"
        elif len(critical_failures) == 0 and overall_success_rate >= 80:
            overall_status = "good"
        elif len(critical_failures) <= 1 and overall_success_rate >= 70:
            overall_status = "acceptable"
        elif overall_success_rate >= 50:
            overall_status = "needs_improvement"
        else:
            overall_status = "poor"
        
        # Generate recommendations
        recommendations = self._generate_comprehensive_recommendations(
            phase_results, critical_failures, overall_success_rate
        )
        
        return {
            "overall_success_rate": round(overall_success_rate, 2),
            "overall_status": overall_status,
            "phase_results": phase_results,
            "critical_failures": critical_failures,
            "total_phases": len(validation_phases),
            "passed_phases": sum(1 for p in phase_results.values() if p["status"] == "passed"),
            "failed_phases": len(critical_failures),
            "recommendations": recommendations,
            "production_readiness": self._assess_production_readiness(
                overall_success_rate, critical_failures
            )
        }
    
    def _extract_phase_summary(self, phase_name: str, phase_result: Dict[str, Any]) -> Dict[str, Any]:
        """Extract summary from a validation phase result"""
        
        if phase_name == "plugin_architecture":
            summary = phase_result.get("summary", {})
            return {
                "status": summary.get("overall_status", "unknown"),
                "success_rate": summary.get("success_rate", 0),
                "total_tests": summary.get("total_tests", 0),
                "passed_tests": summary.get("passed_tests", 0),
                "primary_failure_reason": self._get_primary_failure_reason(phase_result)
            }
        
        elif phase_name == "mcp_protocol":
            summary = phase_result.get("compliance_summary", {})
            return {
                "status": summary.get("overall_status", "unknown"),
                "compliance_rate": summary.get("compliance_rate", 0),
                "total_tests": summary.get("total_tests", 0),
                "passed_tests": summary.get("passed_tests", 0),
                "primary_failure_reason": self._get_primary_failure_reason(phase_result)
            }
        
        elif phase_name == "workflow_execution":
            summary = phase_result.get("summary", {})
            return {
                "status": summary.get("overall_status", "unknown"),
                "success_rate": summary.get("success_rate", 0),
                "total_scenarios": summary.get("total_scenarios", 0),
                "passed_scenarios": summary.get("passed_scenarios", 0),
                "primary_failure_reason": self._get_primary_failure_reason(phase_result)
            }
        
        elif phase_name == "integration":
            summary = phase_result.get("summary", {})
            return {
                "status": summary.get("overall_status", "unknown"),
                "success_rate": summary.get("success_rate", 0),
                "critical_success_rate": summary.get("critical_success_rate", 0),
                "total_scenarios": summary.get("total_scenarios", 0),
                "passed_scenarios": summary.get("passed_scenarios", 0),
                "primary_failure_reason": self._get_primary_failure_reason(phase_result)
            }
        
        else:
            return {
                "status": "unknown",
                "success_rate": 0,
                "primary_failure_reason": "Unknown phase type"
            }
    
    def _get_primary_failure_reason(self, phase_result: Dict[str, Any]) -> Optional[str]:
        """Extract the primary failure reason from a phase result"""
        
        # Look for error messages in various places
        if "error" in phase_result:
            return phase_result["error"]
        
        # Look for failed scenarios/tests
        scenarios = phase_result.get("scenarios", {})
        if scenarios:
            failed_scenarios = [
                name for name, result in scenarios.items()
                if result.get("status") == "failed"
            ]
            if failed_scenarios:
                return f"Failed scenarios: {', '.join(failed_scenarios[:3])}"
        
        # Look for failed tests
        tests = phase_result.get("compliance_tests", {})
        if tests:
            failed_tests = [
                name for name, result in tests.items()
                if result.get("status") == "failed"
            ]
            if failed_tests:
                return f"Failed tests: {', '.join(failed_tests[:3])}"
        
        return None
    
    def _generate_comprehensive_recommendations(
        self,
        phase_results: Dict[str, Any],
        critical_failures: List[Dict[str, Any]],
        overall_success_rate: float
    ) -> List[Dict[str, Any]]:
        """Generate comprehensive recommendations based on validation results"""
        
        recommendations = []
        
        # Critical failure recommendations
        for failure in critical_failures:
            recommendations.append({
                "priority": "critical",
                "category": "failure_resolution",
                "title": f"Resolve {failure['phase']} failures",
                "description": f"Address critical failures in {failure['phase']}: {failure['reason']}",
                "impact": "high"
            })
        
        # Phase-specific recommendations
        for phase_name, phase_result in phase_results.items():
            if phase_result["status"] == "failed":
                recommendations.append({
                    "priority": "high",
                    "category": "phase_improvement",
                    "title": f"Improve {phase_name} validation",
                    "description": f"Address issues in {phase_name} to improve success rate",
                    "impact": "medium"
                })
            elif phase_result.get("success_rate", 0) < 90:
                recommendations.append({
                    "priority": "medium",
                    "category": "optimization",
                    "title": f"Optimize {phase_name} performance",
                    "description": f"Fine-tune {phase_name} to achieve higher success rates",
                    "impact": "low"
                })
        
        # Overall system recommendations
        if overall_success_rate < 80:
            recommendations.append({
                "priority": "high",
                "category": "system_improvement",
                "title": "Comprehensive system improvements needed",
                "description": "Overall success rate is below acceptable threshold",
                "impact": "high"
            })
        elif overall_success_rate < 95:
            recommendations.append({
                "priority": "medium",
                "category": "system_optimization",
                "title": "System optimization opportunities",
                "description": "Fine-tune system components for better performance",
                "impact": "medium"
            })
        
        # Production readiness recommendations
        if len(critical_failures) > 0:
            recommendations.append({
                "priority": "critical",
                "category": "production_readiness",
                "title": "Not ready for production deployment",
                "description": "Critical failures must be resolved before production use",
                "impact": "high"
            })
        elif overall_success_rate >= 90:
            recommendations.append({
                "priority": "low",
                "category": "production_readiness",
                "title": "Ready for production deployment",
                "description": "System meets production readiness criteria",
                "impact": "positive"
            })
        
        return recommendations
    
    def _assess_production_readiness(
        self,
        overall_success_rate: float,
        critical_failures: List[Dict[str, Any]]
    ) -> Dict[str, Any]:
        """Assess production readiness based on validation results"""
        
        # Production readiness criteria
        criteria = {
            "no_critical_failures": len(critical_failures) == 0,
            "high_success_rate": overall_success_rate >= 90,
            "acceptable_success_rate": overall_success_rate >= 80,
            "minimum_success_rate": overall_success_rate >= 70
        }
        
        # Determine readiness level
        if criteria["no_critical_failures"] and criteria["high_success_rate"]:
            readiness_level = "production_ready"
            readiness_score = 10
        elif criteria["no_critical_failures"] and criteria["acceptable_success_rate"]:
            readiness_level = "production_ready_with_monitoring"
            readiness_score = 8
        elif criteria["no_critical_failures"] and criteria["minimum_success_rate"]:
            readiness_level = "staging_ready"
            readiness_score = 6
        elif criteria["minimum_success_rate"]:
            readiness_level = "development_ready"
            readiness_score = 4
        else:
            readiness_level = "not_ready"
            readiness_score = 2
        
        return {
            "readiness_level": readiness_level,
            "readiness_score": readiness_score,
            "criteria_met": criteria,
            "blocking_issues": len(critical_failures),
            "recommendation": self._get_readiness_recommendation(readiness_level)
        }
    
    def _get_readiness_recommendation(self, readiness_level: str) -> str:
        """Get recommendation based on readiness level"""
        
        recommendations = {
            "production_ready": "System is ready for production deployment with confidence",
            "production_ready_with_monitoring": "System can be deployed to production with enhanced monitoring",
            "staging_ready": "System is ready for staging environment testing",
            "development_ready": "System is suitable for development and testing environments only",
            "not_ready": "System requires significant improvements before any deployment"
        }
        
        return recommendations.get(readiness_level, "Unknown readiness level")
    
    async def get_validation_report(self, validation_id: str) -> Optional[Dict[str, Any]]:
        """Get a comprehensive validation report by ID"""
        return self.validation_results.get(validation_id)
    
    async def list_validation_results(self) -> List[Dict[str, Any]]:
        """List all validation results with summary information"""
        return [
            {
                "validation_id": validation_id,
                "started_at": result["started_at"],
                "completed_at": result.get("completed_at"),
                "overall_status": result.get("overall_status"),
                "success_rate": result.get("summary", {}).get("overall_success_rate", 0),
                "production_readiness": result.get("summary", {}).get("production_readiness", {}).get("readiness_level")
            }
            for validation_id, result in self.validation_results.items()
        ]
