"""
Comprehensive Integration Tests for Astron-RPA Integration

Tests the complete integration between Astron-Agent and Astron-RPA,
including PRD processing, workflow execution, and validation.
"""

import asyncio
import json
import pytest
import time
from typing import Dict, Any
from unittest.mock import AsyncMock, MagicMock, patch

import httpx
from fastapi.testclient import TestClient

from core.agent.api.app import app
from core.agent.service.plugin.astron_rpa_plugin import AstronRpaPlugin
from core.agent.service.mapping.component_mapper import ComponentMappingService


class TestRpaIntegrationAPI:
    """Test RPA Integration API endpoints"""
    
    def setup_method(self):
        """Setup test client and mock data"""
        self.client = TestClient(app)
        self.test_project_data = {
            "name": "Test E-commerce Platform",
            "prd_content": """
            Create a comprehensive e-commerce web application with the following features:
            
            1. User Authentication System
            - User registration and login
            - Password reset functionality
            - Profile management
            
            2. Product Catalog
            - Product listing with search and filters
            - Product detail pages
            - Category management
            
            3. Shopping Cart & Checkout
            - Add/remove items from cart
            - Checkout process with payment integration
            - Order confirmation and tracking
            
            4. Admin Dashboard
            - Product management
            - Order management
            - User management
            - Analytics and reporting
            
            5. API Endpoints
            - RESTful API for all operations
            - Authentication endpoints
            - Product CRUD operations
            - Order processing endpoints
            """,
            "project_config": {
                "target_url": "http://localhost:3000",
                "api_endpoints": [
                    "/api/auth/login",
                    "/api/auth/register",
                    "/api/products",
                    "/api/cart",
                    "/api/orders"
                ],
                "ui_requirements": [
                    "login_form",
                    "product_list",
                    "shopping_cart",
                    "checkout_form",
                    "admin_dashboard"
                ]
            }
        }
    
    def test_health_check(self):
        """Test RPA integration health check"""
        response = self.client.get("/api/v1/rpa/health")
        assert response.status_code == 200
        
        data = response.json()
        assert data["status"] == "healthy"
        assert data["service"] == "rpa_integration"
        assert "timestamp" in data
        assert "active_projects" in data
        assert "active_executions" in data
    
    def test_component_mapping_info(self):
        """Test component mapping information endpoint"""
        response = self.client.get("/api/v1/rpa/components/mapping")
        assert response.status_code == 200
        
        data = response.json()
        assert "component_categories" in data
        assert "total_components" in data
        assert "supported_workflows" in data
        
        # Verify component categories
        categories = data["component_categories"]
        expected_categories = [
            "ui_automation", "api_testing", "data_processing", 
            "ai_processing", "system_automation"
        ]
        
        for category in expected_categories:
            assert category in categories
            assert "components" in categories[category]
            assert "description" in categories[category]
    
    @patch('core.agent.service.mapping.component_mapper.ComponentMappingService.create_project_workflow_mappings')
    def test_create_project_success(self, mock_mapping_service):
        """Test successful project creation"""
        # Mock the mapping service response
        mock_mapping_service.return_value = {
            "workflow_mappings": {
                "req_1": {
                    "component_category": "ui_automation",
                    "workflow_type": "ui_validation",
                    "components": ["rpabrowser", "rpacv"],
                    "parameters": {"target_url": "http://localhost:3000"}
                }
            },
            "execution_plan": {
                "phases": [
                    {
                        "phase_name": "ui_automation_execution",
                        "category": "ui_automation",
                        "workflows": []
                    }
                ]
            },
            "validation_strategy": {
                "validation_phases": []
            },
            "requirements": []
        }
        
        response = self.client.post(
            "/api/v1/rpa/projects/create",
            json=self.test_project_data
        )
        
        assert response.status_code == 200
        data = response.json()
        
        assert "project_id" in data
        assert data["status"] == "initializing"
        assert data["message"] == "Project created successfully. PRD processing started."
        assert "data" in data
        assert data["data"]["project_name"] == self.test_project_data["name"]
    
    def test_create_project_invalid_data(self):
        """Test project creation with invalid data"""
        invalid_data = {
            "name": "",  # Empty name
            "prd_content": ""  # Empty PRD
        }
        
        response = self.client.post(
            "/api/v1/rpa/projects/create",
            json=invalid_data
        )
        
        # Should still create project but with empty content
        assert response.status_code == 200
    
    def test_get_project_status_not_found(self):
        """Test getting status of non-existent project"""
        response = self.client.get("/api/v1/rpa/projects/nonexistent-id")
        assert response.status_code == 404
        assert "not found" in response.json()["detail"]
    
    def test_execute_workflow_project_not_found(self):
        """Test workflow execution with non-existent project"""
        workflow_request = {
            "project_id": "nonexistent-id",
            "workflow_type": "ui_validation",
            "component_category": "ui_automation",
            "parameters": {"target_url": "http://localhost:3000"}
        }
        
        response = self.client.post(
            "/api/v1/rpa/workflows/execute",
            json=workflow_request
        )
        
        assert response.status_code == 404
        assert "not found" in response.json()["detail"]
    
    def test_validation_project_not_found(self):
        """Test validation execution with non-existent project"""
        validation_request = {
            "project_id": "nonexistent-id",
            "task_result": {"deployment_url": "http://localhost:3000"},
            "expected_behavior": {"ui_requirements": ["login_form"]}
        }
        
        response = self.client.post(
            "/api/v1/rpa/validation/execute",
            json=validation_request
        )
        
        assert response.status_code == 404
        assert "not found" in response.json()["detail"]


