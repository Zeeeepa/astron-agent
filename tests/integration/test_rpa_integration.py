#!/usr/bin/env python3
"""
Integration Tests for Astron-RPA Integration

Comprehensive test suite for validating the complete RPA integration
including MCP communication, workflow execution, and API endpoints.
"""

import asyncio
import json
import pytest
import time
from typing import Dict, Any
from unittest.mock import AsyncMock, MagicMock, patch

import aiohttp
from fastapi.testclient import TestClient

# Import the components we're testing
from service.plugin.astron_rpa_plugin import AstronRpaPlugin, RpaWorkflowConfig, RpaExecutionResult
from service.mapping.component_mapper import ComponentMappingService, RequirementAnalysis
from engine.nodes.rpa.rpa_node import RpaNode
from api.v1.rpa_integration import rpa_integration_router


class TestAstronRpaPlugin:
    """Test suite for AstronRpaPlugin"""
    
    @pytest.fixture
    def rpa_plugin(self):
        """Create RPA plugin instance for testing"""
        return AstronRpaPlugin(
            rpa_openapi_url="http://test-rpa:8020",
            api_key="test-api-key"
        )
    
    @pytest.fixture
    def mock_span(self):
        """Create mock span for testing"""
        span = MagicMock()
        span.add_info_events = MagicMock()
        return span
    
    def test_plugin_initialization(self, rpa_plugin):
        """Test RPA plugin initialization"""
        assert rpa_plugin.rpa_openapi_url == "http://test-rpa:8020"
        assert rpa_plugin.api_key == "test-api-key"
        assert "ui_testing" in rpa_plugin.component_mapping
        assert "api_testing" in rpa_plugin.component_mapping
        assert len(rpa_plugin.component_mapping) == 5
    
    def test_component_mapping_structure(self, rpa_plugin):
        """Test component mapping structure"""
        ui_components = rpa_plugin.component_mapping["ui_testing"]
        assert "rpabrowser" in ui_components
        assert "rpacv" in ui_components
        assert "rpawindow" in ui_components
        
        api_components = rpa_plugin.component_mapping["api_testing"]
        assert "rpanetwork" in api_components
        assert "rpaopenapi" in api_components
    
    @pytest.mark.asyncio
    async def test_execute_component_workflow_success(self, rpa_plugin, mock_span):
        """Test successful workflow execution"""
        
        # Mock the MCP run method
        with patch.object(rpa_plugin, 'run', new_callable=AsyncMock) as mock_run:
            mock_run.return_value = {"status": "success", "result": "test_result"}
            
            workflow_config = RpaWorkflowConfig(
                workflow_type="ui_validation",
                parameters={"test": "param"}
            )
            
            result = await rpa_plugin.execute_component_workflow(
                component_category="ui_testing",
                workflow_config=workflow_config,
                span=mock_span
            )
            
            assert result.success is True
            assert result.result == {"status": "success", "result": "test_result"}
            assert result.components_used == ["rpabrowser", "rpacv", "rpawindow"]
            
            # Verify MCP call
            mock_run.assert_called_once()
            call_args = mock_run.call_args[0][0]
            assert call_args["action"] == "execute_workflow"
            assert call_args["workflow_type"] == "ui_validation"
            assert call_args["components"] == ["rpabrowser", "rpacv", "rpawindow"]
    
    @pytest.mark.asyncio
    async def test_execute_component_workflow_failure(self, rpa_plugin, mock_span):
        """Test workflow execution failure handling"""
        
        with patch.object(rpa_plugin, 'run', new_callable=AsyncMock) as mock_run:
            mock_run.side_effect = Exception("Test error")
            
            workflow_config = RpaWorkflowConfig(
                workflow_type="ui_validation",
                parameters={"test": "param"}
            )
            
            result = await rpa_plugin.execute_component_workflow(
                component_category="ui_testing",
                workflow_config=workflow_config,
                span=mock_span
            )
            
            assert result.success is False
            assert "Test error" in result.error
            assert result.components_used == ["rpabrowser", "rpacv", "rpawindow"]
    
    @pytest.mark.asyncio
    async def test_autonomous_validation(self, rpa_plugin, mock_span):
        """Test autonomous validation execution"""
        
        with patch.object(rpa_plugin, '_validate_ui_behavior', new_callable=AsyncMock) as mock_ui, \
             patch.object(rpa_plugin, '_validate_api_behavior', new_callable=AsyncMock) as mock_api, \
             patch.object(rpa_plugin, '_validate_integration', new_callable=AsyncMock) as mock_integration:
            
            # Mock validation results
            mock_ui.return_value = {"success": True, "details": "UI validation passed"}
            mock_api.return_value = {"success": True, "details": "API validation passed"}
            mock_integration.return_value = {"success": True, "details": "Integration validation passed"}
            
            task_result = {"implementation_status": "completed"}
            expected_behavior = {
                "ui": {"target_url": "http://test.com"},
                "api": {"endpoints": ["/api/test"]},
                "integration": {"checks": ["database"]}
            }
            
            result = await rpa_plugin.execute_autonomous_validation(
                task_result=task_result,
                expected_behavior=expected_behavior,
                span=mock_span
            )
            
            assert result.overall_valid is True
            assert result.ui_valid is True
            assert result.api_valid is True
            assert result.integration_valid is True
    
    @pytest.mark.asyncio
    async def test_create_prd_workflows(self, rpa_plugin, mock_span):
        """Test PRD workflow creation"""
        
        with patch.object(rpa_plugin, 'execute_component_workflow', new_callable=AsyncMock) as mock_execute:
            mock_execute.return_value = RpaExecutionResult(
                success=True,
                result={
                    "requirements": [
                        {"id": "req_1", "type": "ui", "description": "User interface requirement"}
                    ]
                },
                execution_time=30,
                components_used=["rpaai"]
            )
            
            prd_content = "Create a web application with user authentication"
            project_config = {"environment": "test"}
            
            result = await rpa_plugin.create_prd_workflows(
                prd_content=prd_content,
                project_config=project_config,
                span=mock_span
            )
            
            assert result["success"] is True
            assert "workflows" in result
            assert "execution_plan" in result


