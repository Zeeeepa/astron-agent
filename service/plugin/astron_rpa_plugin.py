"""
Astron-RPA MCP Plugin

Provides seamless integration between Astron-Agent and Astron-RPA
through the Model Context Protocol (MCP).
"""

import asyncio
import time
from typing import Any, Dict, List, Optional, AsyncIterator

from pydantic import BaseModel, Field

from service.plugin.mcp import McpPlugin
from common_imports import logger, Span


class RpaWorkflowConfig(BaseModel):
    """Configuration for RPA workflow execution"""
    
    workflow_type: str = Field(..., description="Type of workflow to execute")
    components: List[str] = Field(default_factory=list, description="RPA components to use")
    parameters: Dict[str, Any] = Field(default_factory=dict, description="Workflow parameters")
    timeout: int = Field(default=300, description="Execution timeout in seconds")
    retry_count: int = Field(default=3, description="Number of retry attempts")


class RpaExecutionResult(BaseModel):
    """Result of RPA workflow execution"""
    
    success: bool = Field(..., description="Whether execution was successful")
    result: Optional[Dict[str, Any]] = Field(default=None, description="Execution result data")
    error: Optional[str] = Field(default=None, description="Error message if failed")
    execution_time: int = Field(..., description="Execution time in seconds")
    components_used: List[str] = Field(default_factory=list, description="Components that were used")


class ValidationResult(BaseModel):
    """Result of autonomous validation"""
    
    overall_valid: bool = Field(..., description="Overall validation result")
    ui_valid: bool = Field(default=False, description="UI validation result")
    api_valid: bool = Field(default=False, description="API validation result")
    integration_valid: bool = Field(default=False, description="Integration validation result")
    validation_results: Dict[str, Any] = Field(default_factory=dict, description="Detailed validation results")
    timestamp: int = Field(default_factory=lambda: int(time.time()), description="Validation timestamp")