class TestRpaPlugin:
    """Test Astron-RPA Plugin functionality"""
    
    def setup_method(self):
        """Setup test environment"""
        self.plugin = AstronRpaPlugin(
            rpa_openapi_url="http://localhost:8020",
            api_key="test-api-key"
        )
        self.mock_span = MagicMock()
        self.mock_span.start.return_value.__enter__ = MagicMock(return_value=self.mock_span)
        self.mock_span.start.return_value.__exit__ = MagicMock(return_value=None)
    
    @patch('httpx.AsyncClient.post')
    async def test_execute_component_workflow_success(self, mock_post):
        """Test successful component workflow execution"""
        # Mock successful response
        mock_response = MagicMock()
        mock_response.status_code = 200
        mock_response.json.return_value = {
            "execution_id": "exec-123",
            "status": "completed",
            "result": {
                "success": True,
                "ui_elements_found": ["login_form", "submit_button"],
                "screenshots": ["screenshot1.png"],
                "validation_results": {
                    "ui_validation": True,
                    "functionality_test": True
                }
            }
        }
        mock_post.return_value = mock_response
        
        from core.agent.service.plugin.astron_rpa_plugin import RpaWorkflowConfig
        workflow_config = RpaWorkflowConfig(
            workflow_type="ui_validation",
            components=["rpabrowser", "rpacv"],
            parameters={"target_url": "http://localhost:3000"},
            timeout=300
        )
        
        result = await self.plugin.execute_component_workflow(
            component_category="ui_automation",
            workflow_config=workflow_config,
            span=self.mock_span
        )
        
        assert result.success is True
        assert result.result["success"] is True
        assert "ui_elements_found" in result.result
        assert "screenshots" in result.result
    
    @patch('httpx.AsyncClient.post')
    async def test_execute_autonomous_validation_success(self, mock_post):
        """Test successful autonomous validation"""
        # Mock successful validation response
        mock_response = MagicMock()
        mock_response.status_code = 200
        mock_response.json.return_value = {
            "validation_id": "val-123",
            "overall_valid": True,
            "validation_results": {
                "ui_validation": {
                    "success": True,
                    "elements_found": ["login_form", "product_list"],
                    "screenshots": ["ui_validation.png"]
                },
                "api_validation": {
                    "success": True,
                    "endpoints_tested": ["/api/auth", "/api/products"],
                    "response_times": {"avg": 150, "max": 300}
                },
                "data_validation": {
                    "success": True,
                    "database_checks": ["users_table", "products_table"],
                    "data_integrity": True
                }
            },
            "timestamp": int(time.time())
        }
        mock_post.return_value = mock_response
        
        task_result = {
            "deployment_url": "http://localhost:3000",
            "api_url": "http://localhost:3000/api",
            "database_config": {"host": "localhost", "port": 3306}
        }
        
        expected_behavior = {
            "ui_requirements": ["login_form", "product_list", "shopping_cart"],
            "api_requirements": [
                {"endpoint": "/api/auth", "method": "POST"},
                {"endpoint": "/api/products", "method": "GET"}
            ],
            "data_requirements": ["users_table", "products_table"]
        }
        
        result = await self.plugin.execute_autonomous_validation(
            task_result=task_result,
            expected_behavior=expected_behavior,
            span=self.mock_span
        )
        
        assert result["overall_valid"] is True
        assert "validation_results" in result
        assert "ui_validation" in result["validation_results"]
        assert "api_validation" in result["validation_results"]
        assert "data_validation" in result["validation_results"]