class TestComponentMappingService:
    """Test suite for ComponentMappingService"""
    
    @pytest.fixture
    def mapping_service(self):
        """Create component mapping service for testing"""
        return ComponentMappingService()
    
    @pytest.fixture
    def mock_span(self):
        """Create mock span for testing"""
        span = MagicMock()
        span.add_info_events = MagicMock()
        return span
    
    def test_service_initialization(self, mapping_service):
        """Test service initialization"""
        assert len(mapping_service.component_capabilities) == 5
        assert "ui_testing" in mapping_service.component_capabilities
        assert "api_testing" in mapping_service.component_capabilities
        assert len(mapping_service.requirement_patterns) == 5
    
    def test_requirement_type_classification(self, mapping_service):
        """Test requirement type classification"""
        
        # Test UI classification
        ui_text = "user interface with buttons and forms"
        ui_type = mapping_service._classify_requirement_type(ui_text)
        assert ui_type == "ui"
        
        # Test API classification
        api_text = "rest api endpoints for user authentication"
        api_type = mapping_service._classify_requirement_type(api_text)
        assert api_type == "api"
        
        # Test data classification
        data_text = "database storage for user information"
        data_type = mapping_service._classify_requirement_type(data_text)
        assert data_type == "data"
    
    def test_complexity_calculation(self, mapping_service):
        """Test complexity calculation"""
        
        # Simple requirement
        simple_req = {
            "description": "Simple login form",
            "priority": "low"
        }
        simple_complexity = mapping_service._calculate_complexity(simple_req)
        assert 0.0 <= simple_complexity <= 1.0
        
        # Complex requirement
        complex_req = {
            "description": "Complex microservice architecture with database integration, api security, performance optimization, and monitoring systems",
            "priority": "high"
        }
        complex_complexity = mapping_service._calculate_complexity(complex_req)
        assert complex_complexity > simple_complexity
    
    def test_component_determination(self, mapping_service):
        """Test component determination for requirements"""
        
        # UI requirement
        ui_components = mapping_service._determine_components("ui", "user interface")
        assert "rpabrowser" in ui_components
        assert "rpacv" in ui_components
        
        # API requirement
        api_components = mapping_service._determine_components("api", "rest api")
        assert "rpanetwork" in api_components
        assert "rpaopenapi" in api_components
    
    def test_validation_strategy_determination(self, mapping_service):
        """Test validation strategy determination"""
        
        # Basic strategy
        basic_strategy = mapping_service._determine_validation_strategy("ui", 0.3)
        assert basic_strategy == "basic"
        
        # Standard strategy
        standard_strategy = mapping_service._determine_validation_strategy("api", 0.5)
        assert standard_strategy == "standard"
        
        # Comprehensive strategy
        comprehensive_strategy = mapping_service._determine_validation_strategy("system", 0.8)
        assert comprehensive_strategy == "comprehensive"
    
    @pytest.mark.asyncio
    async def test_create_project_workflow_mappings(self, mapping_service, mock_span):
        """Test complete project workflow mapping creation"""
        
        prd_content = """
        # E-Commerce Platform
        
        ## User Authentication
        Users must be able to register and login with email and password.
        
        ## Product Catalog
        Users should browse products with search and filtering capabilities.
        
        ## API Requirements
        RESTful API endpoints for all operations with proper status codes.
        """
        
        project_config = {"project_id": "test_project"}
        
        result = await mapping_service.create_project_workflow_mappings(
            prd_content=prd_content,
            project_config=project_config,
            span=mock_span
        )
        
        assert result["project_id"] == "test_project"
        assert len(result["requirements"]) > 0
        assert "workflow_mappings" in result
        assert "execution_plan" in result
        assert "validation_strategy" in result
        
        # Check that requirements were properly analyzed
        requirements = result["requirements"]
        assert any(req["type"] == "ui" for req in requirements)
        assert any(req["type"] == "api" for req in requirements)


