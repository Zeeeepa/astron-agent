"""
Astron-RPA Integration Plugin for Astron-Agent

This plugin provides MCP-based integration with Astron-RPA services,
enabling autonomous CI/CD workflows with comprehensive RPA capabilities.
"""

import asyncio
import json
import time
from typing import Any, Dict, List, Optional, cast

import aiohttp
from pydantic import BaseModel, Field

from common_imports import Span
from exceptions.plugin_exc import GetMcpPluginExc, RunMcpPluginExc
from infra import agent_config
from service.plugin.base import BasePlugin, PluginResponse
from service.plugin.mcp import McpPlugin


class RpaComponentMapping(BaseModel):
    """RPA Component mapping configuration"""
    
    UI_AUTOMATION = {
        "components": ["rpabrowser", "rpacv", "rpawindow"],
        "use_cases": ["web_testing", "ui_validation", "screenshot_capture", "browser_automation"]
    }
    
    API_TESTING = {
        "components": ["rpanetwork", "rpaopenapi"],
        "use_cases": ["api_validation", "endpoint_testing", "integration_testing", "http_requests"]
    }
    
    DATA_PROCESSING = {
        "components": ["rpadatabase", "rpaexcel", "rpapdf", "rpadocx"],
        "use_cases": ["data_validation", "report_generation", "document_processing", "database_operations"]
    }
    
    AI_PROCESSING = {
        "components": ["rpaai", "rpaverifycode"],
        "use_cases": ["intelligent_validation", "code_verification", "ai_analysis", "pattern_recognition"]
    }
    
    SYSTEM_AUTOMATION = {
        "components": ["rpasystem", "rpaencrypt", "rpaemail", "rpaenterprise"],
        "use_cases": ["system_monitoring", "security_operations", "notifications", "enterprise_integration"]
    }


class RpaWorkflowConfig(BaseModel):
    """Configuration for RPA workflow execution"""
    
    workflow_type: str
    components: List[str]
    parameters: Dict[str, Any]
    timeout: Optional[int] = 300
    retry_count: Optional[int] = 3
    validation_rules: Optional[Dict[str, Any]] = None


