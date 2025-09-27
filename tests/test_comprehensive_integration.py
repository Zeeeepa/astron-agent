"""
Comprehensive Integration Tests for Astron-Agent

Tests the complete integration between Astron-Agent and Astron-RPA,
including project creation, workflow execution, and validation.
"""

import asyncio
import json
import time
import pytest
import aiohttp
from typing import Dict, Any, List
from unittest.mock import AsyncMock, patch

from tests.conftest import TestConfig


class TestComprehensiveIntegration:
    """Comprehensive integration tests"""
    
    @pytest.fixture
    def test_config(self):
        """Test configuration"""
        return TestConfig()
    
    @pytest.fixture
    async def http_session(self):
        """HTTP session for API calls"""
        async with aiohttp.ClientSession() as session:
            yield session
    
    @pytest.mark.asyncio
    async def test_complete_project_lifecycle(self, test_config, http_session):
        """Test complete project lifecycle from PRD to validation"""
        
        # Step 1: Create project with PRD
        project_data = {
            "name": "Test E-commerce Platform",
            "prd_content": """
            # E-commerce Platform PRD
            
            ## Overview
            Build a modern e-commerce platform with the following features:
            
            ## Core Features
            1. User Authentication and Registration
            2. Product Catalog with Search and Filtering
            3. Shopping Cart and Checkout Process
            4. Payment Integration (Stripe/PayPal)
            5. Order Management System
            6. Admin Dashboard
            
            ## Technical Requirements
            - React.js frontend
            - Node.js/Express backend
            - PostgreSQL database
            - Redis for caching
            - Docker deployment
            
            ## Validation Requirements
            - All user flows must be tested
            - Payment processing must be validated
            - Performance must meet SLA requirements
            - Security vulnerabilities must be addressed
            """,
            "project_config": {
                "technology_stack": ["React", "Node.js", "PostgreSQL", "Redis"],
                "deployment_target": "Docker",
                "validation_level": "comprehensive"
            }
        }
        
        # Create project
        async with http_session.post(
            f"{test_config.agent_url}/api/v1/rpa/projects/create",
            json=project_data
        ) as response:
            assert response.status == 200
            project_response = await response.json()
            project_id = project_response["project_id"]
            assert project_response["status"] == "initializing"
        
        # Step 2: Wait for PRD processing to complete
        max_wait_time = 300  # 5 minutes
        start_time = time.time()
        
        while time.time() - start_time < max_wait_time:
            async with http_session.get(
                f"{test_config.agent_url}/api/v1/rpa/projects/{project_id}"
            ) as response:
                assert response.status == 200
                status_response = await response.json()
                
                if status_response["status"] == "ready":
                    break
                elif status_response["status"] == "failed":
                    pytest.fail(f"PRD processing failed: {status_response.get('error')}")
                
                await asyncio.sleep(10)
        else:
            pytest.fail("PRD processing timed out")
        
        # Step 3: Get generated workflows
        async with http_session.get(
            f"{test_config.agent_url}/api/v1/rpa/projects/{project_id}/workflows"
        ) as response:
            assert response.status == 200
            workflows_response = await response.json()
            
            assert "workflow_mappings" in workflows_response
            assert "execution_plan" in workflows_response
            
            workflow_mappings = workflows_response["workflow_mappings"]
            execution_plan = workflows_response["execution_plan"]
            
            # Validate workflow mappings contain expected components
            assert len(workflow_mappings) > 0
            assert any("ui_testing" in mapping for mapping in workflow_mappings.values())
            assert any("api_testing" in mapping for mapping in workflow_mappings.values())
        
        # Step 4: Execute UI testing workflow
        ui_workflow_request = {
            "project_id": project_id,
            "workflow_type": "ui_validation",
            "component_category": "ui_testing",
            "parameters": {
                "target_url": "http://localhost:3000",
                "test_scenarios": [
                    "user_registration",
                    "product_search",
                    "add_to_cart",
                    "checkout_process"
                ],
                "browser": "chromium",
                "headless": True
            },
            "timeout": 600
        }
        
        async with http_session.post(
            f"{test_config.agent_url}/api/v1/rpa/workflows/execute",
            json=ui_workflow_request
        ) as response:
            assert response.status == 200
            execution_response = await response.json()
            ui_execution_id = execution_response["execution_id"]
            assert execution_response["status"] == "running"
        
        # Step 5: Execute API testing workflow
        api_workflow_request = {
            "project_id": project_id,
            "workflow_type": "api_validation",
            "component_category": "api_testing",
            "parameters": {
                "base_url": "http://localhost:8000/api",
                "test_endpoints": [
                    {"method": "POST", "path": "/auth/register", "test_type": "functionality"},
                    {"method": "POST", "path": "/auth/login", "test_type": "functionality"},
                    {"method": "GET", "path": "/products", "test_type": "performance"},
                    {"method": "POST", "path": "/cart/add", "test_type": "functionality"},
                    {"method": "POST", "path": "/orders/create", "test_type": "functionality"}
                ],
                "performance_thresholds": {
                    "response_time_ms": 500,
                    "throughput_rps": 100
                }
            },
            "timeout": 600
        }
        
        async with http_session.post(
            f"{test_config.agent_url}/api/v1/rpa/workflows/execute",
            json=api_workflow_request
        ) as response:
            assert response.status == 200
            execution_response = await response.json()
            api_execution_id = execution_response["execution_id"]
            assert execution_response["status"] == "running"
        
        # Step 6: Wait for workflow executions to complete
        execution_ids = [ui_execution_id, api_execution_id]
        execution_results = {}
        
        for execution_id in execution_ids:
            max_wait_time = 600  # 10 minutes
            start_time = time.time()
            
            while time.time() - start_time < max_wait_time:
                async with http_session.get(
                    f"{test_config.agent_url}/api/v1/rpa/workflows/execution/{execution_id}"
                ) as response:
                    assert response.status == 200
                    execution_status = await response.json()
                    
                    if execution_status["status"] == "completed":
                        execution_results[execution_id] = execution_status
                        break
                    elif execution_status["status"] == "failed":
                        pytest.fail(f"Workflow execution failed: {execution_status.get('error')}")
                    
                    await asyncio.sleep(15)
            else:
                pytest.fail(f"Workflow execution {execution_id} timed out")
        
        # Step 7: Execute autonomous validation
        validation_request = {
            "project_id": project_id,
            "task_result": {
                "ui_testing": execution_results[ui_execution_id]["result"],
                "api_testing": execution_results[api_execution_id]["result"]
            },
            "expected_behavior": {
                "ui_flows": {
                    "user_registration": {"success_rate": 0.95, "avg_time_ms": 3000},
                    "product_search": {"success_rate": 0.98, "avg_time_ms": 1000},
                    "add_to_cart": {"success_rate": 0.97, "avg_time_ms": 1500},
                    "checkout_process": {"success_rate": 0.95, "avg_time_ms": 5000}
                },
                "api_endpoints": {
                    "response_time_threshold_ms": 500,
                    "success_rate_threshold": 0.95,
                    "error_rate_threshold": 0.05
                },
                "overall_requirements": {
                    "availability": 0.99,
                    "performance_score": 0.85,
                    "security_score": 0.90
                }
            }
        }
        
        async with http_session.post(
            f"{test_config.agent_url}/api/v1/rpa/validation/execute",
            json=validation_request
        ) as response:
            assert response.status == 200
            validation_response = await response.json()
            
            # Validate the validation results
            assert "validation_id" in validation_response
            assert "overall_valid" in validation_response
            assert "validation_results" in validation_response
            
            validation_results = validation_response["validation_results"]
            
            # Check that all major validation categories are present
            expected_categories = ["ui_validation", "api_validation", "performance_validation", "security_validation"]
            for category in expected_categories:
                assert category in validation_results
                assert "success" in validation_results[category]
                assert "details" in validation_results[category]
        
        # Step 8: Verify project completion status
        async with http_session.get(
            f"{test_config.agent_url}/api/v1/rpa/projects/{project_id}"
        ) as response:
            assert response.status == 200
            final_status = await response.json()
            
            # Project should be in a completed state with all workflows executed
            assert final_status["status"] in ["ready", "completed"]
            assert final_status["data"]["workflow_mappings_count"] > 0
    
    @pytest.mark.asyncio
    async def test_component_mapping_accuracy(self, test_config, http_session):
        """Test that component mapping accurately maps PRD requirements to RPA components"""
        
        # Test different types of PRDs
        test_cases = [
            {
                "name": "Web Application",
                "prd": "Build a web application with user authentication, dashboard, and reporting",
                "expected_components": ["rpabrowser", "rpanetwork", "rpaopenapi"]
            },
            {
                "name": "Data Processing Pipeline",
                "prd": "Create a data processing pipeline that reads Excel files, processes data, and generates PDF reports",
                "expected_components": ["rpaexcel", "rpapdf", "rpadatabase"]
            },
            {
                "name": "AI-Powered System",
                "prd": "Develop an AI system for document analysis and verification",
                "expected_components": ["rpaai", "rpaverifycode", "rpapdf", "rpadocx"]
            },
            {
                "name": "Enterprise Integration",
                "prd": "Build enterprise system integration with email notifications and encryption",
                "expected_components": ["rpaenterprise", "rpaemail", "rpaencrypt"]
            }
        ]
        
        for test_case in test_cases:
            project_data = {
                "name": test_case["name"],
                "prd_content": test_case["prd"],
                "project_config": {"validation_level": "basic"}
            }
            
            # Create project
            async with http_session.post(
                f"{test_config.agent_url}/api/v1/rpa/projects/create",
                json=project_data
            ) as response:
                assert response.status == 200
                project_response = await response.json()
                project_id = project_response["project_id"]
            
            # Wait for processing
            await self._wait_for_project_ready(http_session, test_config, project_id)
            
            # Get workflows
            async with http_session.get(
                f"{test_config.agent_url}/api/v1/rpa/projects/{project_id}/workflows"
            ) as response:
                assert response.status == 200
                workflows_response = await response.json()
                
                workflow_mappings = workflows_response["workflow_mappings"]
                
                # Check that expected components are mapped
                all_mapped_components = []
                for mapping in workflow_mappings.values():
                    if "components" in mapping:
                        all_mapped_components.extend(mapping["components"])
                
                for expected_component in test_case["expected_components"]:
                    assert expected_component in all_mapped_components, \
                        f"Expected component {expected_component} not found in mappings for {test_case['name']}"
    
    @pytest.mark.asyncio
    async def test_error_handling_and_recovery(self, test_config, http_session):
        """Test error handling and recovery mechanisms"""
        
        # Test 1: Invalid PRD content
        invalid_project_data = {
            "name": "Invalid Project",
            "prd_content": "",  # Empty PRD
            "project_config": {}
        }
        
        async with http_session.post(
            f"{test_config.agent_url}/api/v1/rpa/projects/create",
            json=invalid_project_data
        ) as response:
            # Should still create project but fail during processing
            assert response.status == 200
            project_response = await response.json()
            project_id = project_response["project_id"]
        
        # Wait and check that it fails gracefully
        await asyncio.sleep(30)
        async with http_session.get(
            f"{test_config.agent_url}/api/v1/rpa/projects/{project_id}"
        ) as response:
            assert response.status == 200
            status_response = await response.json()
            # Should either be processing or failed, but not crashed
            assert status_response["status"] in ["processing_prd", "failed", "ready"]
        
        # Test 2: Non-existent project workflow execution
        invalid_workflow_request = {
            "project_id": "non-existent-project-id",
            "workflow_type": "ui_validation",
            "component_category": "ui_testing",
            "parameters": {},
            "timeout": 300
        }
        
        async with http_session.post(
            f"{test_config.agent_url}/api/v1/rpa/workflows/execute",
            json=invalid_workflow_request
        ) as response:
            assert response.status == 404
        
        # Test 3: Invalid validation request
        invalid_validation_request = {
            "project_id": "non-existent-project-id",
            "task_result": {},
            "expected_behavior": {}
        }
        
        async with http_session.post(
            f"{test_config.agent_url}/api/v1/rpa/validation/execute",
            json=invalid_validation_request
        ) as response:
            assert response.status == 404
    
    @pytest.mark.asyncio
    async def test_performance_and_scalability(self, test_config, http_session):
        """Test performance and scalability of the system"""
        
        # Create multiple projects concurrently
        concurrent_projects = 5
        project_tasks = []
        
        for i in range(concurrent_projects):
            project_data = {
                "name": f"Performance Test Project {i}",
                "prd_content": f"""
                # Performance Test Project {i}
                
                Build a simple web application with:
                - User authentication
                - Basic CRUD operations
                - Simple reporting
                """,
                "project_config": {"validation_level": "basic"}
            }
            
            task = self._create_project_async(http_session, test_config, project_data)
            project_tasks.append(task)
        
        # Execute all project creations concurrently
        start_time = time.time()
        project_results = await asyncio.gather(*project_tasks, return_exceptions=True)
        creation_time = time.time() - start_time
        
        # Verify all projects were created successfully
        successful_projects = [r for r in project_results if not isinstance(r, Exception)]
        assert len(successful_projects) == concurrent_projects
        
        # Verify creation time is reasonable (should be under 30 seconds for 5 projects)
        assert creation_time < 30
        
        # Wait for all projects to be processed
        project_ids = [r["project_id"] for r in successful_projects]
        
        for project_id in project_ids:
            await self._wait_for_project_ready(http_session, test_config, project_id, timeout=300)
        
        # Verify all projects are ready
        for project_id in project_ids:
            async with http_session.get(
                f"{test_config.agent_url}/api/v1/rpa/projects/{project_id}"
            ) as response:
                assert response.status == 200
                status_response = await response.json()
                assert status_response["status"] == "ready"
    
    async def _create_project_async(self, http_session, test_config, project_data):
        """Helper method to create a project asynchronously"""
        async with http_session.post(
            f"{test_config.agent_url}/api/v1/rpa/projects/create",
            json=project_data
        ) as response:
            assert response.status == 200
            return await response.json()
    
    async def _wait_for_project_ready(self, http_session, test_config, project_id, timeout=300):
        """Helper method to wait for project to be ready"""
        start_time = time.time()
        
        while time.time() - start_time < timeout:
            async with http_session.get(
                f"{test_config.agent_url}/api/v1/rpa/projects/{project_id}"
            ) as response:
                assert response.status == 200
                status_response = await response.json()
                
                if status_response["status"] == "ready":
                    return
                elif status_response["status"] == "failed":
                    pytest.fail(f"Project {project_id} processing failed: {status_response.get('error')}")
                
                await asyncio.sleep(10)
        
        pytest.fail(f"Project {project_id} processing timed out")


if __name__ == "__main__":
    pytest.main([__file__, "-v"])
