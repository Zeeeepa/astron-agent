"""
RPA Integration API Endpoints

Provides REST API endpoints for the Astron-RPA integration,
enabling project creation, PRD processing, and workflow execution.
"""

import asyncio
import time
from typing import Any, Dict, List, Optional

from fastapi import APIRouter, HTTPException, BackgroundTasks, Depends
from pydantic import BaseModel, Field

from api.schemas.completion_chunk import ReasonChatCompletionChunk
from common_imports import logger, sid_generator2, Span
from service.plugin.astron_rpa_plugin import AstronRpaPlugin, RpaWorkflowConfig
from service.mapping.component_mapper import ComponentMappingService


# Request/Response Models
class CreateProjectRequest(BaseModel):
    """Request model for creating a new project"""
    
    name: str = Field(..., description="Project name")
    prd_content: str = Field(..., description="PRD document content")
    project_config: Optional[Dict[str, Any]] = Field(default_factory=dict, description="Project configuration")
    rpa_service_url: Optional[str] = Field(default="http://astron-rpa:8020", description="RPA service URL")
    api_key: Optional[str] = Field(default=None, description="API key for RPA service")


class ProjectResponse(BaseModel):
    """Response model for project operations"""
    
    project_id: str
    status: str
    message: str
    data: Optional[Dict[str, Any]] = None


class ExecuteWorkflowRequest(BaseModel):
    """Request model for workflow execution"""
    
    project_id: str = Field(..., description="Project ID")
    workflow_type: str = Field(..., description="Type of workflow to execute")
    component_category: str = Field(..., description="RPA component category")
    parameters: Dict[str, Any] = Field(default_factory=dict, description="Workflow parameters")
    timeout: Optional[int] = Field(default=300, description="Execution timeout in seconds")


class WorkflowExecutionResponse(BaseModel):
    """Response model for workflow execution"""
    
    execution_id: str
    project_id: str
    status: str
    result: Optional[Dict[str, Any]] = None
    error: Optional[str] = None
    execution_time: Optional[int] = None


class ValidationRequest(BaseModel):
    """Request model for validation execution"""
    
    project_id: str = Field(..., description="Project ID")
    task_result: Dict[str, Any] = Field(..., description="Task execution results")
    expected_behavior: Dict[str, Any] = Field(..., description="Expected behavior specification")


class ValidationResponse(BaseModel):
    """Response model for validation results"""
    
    validation_id: str
    project_id: str
    overall_valid: bool
    validation_results: Dict[str, Any]
    timestamp: int


# Router setup
rpa_integration_router = APIRouter(prefix="/api/v1/rpa", tags=["RPA Integration"])

# Global services (would typically be dependency injected)
component_mapping_service = ComponentMappingService()
active_projects: Dict[str, Dict[str, Any]] = {}
active_executions: Dict[str, Dict[str, Any]] = {}


@rpa_integration_router.post("/projects/create", response_model=ProjectResponse)
async def create_project(
    request: CreateProjectRequest,
    background_tasks: BackgroundTasks
) -> ProjectResponse:
    """
    Create a new project with PRD processing and workflow generation
    
    This endpoint:
    1. Creates a new project
    2. Processes the PRD content
    3. Generates RPA workflow mappings
    4. Returns project configuration
    """
    try:
        project_id = sid_generator2.gen()
        
        # Initialize project
        project_data = {
            "id": project_id,
            "name": request.name,
            "prd_content": request.prd_content,
            "project_config": request.project_config,
            "rpa_service_url": request.rpa_service_url,
            "api_key": request.api_key,
            "status": "initializing",
            "created_at": int(time.time()),
            "workflow_mappings": None,
            "execution_plan": None
        }
        
        active_projects[project_id] = project_data
        
        # Process PRD in background
        background_tasks.add_task(
            process_prd_background,
            project_id,
            request.prd_content,
            request.project_config
        )
        
        return ProjectResponse(
            project_id=project_id,
            status="initializing",
            message="Project created successfully. PRD processing started.",
            data={
                "project_name": request.name,
                "prd_length": len(request.prd_content),
                "estimated_processing_time": "2-5 minutes"
            }
        )
        
    except Exception as e:
        logger.error(f"Failed to create project: {str(e)}")
        raise HTTPException(
            status_code=500,
            detail=f"Failed to create project: {str(e)}"
        )


