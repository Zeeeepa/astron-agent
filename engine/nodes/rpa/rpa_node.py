"""
RPA Workflow Node

Implements RPA-specific workflow node for executing RPA components
within the Astron-Agent workflow engine.
"""

import asyncio
import time
from typing import Any, Dict, List, Optional, AsyncIterator

from engine.nodes.base import BaseNode
from engine.entities.node_trace import NodeTrace
from engine.entities.agent_response import AgentResponse
from service.plugin.astron_rpa_plugin import AstronRpaPlugin, RpaWorkflowConfig
from service.mapping.component_mapper import ComponentMappingService
from common_imports import logger, Span


class RpaNode(BaseNode):
    """RPA workflow node for executing RPA components"""
    
    def __init__(self, 
                 node_id: str,
                 rpa_openapi_url: str = "http://astron-rpa:8020",
                 api_key: Optional[str] = None):
        """
        Initialize RPA node
        
        Args:
            node_id: Unique identifier for this node
            rpa_openapi_url: URL for Astron-RPA OpenAPI service
            api_key: Optional API key for authentication
        """
        super().__init__(node_id)
        
        self.rpa_plugin = AstronRpaPlugin(
            rpa_openapi_url=rpa_openapi_url,
            api_key=api_key
        )
        
        self.component_mapper = ComponentMappingService()
        
        # Node configuration
        self.node_type = "rpa"
        self.supported_operations = [
            "execute_workflow",
            "validate_implementation", 
            "process_prd",
            "create_workflows",
            "execute_validation"
        ]
    
    async def run(self, span: Span, node_trace: NodeTrace) -> AsyncIterator[AgentResponse]:
        """
        Execute RPA node operations
        
        Args:
            span: Tracing span for observability
            node_trace: Node execution trace
            
        Yields:
            AgentResponse objects with execution results
        """
        try:
            # Get operation from node configuration
            operation = node_trace.node_config.get("operation", "execute_workflow")
            
            if operation not in self.supported_operations:
                raise ValueError(f"Unsupported operation: {operation}")
            
            # Add node information to span
            span.add_info_events(
                node_id=self.node_id,
                node_type=self.node_type,
                operation=operation
            )
            
            # Execute the requested operation
            if operation == "execute_workflow":
                async for response in self._execute_workflow(span, node_trace):
                    yield response
                    
            elif operation == "validate_implementation":
                async for response in self._validate_implementation(span, node_trace):
                    yield response
                    
            elif operation == "process_prd":
                async for response in self._process_prd(span, node_trace):
                    yield response
                    
            elif operation == "create_workflows":
                async for response in self._create_workflows(span, node_trace):
                    yield response
                    
            elif operation == "execute_validation":
                async for response in self._execute_validation(span, node_trace):
                    yield response
            
        except Exception as e:
            error_msg = f"RPA node execution failed: {str(e)}"
            logger.error(error_msg, extra={
                "node_id": self.node_id,
                "operation": node_trace.node_config.get("operation", "unknown")
            })
            
            span.add_info_events(error=error_msg)
            
            yield AgentResponse(
                content=f"❌ **RPA Node Error**\n\n{error_msg}",
                response_type="error",
                metadata={
                    "node_id": self.node_id,
                    "error": error_msg,
                    "timestamp": int(time.time())
                }
            )
    
    async def _execute_workflow(self, span: Span, node_trace: NodeTrace) -> AsyncIterator[AgentResponse]:
        """Execute RPA workflow"""
        
        config = node_trace.node_config
        component_category = config.get("component_category", "system_automation")
        workflow_type = config.get("workflow_type", "general")
        parameters = config.get("parameters", {})
        timeout = config.get("timeout", 300)
        
        yield AgentResponse(
            content=f"🤖 **Executing RPA Workflow**\n\n"
                   f"• **Category**: {component_category}\n"
                   f"• **Type**: {workflow_type}\n"
                   f"• **Timeout**: {timeout}s",
            response_type="info"
        )
        
        # Create workflow configuration
        workflow_config = RpaWorkflowConfig(
            workflow_type=workflow_type,
            parameters=parameters,
            timeout=timeout
        )
        
        # Execute workflow
        result = await self.rpa_plugin.execute_component_workflow(
            component_category=component_category,
            workflow_config=workflow_config,
            span=span
        )
        
        if result.success:
            yield AgentResponse(
                content=f"✅ **Workflow Completed Successfully**\n\n"
                       f"• **Execution Time**: {result.execution_time}s\n"
                       f"• **Components Used**: {', '.join(result.components_used)}\n"
                       f"• **Result**: {result.result}",
                response_type="success",
                metadata={
                    "execution_result": result.dict(),
                    "workflow_type": workflow_type,
                    "component_category": component_category
                }
            )
        else:
            yield AgentResponse(
                content=f"❌ **Workflow Failed**\n\n"
                       f"• **Error**: {result.error}\n"
                       f"• **Execution Time**: {result.execution_time}s\n"
                       f"• **Components Attempted**: {', '.join(result.components_used)}",
                response_type="error",
                metadata={
                    "execution_result": result.dict(),
                    "workflow_type": workflow_type,
                    "component_category": component_category
                }
            )
    
    async def _validate_implementation(self, span: Span, node_trace: NodeTrace) -> AsyncIterator[AgentResponse]:
        """Execute autonomous validation"""
        
        config = node_trace.node_config
        task_result = config.get("task_result", {})
        expected_behavior = config.get("expected_behavior", {})
        
        yield AgentResponse(
            content=f"🔍 **Starting Autonomous Validation**\n\n"
                   f"• **UI Validation**: Checking user interface behavior\n"
                   f"• **API Validation**: Validating service endpoints\n"
                   f"• **Integration Validation**: Testing system integration",
            response_type="info"
        )
        
        # Execute validation
        validation_result = await self.rpa_plugin.execute_autonomous_validation(
            task_result=task_result,
            expected_behavior=expected_behavior,
            span=span
        )
        
        # Create detailed validation report
        validation_status = "✅ PASSED" if validation_result.overall_valid else "❌ FAILED"
        ui_status = "✅" if validation_result.ui_valid else "❌"
        api_status = "✅" if validation_result.api_valid else "❌"
        integration_status = "✅" if validation_result.integration_valid else "❌"
        
        yield AgentResponse(
            content=f"📊 **Validation Results** {validation_status}\n\n"
                   f"• **UI Validation**: {ui_status}\n"
                   f"• **API Validation**: {api_status}\n"
                   f"• **Integration Validation**: {integration_status}\n\n"
                   f"**Overall Result**: {'All validations passed' if validation_result.overall_valid else 'Some validations failed'}",
            response_type="success" if validation_result.overall_valid else "warning",
            metadata={
                "validation_result": validation_result.dict(),
                "validation_timestamp": validation_result.timestamp
            }
        )
    
    async def _process_prd(self, span: Span, node_trace: NodeTrace) -> AsyncIterator[AgentResponse]:
        """Process PRD and create workflow mappings"""
        
        config = node_trace.node_config
        prd_content = config.get("prd_content", "")
        project_config = config.get("project_config", {})
        
        if not prd_content:
            yield AgentResponse(
                content="❌ **Error**: No PRD content provided",
                response_type="error"
            )
            return
        
        yield AgentResponse(
            content=f"📋 **Processing PRD Document**\n\n"
                   f"• **Content Length**: {len(prd_content)} characters\n"
                   f"• **Analyzing requirements...**",
            response_type="info"
        )
        
        # Create workflow mappings
        mapping_result = await self.component_mapper.create_project_workflow_mappings(
            prd_content=prd_content,
            project_config=project_config,
            span=span
        )
        
        if "error" not in mapping_result:
            requirements_count = len(mapping_result.get("requirements", []))
            workflows_count = len(mapping_result.get("workflow_mappings", {}))
            estimated_duration = mapping_result.get("estimated_total_duration", 0)
            
            yield AgentResponse(
                content=f"✅ **PRD Processing Complete**\n\n"
                       f"• **Requirements Identified**: {requirements_count}\n"
                       f"• **Workflows Generated**: {workflows_count}\n"
                       f"• **Estimated Duration**: {estimated_duration // 60}m {estimated_duration % 60}s\n\n"
                       f"**Ready for workflow execution!**",
                response_type="success",
                metadata={
                    "mapping_result": mapping_result,
                    "project_id": mapping_result.get("project_id")
                }
            )
        else:
            yield AgentResponse(
                content=f"❌ **PRD Processing Failed**\n\n"
                       f"• **Error**: {mapping_result.get('error', 'Unknown error')}",
                response_type="error",
                metadata={"error": mapping_result.get("error")}
            )
    
    async def _create_workflows(self, span: Span, node_trace: NodeTrace) -> AsyncIterator[AgentResponse]:
        """Create RPA workflows from PRD content"""
        
        config = node_trace.node_config
        prd_content = config.get("prd_content", "")
        project_config = config.get("project_config", {})
        
        yield AgentResponse(
            content=f"🔧 **Creating RPA Workflows**\n\n"
                   f"• **Analyzing PRD content...**\n"
                   f"• **Generating workflow mappings...**",
            response_type="info"
        )
        
        # Create workflows using RPA plugin
        workflow_result = await self.rpa_plugin.create_prd_workflows(
            prd_content=prd_content,
            project_config=project_config,
            span=span
        )
        
        if workflow_result.get("success", False):
            workflows = workflow_result.get("workflows", {})
            execution_plan = workflow_result.get("execution_plan", {})
            
            yield AgentResponse(
                content=f"✅ **Workflows Created Successfully**\n\n"
                       f"• **Total Workflows**: {len(workflows)}\n"
                       f"• **Execution Plan**: {execution_plan.get('total_workflows', 0)} workflows\n"
                       f"• **Estimated Duration**: {execution_plan.get('estimated_duration', 0)}s",
                response_type="success",
                metadata={
                    "workflows": workflows,
                    "execution_plan": execution_plan,
                    "analysis_result": workflow_result.get("analysis_result")
                }
            )
        else:
            yield AgentResponse(
                content=f"❌ **Workflow Creation Failed**\n\n"
                       f"• **Error**: {workflow_result.get('error', 'Unknown error')}",
                response_type="error",
                metadata={"error": workflow_result.get("error")}
            )
    
    async def _execute_validation(self, span: Span, node_trace: NodeTrace) -> AsyncIterator[AgentResponse]:
        """Execute comprehensive validation workflow"""
        
        config = node_trace.node_config
        validation_config = config.get("validation_config", {})
        
        yield AgentResponse(
            content=f"🔍 **Starting Comprehensive Validation**\n\n"
                   f"• **Validation Strategy**: {validation_config.get('strategy', 'standard')}\n"
                   f"• **Components**: Multiple RPA components\n"
                   f"• **Expected Duration**: {validation_config.get('timeout', 300)}s",
            response_type="info"
        )
        
        # Execute multiple validation workflows in parallel
        validation_tasks = []
        
        # UI Validation
        if validation_config.get("include_ui", True):
            ui_config = RpaWorkflowConfig(
                workflow_type="ui_validation",
                parameters=validation_config.get("ui_parameters", {}),
                timeout=validation_config.get("timeout", 300)
            )
            validation_tasks.append(
                self.rpa_plugin.execute_component_workflow("ui_testing", ui_config, span)
            )
        
        # API Validation
        if validation_config.get("include_api", True):
            api_config = RpaWorkflowConfig(
                workflow_type="api_validation",
                parameters=validation_config.get("api_parameters", {}),
                timeout=validation_config.get("timeout", 300)
            )
            validation_tasks.append(
                self.rpa_plugin.execute_component_workflow("api_testing", api_config, span)
            )
        
        # Execute validations
        if validation_tasks:
            results = await asyncio.gather(*validation_tasks, return_exceptions=True)
            
            successful_validations = 0
            total_validations = len(results)
            
            for i, result in enumerate(results):
                if isinstance(result, Exception):
                    logger.error(f"Validation {i} failed: {str(result)}")
                elif hasattr(result, 'success') and result.success:
                    successful_validations += 1
            
            success_rate = successful_validations / total_validations if total_validations > 0 else 0
            overall_success = success_rate >= 0.8  # 80% success threshold
            
            status = "✅ PASSED" if overall_success else "❌ FAILED"
            
            yield AgentResponse(
                content=f"📊 **Validation Complete** {status}\n\n"
                       f"• **Success Rate**: {success_rate:.1%} ({successful_validations}/{total_validations})\n"
                       f"• **Overall Result**: {'Validation passed' if overall_success else 'Validation failed'}\n"
                       f"• **Recommendation**: {'Ready for deployment' if overall_success else 'Review and fix issues'}",
                response_type="success" if overall_success else "warning",
                metadata={
                    "validation_results": [r.dict() if hasattr(r, 'dict') else str(r) for r in results],
                    "success_rate": success_rate,
                    "overall_success": overall_success
                }
            )
        else:
            yield AgentResponse(
                content="⚠️ **No validations configured**\n\nPlease specify validation parameters.",
                response_type="warning"
            )