class TestRpaNode:
    """Test suite for RpaNode"""
    
    @pytest.fixture
    def rpa_node(self):
        """Create RPA node for testing"""
        return RpaNode(
            node_id="test_rpa_node",
            rpa_openapi_url="http://test-rpa:8020"
        )
    
    @pytest.fixture
    def mock_span(self):
        """Create mock span for testing"""
        span = MagicMock()
        span.add_info_events = MagicMock()
        return span
    
    @pytest.fixture
    def mock_node_trace(self):
        """Create mock node trace for testing"""
        trace = MagicMock()
        trace.node_config = {
            "operation": "execute_workflow",
            "component_category": "ui_testing",
            "workflow_type": "ui_validation",
            "parameters": {"test": "param"},
            "timeout": 300
        }
        return trace
    
    def test_node_initialization(self, rpa_node):
        """Test RPA node initialization"""
        assert rpa_node.node_id == "test_rpa_node"
        assert rpa_node.node_type == "rpa"
        assert len(rpa_node.supported_operations) == 5
        assert "execute_workflow" in rpa_node.supported_operations
        assert "validate_implementation" in rpa_node.supported_operations
    
    @pytest.mark.asyncio
    async def test_execute_workflow_operation(self, rpa_node, mock_span, mock_node_trace):
        """Test workflow execution operation"""
        
        with patch.object(rpa_node.rpa_plugin, 'execute_component_workflow', new_callable=AsyncMock) as mock_execute:
            mock_execute.return_value = RpaExecutionResult(
                success=True,
                result={"status": "completed"},
                execution_time=60,
                components_used=["rpabrowser"]
            )
            
            responses = []
            async for response in rpa_node.run(mock_span, mock_node_trace):
                responses.append(response)
            
            assert len(responses) == 2  # Info + Success response
            assert any("Executing RPA Workflow" in resp.content for resp in responses)
            assert any("Workflow Completed Successfully" in resp.content for resp in responses)
    
    @pytest.mark.asyncio
    async def test_unsupported_operation(self, rpa_node, mock_span):
        """Test handling of unsupported operations"""
        
        mock_node_trace = MagicMock()
        mock_node_trace.node_config = {"operation": "unsupported_operation"}
        
        responses = []
        async for response in rpa_node.run(mock_span, mock_node_trace):
            responses.append(response)
        
        assert len(responses) == 1
        assert responses[0].response_type == "error"
        assert "Unsupported operation" in responses[0].content