@rpa_integration_router.get("/projects/{project_id}", response_model=ProjectResponse)
async def get_project_status(project_id: str) -> ProjectResponse:
    """Get project status and details"""
    
    if project_id not in active_projects:
        raise HTTPException(
            status_code=404,
            detail=f"Project {project_id} not found"
        )
    
    project_data = active_projects[project_id]
    
    return ProjectResponse(
        project_id=project_id,
        status=project_data["status"],
        message=f"Project {project_data['name']} status: {project_data['status']}",
        data={
            "name": project_data["name"],
            "created_at": project_data["created_at"],
            "prd_length": len(project_data["prd_content"]),
            "workflow_mappings_count": len(project_data.get("workflow_mappings", {})),
            "execution_plan": project_data.get("execution_plan")
        }
    )


@rpa_integration_router.post("/workflows/execute", response_model=WorkflowExecutionResponse)
async def execute_workflow(
    request: ExecuteWorkflowRequest,
    background_tasks: BackgroundTasks
) -> WorkflowExecutionResponse:
    """
    Execute an RPA workflow for a project
    
    This endpoint:
    1. Validates the project exists
    2. Creates RPA plugin instance
    3. Executes the specified workflow
    4. Returns execution results
    """
    try:
        # Validate project exists
        if request.project_id not in active_projects:
            raise HTTPException(
                status_code=404,
                detail=f"Project {request.project_id} not found"
            )
        
        project_data = active_projects[request.project_id]
        execution_id = sid_generator2.gen()
        
        # Initialize execution tracking
        execution_data = {
            "id": execution_id,
            "project_id": request.project_id,
            "workflow_type": request.workflow_type,
            "component_category": request.component_category,
            "status": "running",
            "started_at": int(time.time()),
            "result": None,
            "error": None
        }
        
        active_executions[execution_id] = execution_data
        
        # Execute workflow in background
        background_tasks.add_task(
            execute_workflow_background,
            execution_id,
            project_data,
            request
        )
        
        return WorkflowExecutionResponse(
            execution_id=execution_id,
            project_id=request.project_id,
            status="running",
            result=None,
            error=None,
            execution_time=None
        )
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Failed to execute workflow: {str(e)}")
        raise HTTPException(
            status_code=500,
            detail=f"Failed to execute workflow: {str(e)}"
        )


@rpa_integration_router.get("/workflows/execution/{execution_id}", response_model=WorkflowExecutionResponse)
async def get_execution_status(execution_id: str) -> WorkflowExecutionResponse:
    """Get workflow execution status and results"""
    
    if execution_id not in active_executions:
        raise HTTPException(
            status_code=404,
            detail=f"Execution {execution_id} not found"
        )
    
    execution_data = active_executions[execution_id]
    
    execution_time = None
    if execution_data["status"] in ["completed", "failed"]:
        execution_time = execution_data.get("completed_at", 0) - execution_data["started_at"]
    
    return WorkflowExecutionResponse(
        execution_id=execution_id,
        project_id=execution_data["project_id"],
        status=execution_data["status"],
        result=execution_data.get("result"),
        error=execution_data.get("error"),
        execution_time=execution_time
    )


@rpa_integration_router.post("/validation/execute", response_model=ValidationResponse)
async def execute_validation(
    request: ValidationRequest,
    background_tasks: BackgroundTasks
) -> ValidationResponse:
    """
    Execute autonomous validation using RPA components
    
    This endpoint:
    1. Validates the project exists
    2. Creates RPA plugin instance
    3. Executes comprehensive validation
    4. Returns validation results
    """
    try:
        # Validate project exists
        if request.project_id not in active_projects:
            raise HTTPException(
                status_code=404,
                detail=f"Project {request.project_id} not found"
            )
        
        project_data = active_projects[request.project_id]
        validation_id = sid_generator2.gen()
        
        # Create RPA plugin
        rpa_plugin = AstronRpaPlugin(
            rpa_openapi_url=project_data.get("rpa_service_url", "http://astron-rpa:8020"),
            api_key=project_data.get("api_key")
        )
        
        # Create span for tracing
        span = create_default_span(f"validation_{validation_id}")
        
        # Execute validation
        validation_result = await rpa_plugin.execute_autonomous_validation(
            task_result=request.task_result,
            expected_behavior=request.expected_behavior,
            span=span
        )
        
        return ValidationResponse(
            validation_id=validation_id,
            project_id=request.project_id,
            overall_valid=validation_result["overall_valid"],
            validation_results=validation_result["validation_results"],
            timestamp=validation_result["timestamp"]
        )
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Failed to execute validation: {str(e)}")
        raise HTTPException(
            status_code=500,
            detail=f"Failed to execute validation: {str(e)}"
        )