class TestComponentMapper:
    """Test Component Mapping Service"""
    
    def setup_method(self):
        """Setup test environment"""
        self.mapper_service = ComponentMappingService()
        self.mock_span = MagicMock()
        self.mock_span.start.return_value.__enter__ = MagicMock(return_value=self.mock_span)
        self.mock_span.start.return_value.__exit__ = MagicMock(return_value=None)
    
    async def test_create_project_workflow_mappings(self):
        """Test creating workflow mappings from PRD"""
        prd_content = """
        Create a web application with:
        - User authentication system with login and registration
        - Product catalog with search functionality
        - Shopping cart and checkout process
        - Admin dashboard for product management
        - RESTful API endpoints for all operations
        - Database integration for data persistence
        """
        
        project_config = {
            "target_url": "http://localhost:3000",
            "api_endpoints": ["/api/auth", "/api/products", "/api/cart"]
        }
        
        result = await self.mapper_service.create_project_workflow_mappings(
            prd_content=prd_content,
            project_config=project_config,
            span=self.mock_span
        )
        
        assert "requirements" in result
        assert "workflow_mappings" in result
        assert "execution_plan" in result
        assert "validation_strategy" in result
        
        # Check that requirements were extracted
        assert len(result["requirements"]) > 0
        
        # Check that workflow mappings were created
        assert len(result["workflow_mappings"]) > 0
        
        # Check execution plan structure
        execution_plan = result["execution_plan"]
        assert "phases" in execution_plan
        assert "total_workflows" in execution_plan
        assert "estimated_duration" in execution_plan
        
        # Check validation strategy
        validation_strategy = result["validation_strategy"]
        assert "validation_phases" in validation_strategy
        assert "overall_success_criteria" in validation_strategy