class AstronRpaPlugin(McpPlugin):
    """
    Enhanced MCP Plugin for Astron-RPA integration
    
    Provides seamless integration between Astron-Agent's orchestration
    capabilities and Astron-RPA's comprehensive automation components.
    """
    
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
        self.api_key = api_key or agent_config.RPA_API_KEY
        self.component_mapping = RpaComponentMapping()
        
        # Initialize MCP plugin with proper configuration
        super().__init__(
            name="astron_rpa",
            description="Execute RPA workflows for CI/CD automation",
            server_url=f"{rpa_openapi_url}/mcp",
            timeout=40.0  # Based on existing MCP timeout pattern
        )
    
    async def execute_component_workflow(self, 
                                       component_category: str, 
                                       workflow_config: RpaWorkflowConfig,
                                       span: Span) -> PluginResponse:
        """
        Execute workflow using specific RPA component category
        
        Args:
            component_category: Category of RPA components to use
            workflow_config: Configuration for workflow execution
            span: Tracing span for observability
            
        Returns:
            PluginResponse with execution results
        """
        with span.start("ExecuteComponentWorkflow") as sp:
            start_time = int(round(time.time() * 1000))
            
            # Get components for category
            category_config = getattr(self.component_mapping, component_category.upper(), None)
            if not category_config:
                raise RunMcpPluginExc(f"Unknown component category: {component_category}")
            
            components = category_config["components"]
            
            # Prepare execution data
            execution_data = {
                "workflow_type": workflow_config.workflow_type,
                "components": components,
                "parameters": workflow_config.parameters,
                "timeout": workflow_config.timeout,
                "validation_rules": workflow_config.validation_rules,
                "sid": sp.sid
            }
            
            sp.add_info_events(
                attributes={
                    "rpa-workflow-inputs": json.dumps(execution_data, ensure_ascii=False)
                }
            )
            
            try:
                # Execute workflow via RPA OpenAPI service
                result = await self._execute_rpa_workflow(execution_data)
                
                sp.add_info_events(
                    attributes={
                        "rpa-workflow-outputs": json.dumps(result, ensure_ascii=False)
                    }
                )
                
                end_time = int(round(time.time() * 1000))
                
                return PluginResponse(
                    code=result.get("code", "success"),
                    sid=result.get("sid", sp.sid),
                    start_time=start_time,
                    end_time=end_time,
                    result=result,
                    log=[{
                        "name": f"rpa_{component_category}",
                        "input": execution_data,
                        "output": result
                    }]
                )
                
            except Exception as e:
                sp.add_info_events(
                    attributes={
                        "rpa-workflow-error": str(e)
                    }
                )
                raise RunMcpPluginExc(f"RPA workflow execution failed: {str(e)}") from e
    
    async def create_prd_validation_workflow(self, 
                                           prd_content: str, 
                                           project_config: Dict[str, Any],
                                           span: Span) -> Dict[str, Any]:
        """
        Create comprehensive validation workflow from PRD content
        
        Args:
            prd_content: PRD document content
            project_config: Project configuration
            span: Tracing span
            
        Returns:
            Dictionary containing generated workflows
        """
        with span.start("CreatePRDValidationWorkflow") as sp:
            workflows = {}
            
            # Analyze PRD to determine required validation types
            validation_types = await self._analyze_prd_requirements(prd_content, sp)
            
            for validation_type in validation_types:
                if validation_type == "ui_validation":
                    workflows["ui"] = await self._create_ui_validation_workflow(
                        prd_content, project_config, sp
                    )
                elif validation_type == "api_validation":
                    workflows["api"] = await self._create_api_validation_workflow(
                        prd_content, project_config, sp
                    )
                elif validation_type == "data_validation":
                    workflows["data"] = await self._create_data_validation_workflow(
                        prd_content, project_config, sp
                    )
                elif validation_type == "integration_validation":
                    workflows["integration"] = await self._create_integration_validation_workflow(
                        prd_content, project_config, sp
                    )
            
            return workflows
    
    async def execute_autonomous_validation(self, 
                                          task_result: Dict[str, Any],
                                          expected_behavior: Dict[str, Any],
                                          span: Span) -> Dict[str, Any]:
        """
        Execute autonomous validation using RPA components
        
        Args:
            task_result: Results from task execution
            expected_behavior: Expected behavior specification
            span: Tracing span
            
        Returns:
            Validation results
        """
        with span.start("AutonomousValidation") as sp:
            validation_results = {}
            
            # UI Validation using rpabrowser + rpacv
            if "ui_requirements" in expected_behavior:
                ui_config = RpaWorkflowConfig(
                    workflow_type="ui_validation",
                    components=["rpabrowser", "rpacv", "rpawindow"],
                    parameters={
                        "target_url": task_result.get("deployment_url"),
                        "expected_elements": expected_behavior["ui_requirements"],
                        "screenshot_path": "/validation/ui_screenshots/"
                    }
                )
                validation_results["ui"] = await self.execute_component_workflow(
                    "ui_automation", ui_config, sp
                )
            
            # API Validation using rpanetwork + rpaopenapi
            if "api_requirements" in expected_behavior:
                api_config = RpaWorkflowConfig(
                    workflow_type="api_validation",
                    components=["rpanetwork", "rpaopenapi"],
                    parameters={
                        "api_base_url": task_result.get("api_url"),
                        "endpoints": expected_behavior["api_requirements"],
                        "test_data": expected_behavior.get("test_data", {})
                    }
                )
                validation_results["api"] = await self.execute_component_workflow(
                    "api_testing", api_config, sp
                )
            
            # Data Validation using rpadatabase + rpaexcel
            if "data_requirements" in expected_behavior:
                data_config = RpaWorkflowConfig(
                    workflow_type="data_validation",
                    components=["rpadatabase", "rpaexcel"],
                    parameters={
                        "database_config": task_result.get("database_config"),
                        "expected_data": expected_behavior["data_requirements"],
                        "validation_queries": expected_behavior.get("validation_queries", [])
                    }
                )
                validation_results["data"] = await self.execute_component_workflow(
                    "data_processing", data_config, sp
                )
            
            # Overall validation result
            all_valid = all(
                result.result.get("success", False) 
                for result in validation_results.values()
            )
            
            return {
                "overall_valid": all_valid,
                "validation_results": validation_results,
                "timestamp": int(time.time()),
                "validation_id": sp.sid
            }
    
    async def _execute_rpa_workflow(self, execution_data: Dict[str, Any]) -> Dict[str, Any]:
        """Execute workflow via RPA OpenAPI service"""
        headers = {"Content-Type": "application/json"}
        if self.api_key:
            headers["Authorization"] = f"Bearer {self.api_key}"
        
        async with aiohttp.ClientSession() as session:
            timeout = aiohttp.ClientTimeout(total=execution_data.get("timeout", 300))
            async with session.post(
                f"{self.rpa_openapi_url}/api/v1/workflows/execute",
                json=execution_data,
                headers=headers,
                timeout=timeout,
            ) as response:
                response.raise_for_status()
                return await response.json()
    
    async def _analyze_prd_requirements(self, 
                                      prd_content: str, 
                                      span: Span) -> List[str]:
        """Analyze PRD content to determine required validation types"""
        # This would typically use AI to analyze the PRD
        # For now, return common validation types
        return ["ui_validation", "api_validation", "data_validation", "integration_validation"]
    
    async def _create_ui_validation_workflow(self, 
                                           prd_content: str,
                                           project_config: Dict[str, Any],
                                           span: Span) -> Dict[str, Any]:
        """Create UI validation workflow"""
        return {
            "workflow_type": "ui_validation",
            "components": ["rpabrowser", "rpacv", "rpawindow"],
            "steps": [
                {
                    "component": "rpabrowser",
                    "action": "navigate",
                    "params": {"url": project_config.get("target_url", "http://localhost:3000")}
                },
                {
                    "component": "rpacv",
                    "action": "validate_ui_elements",
                    "params": {"expected_elements": project_config.get("ui_elements", [])}
                },
                {
                    "component": "rpawindow",
                    "action": "capture_screenshot",
                    "params": {"save_path": "/validation/screenshots/"}
                }
            ]
        }
    
    async def _create_api_validation_workflow(self, 
                                            prd_content: str,
                                            project_config: Dict[str, Any],
                                            span: Span) -> Dict[str, Any]:
        """Create API validation workflow"""
        return {
            "workflow_type": "api_validation",
            "components": ["rpanetwork", "rpaopenapi"],
            "steps": [
                {
                    "component": "rpaopenapi",
                    "action": "load_spec",
                    "params": {"spec_url": project_config.get("openapi_spec_url")}
                },
                {
                    "component": "rpanetwork",
                    "action": "execute_test_suite",
                    "params": {"endpoints": project_config.get("api_endpoints", [])}
                }
            ]
        }
    
    async def _create_data_validation_workflow(self, 
                                             prd_content: str,
                                             project_config: Dict[str, Any],
                                             span: Span) -> Dict[str, Any]:
        """Create data validation workflow"""
        return {
            "workflow_type": "data_validation",
            "components": ["rpadatabase", "rpaexcel"],
            "steps": [
                {
                    "component": "rpadatabase",
                    "action": "validate_schema",
                    "params": {"database_config": project_config.get("database_config")}
                },
                {
                    "component": "rpaexcel",
                    "action": "generate_report",
                    "params": {"output_path": "/validation/reports/"}
                }
            ]
        }
    
    async def _create_integration_validation_workflow(self, 
                                                    prd_content: str,
                                                    project_config: Dict[str, Any],
                                                    span: Span) -> Dict[str, Any]:
        """Create integration validation workflow"""
        return {
            "workflow_type": "integration_validation",
            "components": ["rpaenterprise", "rpasystem"],
            "steps": [
                {
                    "component": "rpaenterprise",
                    "action": "test_integrations",
                    "params": {"integration_configs": project_config.get("integrations", [])}
                },
                {
                    "component": "rpasystem",
                    "action": "monitor_performance",
                    "params": {"monitoring_duration": 300}
                }
            ]
        }