class TestRpaIntegrationAPI:
    """Test suite for RPA Integration API"""
    
    @pytest.fixture
    def client(self):
        """Create test client for API testing"""
        from fastapi import FastAPI
        app = FastAPI()
        app.include_router(rpa_integration_router)
        return TestClient(app)
    
    def test_health_endpoint(self, client):
        """Test health check endpoint"""
        response = client.get("/api/v1/rpa/health")
        assert response.status_code == 200
        
        data = response.json()
        assert data["status"] == "healthy"
        assert data["service"] == "rpa_integration"
        assert "timestamp" in data
    
    def test_component_mapping_endpoint(self, client):
        """Test component mapping endpoint"""
        response = client.get("/api/v1/rpa/components/mapping")
        assert response.status_code == 200
        
        data = response.json()
        assert "component_categories" in data
        assert "ui_testing" in data["component_categories"]
        assert "api_testing" in data["component_categories"]
        assert data["total_components"] == 25
    
    def test_create_project_endpoint(self, client):
        """Test project creation endpoint"""
        project_data = {
            "name": "Test Project",
            "prd_content": "Create a simple web application with user authentication",
            "project_config": {"environment": "test"}
        }
        
        response = client.post("/api/v1/rpa/projects/create", json=project_data)
        assert response.status_code == 200
        
        data = response.json()
        assert "project_id" in data
        assert data["status"] == "initializing"
        assert data["message"] == "Project created successfully. PRD processing started."
    
    def test_get_project_status_not_found(self, client):
        """Test getting status of non-existent project"""
        response = client.get("/api/v1/rpa/projects/nonexistent")
        assert response.status_code == 404
        assert "not found" in response.json()["detail"]


class TestIntegrationWorkflow:
    """End-to-end integration workflow tests"""
    
    @pytest.mark.asyncio
    async def test_complete_autonomous_workflow(self):
        """Test complete autonomous workflow from PRD to validation"""
        
        # This would be a comprehensive end-to-end test
        # For now, we'll test the workflow components individually
        
        # 1. Test PRD processing
        mapping_service = ComponentMappingService()
        mock_span = MagicMock()
        mock_span.add_info_events = MagicMock()
        
        prd_content = """
        # Test Application
        Create a web application with user authentication and product catalog.
        Users should be able to login, browse products, and make purchases.
        API endpoints should return proper status codes and handle errors gracefully.
        """
        
        project_config = {"project_id": "integration_test"}
        
        workflow_mappings = await mapping_service.create_project_workflow_mappings(
            prd_content=prd_content,
            project_config=project_config,
            span=mock_span
        )
        
        assert workflow_mappings["project_id"] == "integration_test"
        assert len(workflow_mappings["requirements"]) > 0
        
        # 2. Test workflow execution simulation
        rpa_plugin = AstronRpaPlugin()
        
        with patch.object(rpa_plugin, 'run', new_callable=AsyncMock) as mock_run:
            mock_run.return_value = {"status": "success", "validation_passed": True}
            
            workflow_config = RpaWorkflowConfig(
                workflow_type="integration_test",
                parameters={"test_mode": True}
            )
            
            result = await rpa_plugin.execute_component_workflow(
                component_category="ui_testing",
                workflow_config=workflow_config,
                span=mock_span
            )
            
            assert result.success is True


# Test fixtures and utilities
@pytest.fixture
def sample_prd_content():
    """Sample PRD content for testing"""
    return """
    # E-Commerce Platform Requirements
    
    ## User Authentication
    - Users must be able to register with email and password
    - Users must be able to login with valid credentials
    - System should validate email format and password strength
    
    ## Product Catalog
    - Users should be able to browse products by category
    - Product search functionality with filters
    - Product details page with images and descriptions
    
    ## API Requirements
    - RESTful API endpoints for all user operations
    - Authentication endpoints (/api/auth/login, /api/auth/register)
    - Product endpoints (/api/products, /api/products/{id})
    - All endpoints should return proper HTTP status codes
    
    ## Performance Requirements
    - Page load time under 2 seconds
    - Support for 1000 concurrent users
    - 99.9% uptime requirement
    """


@pytest.fixture
def sample_project_config():
    """Sample project configuration for testing"""
    return {
        "environment": "test",
        "validation_level": "comprehensive",
        "parallel_execution": True,
        "timeout": 300
    }


if __name__ == "__main__":
    # Run tests with pytest
    pytest.main([__file__, "-v", "--tb=short"])