class AstronRpaPlugin(McpPlugin):
    """Enhanced MCP Plugin for Astron-RPA integration"""
    
    def __init__(self, 
                 rpa_openapi_url: str = "http://astron-rpa:8020",
                 api_key: Optional[str] = None):
        """
        Initialize Astron-RPA plugin
        
        Args:
            rpa_openapi_url: Base URL for Astron-RPA OpenAPI service
            api_key: Optional API key for authentication
        """
        self.rpa_openapi_url = rpa_openapi_url
        self.api_key = api_key
        
        # Component mapping for intelligent workflow selection
        self.component_mapping = {
            "ui_testing": ["rpabrowser", "rpacv", "rpawindow"],
            "api_testing": ["rpanetwork", "rpaopenapi"],
            "data_processing": ["rpadatabase", "rpaexcel", "rpapdf", "rpadocx"],
            "ai_processing": ["rpaai", "rpaverifycode"],
            "system_automation": ["rpasystem", "rpaencrypt", "rpaemail", "rpaenterprise"]
        }
        
        super().__init__(
            name="astron_rpa",
            description="Execute RPA workflows for CI/CD automation",
            server_url=f"{rpa_openapi_url}/mcp",
            timeout=40.0
        )
    
    async def execute_component_workflow(self, 
                                       component_category: str, 
                                       workflow_config: RpaWorkflowConfig,
                                       span: Span) -> RpaExecutionResult:
        """
        Execute workflow using specific RPA component category
        
        Args:
            component_category: Category of RPA components to use
            workflow_config: Workflow configuration
            span: Tracing span for observability
            
        Returns:
            RpaExecutionResult with execution details
        """
        start_time = time.time()
        
        try:
            # Get components for category
            components = self.component_mapping.get(component_category, [])
            if not components:
                raise ValueError(f"Unknown component category: {component_category}")
            
            # Update workflow config with components
            workflow_config.components = components
            
            # Execute workflow via MCP
            result = await self.run({
                "action": "execute_workflow",
                "workflow_type": workflow_config.workflow_type,
                "components": components,
                "parameters": workflow_config.parameters,
                "timeout": workflow_config.timeout,
                "engine_version": "python3.13+"
            })
            
            execution_time = int(time.time() - start_time)
            
            # Add span information
            span.add_info_events(
                component_category=component_category,
                components_used=components,
                execution_time=execution_time,
                workflow_type=workflow_config.workflow_type
            )
            
            return RpaExecutionResult(
                success=True,
                result=result,
                execution_time=execution_time,
                components_used=components
            )
            
        except Exception as e:
            execution_time = int(time.time() - start_time)
            error_msg = f"RPA workflow execution failed: {str(e)}"
            
            logger.error(error_msg, extra={
                "component_category": component_category,
                "workflow_type": workflow_config.workflow_type,
                "execution_time": execution_time
            })
            
            span.add_info_events(
                error=error_msg,
                component_category=component_category,
                execution_time=execution_time
            )
            
            return RpaExecutionResult(
                success=False,
                error=error_msg,
                execution_time=execution_time,
                components_used=self.component_mapping.get(component_category, [])
            )
    
    async def execute_autonomous_validation(self,
                                          task_result: Dict[str, Any],
                                          expected_behavior: Dict[str, Any],
                                          span: Span) -> ValidationResult:
        """
        Execute autonomous validation using RPA components
        
        Args:
            task_result: Results from task execution
            expected_behavior: Expected behavior specification
            span: Tracing span for observability
            
        Returns:
            ValidationResult with comprehensive validation details
        """
        try:
            validation_results = {}
            
            # UI Validation using browser automation
            ui_result = await self._validate_ui_behavior(task_result, expected_behavior, span)
            validation_results["ui_validation"] = ui_result
            
            # API Validation using network components
            api_result = await self._validate_api_behavior(task_result, expected_behavior, span)
            validation_results["api_validation"] = api_result
            
            # Integration Validation using system components
            integration_result = await self._validate_integration(task_result, expected_behavior, span)
            validation_results["integration_validation"] = integration_result
            
            # Determine overall validation result
            overall_valid = all([
                ui_result.get("success", False),
                api_result.get("success", False),
                integration_result.get("success", False)
            ])
            
            span.add_info_events(
                overall_valid=overall_valid,
                ui_valid=ui_result.get("success", False),
                api_valid=api_result.get("success", False),
                integration_valid=integration_result.get("success", False)
            )
            
            return ValidationResult(
                overall_valid=overall_valid,
                ui_valid=ui_result.get("success", False),
                api_valid=api_result.get("success", False),
                integration_valid=integration_result.get("success", False),
                validation_results=validation_results
            )
            
        except Exception as e:
            error_msg = f"Autonomous validation failed: {str(e)}"
            logger.error(error_msg)
            
            span.add_info_events(error=error_msg)
            
            return ValidationResult(
                overall_valid=False,
                validation_results={"error": error_msg}
            )
    
    async def _validate_ui_behavior(self, 
                                  task_result: Dict[str, Any], 
                                  expected_behavior: Dict[str, Any],
                                  span: Span) -> Dict[str, Any]:
        """Validate UI behavior using browser automation components"""
        try:
            ui_config = RpaWorkflowConfig(
                workflow_type="ui_validation",
                parameters={
                    "target_url": expected_behavior.get("ui", {}).get("target_url"),
                    "expected_elements": expected_behavior.get("ui", {}).get("elements", []),
                    "validation_rules": expected_behavior.get("ui", {}).get("rules", [])
                }
            )
            
            result = await self.execute_component_workflow("ui_testing", ui_config, span)
            return {
                "success": result.success,
                "details": result.result,
                "components_used": result.components_used
            }
            
        except Exception as e:
            return {
                "success": False,
                "error": str(e),
                "components_used": self.component_mapping["ui_testing"]
            }
    
    async def _validate_api_behavior(self, 
                                   task_result: Dict[str, Any], 
                                   expected_behavior: Dict[str, Any],
                                   span: Span) -> Dict[str, Any]:
        """Validate API behavior using network components"""
        try:
            api_config = RpaWorkflowConfig(
                workflow_type="api_validation",
                parameters={
                    "endpoints": expected_behavior.get("api", {}).get("endpoints", []),
                    "expected_responses": expected_behavior.get("api", {}).get("responses", {}),
                    "validation_rules": expected_behavior.get("api", {}).get("rules", [])
                }
            )
            
            result = await self.execute_component_workflow("api_testing", api_config, span)
            return {
                "success": result.success,
                "details": result.result,
                "components_used": result.components_used
            }
            
        except Exception as e:
            return {
                "success": False,
                "error": str(e),
                "components_used": self.component_mapping["api_testing"]
            }
    
    async def _validate_integration(self, 
                                  task_result: Dict[str, Any], 
                                  expected_behavior: Dict[str, Any],
                                  span: Span) -> Dict[str, Any]:
        """Validate integration using system components"""
        try:
            integration_config = RpaWorkflowConfig(
                workflow_type="integration_validation",
                parameters={
                    "system_checks": expected_behavior.get("integration", {}).get("checks", []),
                    "data_validation": expected_behavior.get("integration", {}).get("data", {}),
                    "performance_thresholds": expected_behavior.get("integration", {}).get("performance", {})
                }
            )
            
            result = await self.execute_component_workflow("system_automation", integration_config, span)
            return {
                "success": result.success,
                "details": result.result,
                "components_used": result.components_used
            }
            
        except Exception as e:
            return {
                "success": False,
                "error": str(e),
                "components_used": self.component_mapping["system_automation"]
            }
    
    async def create_prd_workflows(self, 
                                 prd_content: str, 
                                 project_config: Dict[str, Any],
                                 span: Span) -> Dict[str, Any]:
        """
        Create RPA workflows from PRD content
        
        Args:
            prd_content: Product Requirements Document content
            project_config: Project configuration
            span: Tracing span for observability
            
        Returns:
            Dictionary containing generated workflows and execution plan
        """
        try:
            # Execute PRD analysis workflow
            prd_config = RpaWorkflowConfig(
                workflow_type="prd_analysis",
                parameters={
                    "prd_content": prd_content,
                    "project_config": project_config,
                    "analysis_depth": "comprehensive"
                }
            )
            
            result = await self.execute_component_workflow("ai_processing", prd_config, span)
            
            if not result.success:
                raise Exception(f"PRD analysis failed: {result.error}")
            
            # Generate workflow mappings based on analysis
            workflows = await self._generate_workflow_mappings(result.result, span)
            
            span.add_info_events(
                prd_length=len(prd_content),
                workflows_generated=len(workflows),
                analysis_success=True
            )
            
            return {
                "success": True,
                "workflows": workflows,
                "analysis_result": result.result,
                "execution_plan": self._create_execution_plan(workflows)
            }
            
        except Exception as e:
            error_msg = f"PRD workflow creation failed: {str(e)}"
            logger.error(error_msg)
            
            span.add_info_events(error=error_msg)
            
            return {
                "success": False,
                "error": error_msg,
                "workflows": {},
                "execution_plan": None
            }
    
    async def _generate_workflow_mappings(self, 
                                        analysis_result: Dict[str, Any],
                                        span: Span) -> Dict[str, Any]:
        """Generate workflow mappings from PRD analysis"""
        workflows = {}
        
        requirements = analysis_result.get("requirements", [])
        
        for req in requirements:
            req_id = req.get("id", f"req_{len(workflows)}")
            req_type = req.get("type", "general")
            
            # Map requirement type to component category
            if "ui" in req_type.lower() or "interface" in req_type.lower():
                category = "ui_testing"
            elif "api" in req_type.lower() or "service" in req_type.lower():
                category = "api_testing"
            elif "data" in req_type.lower() or "database" in req_type.lower():
                category = "data_processing"
            elif "ai" in req_type.lower() or "intelligent" in req_type.lower():
                category = "ai_processing"
            else:
                category = "system_automation"
            
            workflows[req_id] = {
                "requirement": req,
                "component_category": category,
                "components": self.component_mapping[category],
                "workflow_config": {
                    "workflow_type": f"{req_type}_validation",
                    "parameters": req.get("parameters", {}),
                    "validation_rules": req.get("validation", [])
                }
            }
        
        return workflows
    
    def _create_execution_plan(self, workflows: Dict[str, Any]) -> Dict[str, Any]:
        """Create execution plan for workflows"""
        return {
            "total_workflows": len(workflows),
            "execution_order": list(workflows.keys()),
            "parallel_groups": self._group_parallel_workflows(workflows),
            "estimated_duration": self._estimate_execution_duration(workflows)
        }
    
    def _group_parallel_workflows(self, workflows: Dict[str, Any]) -> List[List[str]]:
        """Group workflows that can be executed in parallel"""
        # Simple grouping by component category
        category_groups = {}
        
        for workflow_id, workflow in workflows.items():
            category = workflow["component_category"]
            if category not in category_groups:
                category_groups[category] = []
            category_groups[category].append(workflow_id)
        
        return list(category_groups.values())
    
    def _estimate_execution_duration(self, workflows: Dict[str, Any]) -> int:
        """Estimate total execution duration in seconds"""
        # Base estimation: 60 seconds per workflow, with parallelization benefits
        base_duration = len(workflows) * 60
        parallel_groups = self._group_parallel_workflows(workflows)
        
        # Reduce duration based on parallel execution
        if len(parallel_groups) > 1:
            parallel_factor = 0.7  # 30% reduction for parallel execution
            base_duration = int(base_duration * parallel_factor)
        
        return max(base_duration, 120)  # Minimum 2 minutes