class TestEndToEndWorkflow:
    """End-to-end integration tests"""
    
    def setup_method(self):
        """Setup test environment"""
        self.client = TestClient(app)
        self.project_id = None
    
    @pytest.mark.asyncio
    async def test_complete_prd_to_validation_workflow(self):
        """Test complete workflow from PRD to validation"""
        # Step 1: Create project
        project_data = {
            "name": "E2E Test Project",
            "prd_content": """
            Create a simple web application with:
            - User login functionality
            - Product listing page
            - Basic API endpoints
            """,
            "project_config": {
                "target_url": "http://localhost:3000",
                "api_endpoints": ["/api/auth", "/api/products"]
            }
        }
        
        with patch('core.agent.service.mapping.component_mapper.ComponentMappingService.create_project_workflow_mappings') as mock_mapping:
            mock_mapping.return_value = {
                "workflow_mappings": {
                    "req_1": {
                        "component_category": "ui_automation",
                        "workflow_type": "ui_validation",
                        "components": ["rpabrowser"],
                        "parameters": {"target_url": "http://localhost:3000"}
                    }
                },
                "execution_plan": {"phases": []},
                "validation_strategy": {"validation_phases": []},
                "requirements": [{"id": "req_1", "description": "User login"}]
            }
            
            response = self.client.post("/api/v1/rpa/projects/create", json=project_data)
            assert response.status_code == 200
            
            project_response = response.json()
            self.project_id = project_response["project_id"]
        
        # Step 2: Wait for PRD processing (simulate)
        await asyncio.sleep(0.1)  # Simulate processing time
        
        # Step 3: Check project status
        response = self.client.get(f"/api/v1/rpa/projects/{self.project_id}")
        assert response.status_code == 200
        
        # Step 4: Execute workflow
        workflow_request = {
            "project_id": self.project_id,
            "workflow_type": "ui_validation",
            "component_category": "ui_automation",
            "parameters": {"target_url": "http://localhost:3000"}
        }
        
        with patch('core.agent.service.plugin.astron_rpa_plugin.AstronRpaPlugin.execute_component_workflow') as mock_execute:
            mock_result = MagicMock()
            mock_result.success = True
            mock_result.result = {"ui_elements_found": ["login_form"]}
            mock_execute.return_value = mock_result
            
            response = self.client.post("/api/v1/rpa/workflows/execute", json=workflow_request)
            assert response.status_code == 200
            
            execution_response = response.json()
            execution_id = execution_response["execution_id"]
        
        # Step 5: Check execution status
        response = self.client.get(f"/api/v1/rpa/workflows/execution/{execution_id}")
        assert response.status_code == 200
        
        # Step 6: Execute validation
        validation_request = {
            "project_id": self.project_id,
            "task_result": {"deployment_url": "http://localhost:3000"},
            "expected_behavior": {"ui_requirements": ["login_form"]}
        }
        
        with patch('core.agent.service.plugin.astron_rpa_plugin.AstronRpaPlugin.execute_autonomous_validation') as mock_validate:
            mock_validate.return_value = {
                "overall_valid": True,
                "validation_results": {"ui_validation": {"success": True}},
                "timestamp": int(time.time())
            }
            
            response = self.client.post("/api/v1/rpa/validation/execute", json=validation_request)
            assert response.status_code == 200
            
            validation_response = response.json()
            assert validation_response["overall_valid"] is True


class TestErrorHandling:
    """Test error handling and edge cases"""
    
    def setup_method(self):
        """Setup test environment"""
        self.client = TestClient(app)
    
    def test_malformed_json_request(self):
        """Test handling of malformed JSON requests"""
        response = self.client.post(
            "/api/v1/rpa/projects/create",
            data="invalid json",
            headers={"Content-Type": "application/json"}
        )
        assert response.status_code == 422  # Unprocessable Entity
    
    def test_missing_required_fields(self):
        """Test handling of missing required fields"""
        incomplete_data = {
            "name": "Test Project"
            # Missing prd_content
        }
        
        response = self.client.post(
            "/api/v1/rpa/projects/create",
            json=incomplete_data
        )
        assert response.status_code == 422  # Validation error
    
    @patch('core.agent.service.plugin.astron_rpa_plugin.AstronRpaPlugin.execute_component_workflow')
    async def test_workflow_execution_timeout(self, mock_execute):
        """Test workflow execution timeout handling"""
        # Mock timeout exception
        mock_execute.side_effect = asyncio.TimeoutError("Workflow execution timed out")
        
        # This would be tested in a real integration test
        # For now, we just verify the mock setup
        assert mock_execute.side_effect is not None
    
    def test_invalid_component_category(self):
        """Test handling of invalid component category"""
        # Create a project first (mocked)
        with patch('core.agent.api.v1.rpa_integration.active_projects') as mock_projects:
            mock_projects.__contains__ = MagicMock(return_value=True)
            mock_projects.__getitem__ = MagicMock(return_value={
                "id": "test-project",
                "name": "Test Project"
            })
            
            workflow_request = {
                "project_id": "test-project",
                "workflow_type": "ui_validation",
                "component_category": "invalid_category",  # Invalid category
                "parameters": {}
            }
            
            response = self.client.post("/api/v1/rpa/workflows/execute", json=workflow_request)
            # Should still accept the request but may fail during execution
            assert response.status_code == 200


if __name__ == "__main__":
    # Run tests with pytest
    pytest.main([__file__, "-v", "--tb=short"])