@rpa_integration_router.get("/projects/{project_id}/workflows", response_model=Dict[str, Any])
async def get_project_workflows(project_id: str) -> Dict[str, Any]:
    """Get generated workflows for a project"""
    
    if project_id not in active_projects:
        raise HTTPException(
            status_code=404,
            detail=f"Project {project_id} not found"
        )
    
    project_data = active_projects[project_id]
    
    if not project_data.get("workflow_mappings"):
        raise HTTPException(
            status_code=404,
            detail=f"Workflows not yet generated for project {project_id}"
        )
    
    return {
        "project_id": project_id,
        "workflow_mappings": project_data["workflow_mappings"],
        "execution_plan": project_data.get("execution_plan"),
        "validation_strategy": project_data.get("validation_strategy")
    }


# Background task functions
async def process_prd_background(
    project_id: str,
    prd_content: str,
    project_config: Dict[str, Any]
):
    """Background task for PRD processing"""
    try:
        project_data = active_projects[project_id]
        project_data["status"] = "processing_prd"
        
        # Create span for tracing
        span = create_default_span(f"prd_processing_{project_id}")
        
        # Generate workflow mappings
        workflow_mappings = await component_mapping_service.create_project_workflow_mappings(
            prd_content=prd_content,
            project_config=project_config,
            span=span
        )
        
        # Update project data
        project_data.update({
            "status": "ready",
            "workflow_mappings": workflow_mappings["workflow_mappings"],
            "execution_plan": workflow_mappings["execution_plan"],
            "validation_strategy": workflow_mappings["validation_strategy"],
            "requirements": workflow_mappings["requirements"],
            "processed_at": int(time.time())
        })
        
        logger.info(f"PRD processing completed for project {project_id}")
        
    except Exception as e:
        logger.error(f"PRD processing failed for project {project_id}: {str(e)}")
        project_data = active_projects[project_id]
        project_data.update({
            "status": "failed",
            "error": str(e),
            "failed_at": int(time.time())
        })


async def execute_workflow_background(
    execution_id: str,
    project_data: Dict[str, Any],
    request: ExecuteWorkflowRequest
):
    """Background task for workflow execution"""
    try:
        execution_data = active_executions[execution_id]
        
        # Create RPA plugin
        rpa_plugin = AstronRpaPlugin(
            rpa_openapi_url=project_data.get("rpa_service_url", "http://astron-rpa:8020"),
            api_key=project_data.get("api_key")
        )
        
        # Create workflow configuration
        workflow_config = RpaWorkflowConfig(
            workflow_type=request.workflow_type,
            components=[],  # Will be set by plugin
            parameters=request.parameters,
            timeout=request.timeout
        )
        
        # Create span for tracing
        span = create_default_span(f"workflow_execution_{execution_id}")
        
        # Execute workflow
        result = await rpa_plugin.execute_component_workflow(
            component_category=request.component_category,
            workflow_config=workflow_config,
            span=span
        )
        
        # Update execution data
        execution_data.update({
            "status": "completed",
            "result": result.result,
            "completed_at": int(time.time())
        })
        
        logger.info(f"Workflow execution completed for {execution_id}")
        
    except Exception as e:
        logger.error(f"Workflow execution failed for {execution_id}: {str(e)}")
        execution_data = active_executions[execution_id]
        execution_data.update({
            "status": "failed",
            "error": str(e),
            "completed_at": int(time.time())
        })


def create_default_span(name: str) -> Span:
    """Create a default span for tracing"""
    # This would typically create a proper tracing span
    # For now, return a simple mock span
    class DefaultSpan:
        def __init__(self, name: str):
            self.name = name
            self.sid = sid_generator2.gen()
        
        def __enter__(self):
            return self
        
        def __exit__(self, *args):
            pass
        
        def start(self, name: str):
            return DefaultSpan(name)
        
        def add_info_events(self, **kwargs):
            pass
    
    return DefaultSpan(name)


# Health check endpoint
@rpa_integration_router.get("/health")
async def health_check():
    """Health check endpoint for RPA integration"""
    return {
        "status": "healthy",
        "service": "rpa_integration",
        "timestamp": int(time.time()),
        "active_projects": len(active_projects),
        "active_executions": len(active_executions)
    }
