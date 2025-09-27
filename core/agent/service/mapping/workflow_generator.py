"""
Workflow Generation Service

Generates executable workflows from component mappings and PRD analysis.
"""

import asyncio
import json
from typing import Any, Dict, List, Optional
from datetime import datetime, timedelta

from common_imports import logger


class WorkflowGenerationService:
    """Service for generating executable workflows from component mappings"""
    
    def __init__(self):
        self.workflow_templates = self._initialize_workflow_templates()
        self.execution_patterns = self._initialize_execution_patterns()
    
    def _initialize_workflow_templates(self) -> Dict[str, Dict[str, Any]]:
        """Initialize workflow templates for different component categories"""
        return {
            "ui_testing": {
                "template_name": "UI Testing Workflow",
                "steps": [
                    {"action": "setup_browser", "component": "rpabrowser", "timeout": 30},
                    {"action": "navigate_to_page", "component": "rpabrowser", "timeout": 10},
                    {"action": "validate_page_load", "component": "rpacv", "timeout": 15},
                    {"action": "interact_with_elements", "component": "rpabrowser", "timeout": 60},
                    {"action": "capture_screenshots", "component": "rpacv", "timeout": 10},
                    {"action": "validate_results", "component": "rpacv", "timeout": 20}
                ],
                "error_handling": "retry_on_failure",
                "cleanup_required": True
            },
            "api_testing": {
                "template_name": "API Testing Workflow",
                "steps": [
                    {"action": "setup_client", "component": "rpanetwork", "timeout": 10},
                    {"action": "authenticate", "component": "rpanetwork", "timeout": 15},
                    {"action": "validate_endpoints", "component": "rpaopenapi", "timeout": 30},
                    {"action": "execute_requests", "component": "rpanetwork", "timeout": 45},
                    {"action": "validate_responses", "component": "rpaopenapi", "timeout": 20},
                    {"action": "generate_report", "component": "rpanetwork", "timeout": 10}
                ],
                "error_handling": "fail_fast",
                "cleanup_required": False
            },
            "data_processing": {
                "template_name": "Data Processing Workflow",
                "steps": [
                    {"action": "setup_connections", "component": "rpadatabase", "timeout": 20},
                    {"action": "load_data_sources", "component": "rpaexcel", "timeout": 30},
                    {"action": "process_documents", "component": "rpapdf", "timeout": 60},
                    {"action": "transform_data", "component": "rpadatabase", "timeout": 45},
                    {"action": "generate_reports", "component": "rpadocx", "timeout": 30},
                    {"action": "validate_outputs", "component": "rpaexcel", "timeout": 15}
                ],
                "error_handling": "rollback_on_failure",
                "cleanup_required": True
            },
            "ai_processing": {
                "template_name": "AI Processing Workflow",
                "steps": [
                    {"action": "initialize_ai_models", "component": "rpaai", "timeout": 60},
                    {"action": "analyze_content", "component": "rpaai", "timeout": 120},
                    {"action": "verify_code_quality", "component": "rpaverifycode", "timeout": 90},
                    {"action": "generate_insights", "component": "rpaai", "timeout": 60},
                    {"action": "validate_results", "component": "rpaverifycode", "timeout": 30}
                ],
                "error_handling": "graceful_degradation",
                "cleanup_required": False
            },
            "system_automation": {
                "template_name": "System Automation Workflow",
                "steps": [
                    {"action": "setup_environment", "component": "rpasystem", "timeout": 30},
                    {"action": "configure_security", "component": "rpaencrypt", "timeout": 20},
                    {"action": "setup_notifications", "component": "rpaemail", "timeout": 15},
                    {"action": "initialize_integrations", "component": "rpaenterprise", "timeout": 45},
                    {"action": "validate_setup", "component": "rpasystem", "timeout": 20}
                ],
                "error_handling": "stop_on_critical_failure",
                "cleanup_required": True
            }
        }
    
    def _initialize_execution_patterns(self) -> Dict[str, Dict[str, Any]]:
        """Initialize execution patterns for different workflow types"""
        return {
            "sequential": {
                "description": "Execute steps one after another",
                "parallelism": 1,
                "suitable_for": ["data_processing", "system_automation"]
            },
            "parallel": {
                "description": "Execute independent steps in parallel",
                "parallelism": 3,
                "suitable_for": ["ui_testing", "api_testing"]
            },
            "pipeline": {
                "description": "Execute steps in pipeline with data flow",
                "parallelism": 2,
                "suitable_for": ["ai_processing", "data_processing"]
            },
            "hybrid": {
                "description": "Mix of sequential and parallel execution",
                "parallelism": 2,
                "suitable_for": ["comprehensive_workflows"]
            }
        }
    
    async def generate_workflow_from_mappings(
        self,
        component_mappings: Dict[str, Any],
        execution_plan: Dict[str, Any],
        project_config: Dict[str, Any]
    ) -> Dict[str, Any]:
        """Generate executable workflow from component mappings"""
        try:
            workflows = []
            
            # Generate workflow for each phase in execution plan
            for phase in execution_plan.get("phases", []):
                category = phase["category"]
                components = phase["components"]
                
                # Get template for this category
                template = self.workflow_templates.get(category)
                if not template:
                    logger.warning(f"No template found for category: {category}")
                    continue
                
                # Generate workflow for this phase
                workflow = await self._generate_category_workflow(
                    category, components, template, phase, project_config
                )
                
                workflows.append(workflow)
            
            # Determine overall execution pattern
            execution_pattern = self._determine_execution_pattern(workflows, project_config)
            
            # Generate master workflow
            master_workflow = await self._generate_master_workflow(
                workflows, execution_pattern, project_config
            )
            
            return {
                "master_workflow": master_workflow,
                "category_workflows": workflows,
                "execution_pattern": execution_pattern,
                "total_estimated_duration": sum(w["estimated_duration_minutes"] for w in workflows),
                "generated_at": datetime.utcnow().isoformat()
            }
            
        except Exception as e:
            logger.error(f"Workflow generation failed: {str(e)}")
            raise
    
    async def _generate_category_workflow(
        self,
        category: str,
        components: List[str],
        template: Dict[str, Any],
        phase: Dict[str, Any],
        project_config: Dict[str, Any]
    ) -> Dict[str, Any]:
        """Generate workflow for a specific category"""
        
        workflow_steps = []
        
        # Customize template steps based on available components
        for step_template in template["steps"]:
            if step_template["component"] in components:
                # Customize step based on project config
                step = await self._customize_workflow_step(
                    step_template, project_config, category
                )
                workflow_steps.append(step)
        
        # Add validation steps
        validation_steps = await self._generate_validation_steps(
            category, components, project_config
        )
        workflow_steps.extend(validation_steps)
        
        return {
            "workflow_id": f"{category}_{phase['phase']}",
            "name": template["template_name"],
            "category": category,
            "phase": phase["phase"],
            "components": components,
            "steps": workflow_steps,
            "error_handling": template["error_handling"],
            "cleanup_required": template["cleanup_required"],
            "estimated_duration_minutes": phase["estimated_duration_minutes"],
            "dependencies": phase.get("dependencies", []),
            "parallel_execution": len(workflow_steps) > 3
        }
    
    async def _customize_workflow_step(
        self,
        step_template: Dict[str, Any],
        project_config: Dict[str, Any],
        category: str
    ) -> Dict[str, Any]:
        """Customize a workflow step based on project configuration"""
        
        step = step_template.copy()
        
        # Add project-specific parameters
        step["parameters"] = {}
        
        # Customize based on category
        if category == "ui_testing":
            step["parameters"].update({
                "browser_type": project_config.get("browser", "chromium"),
                "headless": project_config.get("headless", True),
                "viewport": project_config.get("viewport", {"width": 1920, "height": 1080})
            })
        elif category == "api_testing":
            step["parameters"].update({
                "base_url": project_config.get("api_base_url", "http://localhost:8000"),
                "timeout": project_config.get("api_timeout", 30),
                "verify_ssl": project_config.get("verify_ssl", True)
            })
        elif category == "data_processing":
            step["parameters"].update({
                "batch_size": project_config.get("batch_size", 1000),
                "parallel_processing": project_config.get("parallel_processing", True),
                "data_validation": project_config.get("data_validation", True)
            })
        elif category == "ai_processing":
            step["parameters"].update({
                "model": project_config.get("ai_model", "gpt-4"),
                "temperature": project_config.get("temperature", 0.7),
                "max_tokens": project_config.get("max_tokens", 2000)
            })
        elif category == "system_automation":
            step["parameters"].update({
                "platform": project_config.get("platform", "linux"),
                "security_level": project_config.get("security_level", "standard"),
                "monitoring_enabled": project_config.get("monitoring", True)
            })
        
        # Add common parameters
        step["parameters"].update({
            "retry_count": project_config.get("retry_count", 3),
            "log_level": project_config.get("log_level", "INFO"),
            "capture_screenshots": project_config.get("capture_screenshots", True)
        })
        
        return step
    
    async def _generate_validation_steps(
        self,
        category: str,
        components: List[str],
        project_config: Dict[str, Any]
    ) -> List[Dict[str, Any]]:
        """Generate validation steps for a category"""
        
        validation_steps = []
        
        # Common validation step
        validation_steps.append({
            "action": "validate_execution",
            "component": "validation_engine",
            "timeout": 30,
            "parameters": {
                "validation_type": f"{category}_validation",
                "confidence_threshold": project_config.get("confidence_threshold", 0.8),
                "strict_mode": project_config.get("strict_validation", False)
            }
        })
        
        # Category-specific validation
        if category == "ui_testing":
            validation_steps.append({
                "action": "validate_ui_elements",
                "component": "rpacv",
                "timeout": 20,
                "parameters": {
                    "element_validation": True,
                    "accessibility_check": project_config.get("accessibility_check", True)
                }
            })
        elif category == "api_testing":
            validation_steps.append({
                "action": "validate_api_contracts",
                "component": "rpaopenapi",
                "timeout": 25,
                "parameters": {
                    "schema_validation": True,
                    "response_validation": True
                }
            })
        elif category == "data_processing":
            validation_steps.append({
                "action": "validate_data_integrity",
                "component": "rpadatabase",
                "timeout": 35,
                "parameters": {
                    "data_consistency_check": True,
                    "referential_integrity": True
                }
            })
        
        return validation_steps
    
    def _determine_execution_pattern(
        self,
        workflows: List[Dict[str, Any]],
        project_config: Dict[str, Any]
    ) -> str:
        """Determine the best execution pattern for the workflows"""
        
        # Analyze workflow characteristics
        total_workflows = len(workflows)
        has_dependencies = any(w.get("dependencies") for w in workflows)
        avg_duration = sum(w["estimated_duration_minutes"] for w in workflows) / total_workflows if workflows else 0
        
        # Determine pattern based on characteristics
        if total_workflows == 1:
            return "sequential"
        elif has_dependencies and avg_duration > 30:
            return "pipeline"
        elif not has_dependencies and total_workflows <= 3:
            return "parallel"
        else:
            return "hybrid"
    
    async def _generate_master_workflow(
        self,
        workflows: List[Dict[str, Any]],
        execution_pattern: str,
        project_config: Dict[str, Any]
    ) -> Dict[str, Any]:
        """Generate master workflow that orchestrates all category workflows"""
        
        pattern_config = self.execution_patterns[execution_pattern]
        
        master_steps = []
        
        # Add initialization step
        master_steps.append({
            "action": "initialize_execution_environment",
            "component": "workflow_orchestrator",
            "timeout": 60,
            "parameters": {
                "execution_pattern": execution_pattern,
                "parallelism": pattern_config["parallelism"],
                "total_workflows": len(workflows)
            }
        })
        
        # Add workflow execution steps based on pattern
        if execution_pattern == "sequential":
            for workflow in workflows:
                master_steps.append({
                    "action": "execute_workflow",
                    "component": "workflow_executor",
                    "timeout": workflow["estimated_duration_minutes"] * 60,
                    "parameters": {
                        "workflow_id": workflow["workflow_id"],
                        "category": workflow["category"],
                        "wait_for_completion": True
                    }
                })
        
        elif execution_pattern == "parallel":
            # Group workflows for parallel execution
            master_steps.append({
                "action": "execute_workflows_parallel",
                "component": "workflow_executor",
                "timeout": max(w["estimated_duration_minutes"] for w in workflows) * 60,
                "parameters": {
                    "workflow_ids": [w["workflow_id"] for w in workflows],
                    "max_parallelism": pattern_config["parallelism"]
                }
            })
        
        elif execution_pattern == "pipeline":
            # Create pipeline execution
            for i, workflow in enumerate(workflows):
                master_steps.append({
                    "action": "execute_workflow_pipeline_stage",
                    "component": "workflow_executor",
                    "timeout": workflow["estimated_duration_minutes"] * 60,
                    "parameters": {
                        "workflow_id": workflow["workflow_id"],
                        "stage": i + 1,
                        "wait_for_previous": i > 0
                    }
                })
        
        else:  # hybrid
            # Mix of sequential and parallel based on dependencies
            independent_workflows = [w for w in workflows if not w.get("dependencies")]
            dependent_workflows = [w for w in workflows if w.get("dependencies")]
            
            if independent_workflows:
                master_steps.append({
                    "action": "execute_independent_workflows",
                    "component": "workflow_executor",
                    "timeout": max(w["estimated_duration_minutes"] for w in independent_workflows) * 60,
                    "parameters": {
                        "workflow_ids": [w["workflow_id"] for w in independent_workflows],
                        "parallel_execution": True
                    }
                })
            
            for workflow in dependent_workflows:
                master_steps.append({
                    "action": "execute_dependent_workflow",
                    "component": "workflow_executor",
                    "timeout": workflow["estimated_duration_minutes"] * 60,
                    "parameters": {
                        "workflow_id": workflow["workflow_id"],
                        "dependencies": workflow["dependencies"]
                    }
                })
        
        # Add final validation step
        master_steps.append({
            "action": "validate_overall_execution",
            "component": "validation_engine",
            "timeout": 120,
            "parameters": {
                "validation_type": "comprehensive",
                "workflows_validated": len(workflows),
                "success_criteria": project_config.get("success_criteria", {})
            }
        })
        
        # Add cleanup step
        master_steps.append({
            "action": "cleanup_execution_environment",
            "component": "workflow_orchestrator",
            "timeout": 30,
            "parameters": {
                "cleanup_level": project_config.get("cleanup_level", "standard"),
                "preserve_logs": project_config.get("preserve_logs", True)
            }
        })
        
        return {
            "workflow_id": "master_workflow",
            "name": "Master Execution Workflow",
            "execution_pattern": execution_pattern,
            "steps": master_steps,
            "total_steps": len(master_steps),
            "estimated_duration_minutes": sum(w["estimated_duration_minutes"] for w in workflows) + 10,
            "parallelism": pattern_config["parallelism"],
            "error_handling": "comprehensive_rollback",
            "monitoring_enabled": True
        }
    
    async def optimize_workflow_performance(
        self,
        workflow: Dict[str, Any],
        performance_targets: Dict[str, Any]
    ) -> Dict[str, Any]:
        """Optimize workflow for performance based on targets"""
        
        optimized_workflow = workflow.copy()
        optimizations_applied = []
        
        # Optimize timeouts
        if performance_targets.get("reduce_timeouts"):
            for step in optimized_workflow["steps"]:
                original_timeout = step["timeout"]
                step["timeout"] = max(original_timeout * 0.8, 10)  # Reduce by 20%, minimum 10s
            optimizations_applied.append("timeout_optimization")
        
        # Optimize parallelism
        if performance_targets.get("increase_parallelism") and optimized_workflow.get("parallel_execution"):
            optimized_workflow["parallelism"] = min(
                optimized_workflow.get("parallelism", 1) * 2, 
                performance_targets.get("max_parallelism", 5)
            )
            optimizations_applied.append("parallelism_optimization")
        
        # Optimize step ordering
        if performance_targets.get("optimize_step_order"):
            optimized_workflow["steps"] = await self._optimize_step_order(
                optimized_workflow["steps"]
            )
            optimizations_applied.append("step_order_optimization")
        
        # Add caching where appropriate
        if performance_targets.get("enable_caching"):
            for step in optimized_workflow["steps"]:
                if step["action"] in ["validate_execution", "analyze_content", "process_documents"]:
                    step["parameters"]["enable_caching"] = True
            optimizations_applied.append("caching_optimization")
        
        optimized_workflow["optimizations_applied"] = optimizations_applied
        optimized_workflow["optimization_timestamp"] = datetime.utcnow().isoformat()
        
        return optimized_workflow
    
    async def _optimize_step_order(self, steps: List[Dict[str, Any]]) -> List[Dict[str, Any]]:
        """Optimize the order of workflow steps for better performance"""
        
        # Separate steps by type
        setup_steps = [s for s in steps if "setup" in s["action"] or "initialize" in s["action"]]
        processing_steps = [s for s in steps if "process" in s["action"] or "execute" in s["action"]]
        validation_steps = [s for s in steps if "validate" in s["action"]]
        cleanup_steps = [s for s in steps if "cleanup" in s["action"]]
        
        # Sort processing steps by estimated duration (shortest first for quick wins)
        processing_steps.sort(key=lambda x: x.get("timeout", 60))
        
        # Reorder: setup -> processing -> validation -> cleanup
        optimized_order = setup_steps + processing_steps + validation_steps + cleanup_steps
        
        return optimized_order
