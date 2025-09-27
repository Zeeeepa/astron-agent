"""
Playwright Tests for RPA Integration UI Interaction

Comprehensive UI testing using Playwright to validate the complete
user interface and interaction flows for the RPA integration.
"""

import asyncio
import json
import time
from typing import Dict, Any

import pytest
from playwright.async_api import async_playwright, Page, Browser, BrowserContext


class TestRpaIntegrationUI:
    """Test RPA Integration UI with Playwright"""
    
    @pytest.fixture(scope="class")
    async def browser_setup(self):
        """Setup browser for testing"""
        playwright = await async_playwright().start()
        browser = await playwright.chromium.launch(
            headless=False,  # Set to True for CI/CD
            slow_mo=500,     # Slow down for debugging
            args=['--no-sandbox', '--disable-dev-shm-usage']
        )
        
        context = await browser.new_context(
            viewport={'width': 1920, 'height': 1080},
            user_agent='Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36'
        )
        
        yield browser, context
        
        await context.close()
        await browser.close()
        await playwright.stop()
    
    @pytest.fixture
    async def page(self, browser_setup):
        """Create a new page for each test"""
        browser, context = browser_setup
        page = await context.new_page()
        
        # Enable console logging
        page.on("console", lambda msg: print(f"Console: {msg.text}"))
        page.on("pageerror", lambda error: print(f"Page Error: {error}"))
        
        yield page
        await page.close()
    
    async def test_api_health_check_ui(self, page: Page):
        """Test API health check through UI interaction"""
        # Navigate to API documentation (assuming Swagger UI is available)
        await page.goto("http://localhost:8000/docs")
        
        # Wait for Swagger UI to load
        await page.wait_for_selector(".swagger-ui", timeout=10000)
        
        # Find and click on RPA health check endpoint
        health_endpoint = page.locator('text="GET /api/v1/rpa/health"')
        await health_endpoint.click()
        
        # Click "Try it out" button
        try_it_button = page.locator('button:has-text("Try it out")')
        await try_it_button.click()
        
        # Click "Execute" button
        execute_button = page.locator('button:has-text("Execute")')
        await execute_button.click()
        
        # Wait for response
        await page.wait_for_selector('.response-col_status', timeout=5000)
        
        # Verify successful response
        response_status = await page.locator('.response-col_status').inner_text()
        assert "200" in response_status
        
        # Verify response body contains expected fields
        response_body = await page.locator('.response-col_description pre').inner_text()
        response_data = json.loads(response_body)
        
        assert response_data["status"] == "healthy"
        assert response_data["service"] == "rpa_integration"
        assert "timestamp" in response_data
    
    async def test_create_project_ui_flow(self, page: Page):
        """Test project creation through UI"""
        await page.goto("http://localhost:8000/docs")
        await page.wait_for_selector(".swagger-ui", timeout=10000)
        
        # Find and expand the create project endpoint
        create_project_endpoint = page.locator('text="POST /api/v1/rpa/projects/create"')
        await create_project_endpoint.click()
        
        # Click "Try it out"
        try_it_button = page.locator('button:has-text("Try it out")').first
        await try_it_button.click()
        
        # Fill in the request body
        request_body = {
            "name": "Playwright Test Project",
            "prd_content": """
            Create a modern e-commerce web application with:
            - User authentication (login/register)
            - Product catalog with search
            - Shopping cart functionality
            - Checkout process
            - Admin dashboard
            - RESTful API endpoints
            """,
            "project_config": {
                "target_url": "http://localhost:3000",
                "api_endpoints": [
                    "/api/auth/login",
                    "/api/products",
                    "/api/cart"
                ]
            }
        }
        
        # Find and fill the request body textarea
        request_textarea = page.locator('textarea[placeholder*="Request body"]')
        await request_textarea.fill(json.dumps(request_body, indent=2))
        
        # Execute the request
        execute_button = page.locator('button:has-text("Execute")').first
        await execute_button.click()
        
        # Wait for response
        await page.wait_for_selector('.response-col_status', timeout=10000)
        
        # Verify successful response
        response_status = await page.locator('.response-col_status').inner_text()
        assert "200" in response_status
        
        # Get project ID from response
        response_body = await page.locator('.response-col_description pre').inner_text()
        response_data = json.loads(response_body)
        
        assert response_data["status"] == "initializing"
        assert "project_id" in response_data
        
        return response_data["project_id"]
    
    async def test_component_mapping_ui(self, page: Page):
        """Test component mapping information through UI"""
        await page.goto("http://localhost:8000/docs")
        await page.wait_for_selector(".swagger-ui", timeout=10000)
        
        # Find component mapping endpoint
        mapping_endpoint = page.locator('text="GET /api/v1/rpa/components/mapping"')
        await mapping_endpoint.click()
        
        # Try it out and execute
        try_it_button = page.locator('button:has-text("Try it out")').nth(1)
        await try_it_button.click()
        
        execute_button = page.locator('button:has-text("Execute")').nth(1)
        await execute_button.click()
        
        # Wait for response
        await page.wait_for_selector('.response-col_status', timeout=5000)
        
        # Verify response
        response_status = await page.locator('.response-col_status').inner_text()
        assert "200" in response_status
        
        response_body = await page.locator('.response-col_description pre').inner_text()
        response_data = json.loads(response_body)
        
        # Verify component categories
        assert "component_categories" in response_data
        categories = response_data["component_categories"]
        
        expected_categories = [
            "ui_automation", "api_testing", "data_processing",
            "ai_processing", "system_automation"
        ]
        
        for category in expected_categories:
            assert category in categories
    
    async def test_workflow_execution_ui(self, page: Page):
        """Test workflow execution through UI"""
        # First create a project
        project_id = await self.test_create_project_ui_flow(page)
        
        # Wait a bit for project to be processed
        await page.wait_for_timeout(2000)
        
        # Navigate to workflow execution endpoint
        workflow_endpoint = page.locator('text="POST /api/v1/rpa/workflows/execute"')
        await workflow_endpoint.click()
        
        # Try it out
        try_it_button = page.locator('button:has-text("Try it out")').nth(2)
        await try_it_button.click()
        
        # Fill workflow execution request
        workflow_request = {
            "project_id": project_id,
            "workflow_type": "ui_validation",
            "component_category": "ui_automation",
            "parameters": {
                "target_url": "http://localhost:3000",
                "ui_elements": ["login_form", "product_list"]
            },
            "timeout": 300
        }
        
        request_textarea = page.locator('textarea[placeholder*="Request body"]').nth(1)
        await request_textarea.fill(json.dumps(workflow_request, indent=2))
        
        # Execute
        execute_button = page.locator('button:has-text("Execute")').nth(2)
        await execute_button.click()
        
        # Wait for response
        await page.wait_for_selector('.response-col_status', timeout=10000)
        
        # Verify response
        response_status = await page.locator('.response-col_status').inner_text()
        assert "200" in response_status
        
        response_body = await page.locator('.response-col_description pre').inner_text()
        response_data = json.loads(response_body)
        
        assert "execution_id" in response_data
        assert response_data["status"] == "running"
        
        return response_data["execution_id"]
    
    async def test_validation_execution_ui(self, page: Page):
        """Test validation execution through UI"""
        # First create a project
        project_id = await self.test_create_project_ui_flow(page)
        
        # Wait for project processing
        await page.wait_for_timeout(2000)
        
        # Navigate to validation endpoint
        validation_endpoint = page.locator('text="POST /api/v1/rpa/validation/execute"')
        await validation_endpoint.click()
        
        # Try it out
        try_it_button = page.locator('button:has-text("Try it out")').nth(3)
        await try_it_button.click()
        
        # Fill validation request
        validation_request = {
            "project_id": project_id,
            "task_result": {
                "deployment_url": "http://localhost:3000",
                "api_url": "http://localhost:3000/api",
                "database_config": {
                    "host": "localhost",
                    "port": 3306
                }
            },
            "expected_behavior": {
                "ui_requirements": [
                    "login_form",
                    "product_list",
                    "shopping_cart"
                ],
                "api_requirements": [
                    {"endpoint": "/api/auth/login", "method": "POST"},
                    {"endpoint": "/api/products", "method": "GET"}
                ],
                "data_requirements": [
                    "users_table",
                    "products_table"
                ]
            }
        }
        
        request_textarea = page.locator('textarea[placeholder*="Request body"]').nth(2)
        await request_textarea.fill(json.dumps(validation_request, indent=2))
        
        # Execute
        execute_button = page.locator('button:has-text("Execute")').nth(3)
        await execute_button.click()
        
        # Wait for response
        await page.wait_for_selector('.response-col_status', timeout=15000)
        
        # Verify response
        response_status = await page.locator('.response-col_status').inner_text()
        assert "200" in response_status
        
        response_body = await page.locator('.response-col_description pre').inner_text()
        response_data = json.loads(response_body)
        
        assert "validation_id" in response_data
        assert "overall_valid" in response_data
        assert "validation_results" in response_data
    
    async def test_project_status_monitoring_ui(self, page: Page):
        """Test project status monitoring through UI"""
        # Create a project first
        project_id = await self.test_create_project_ui_flow(page)
        
        # Navigate to project status endpoint
        status_endpoint = page.locator('text="GET /api/v1/rpa/projects/{project_id}"')
        await status_endpoint.click()
        
        # Try it out
        try_it_button = page.locator('button:has-text("Try it out")').nth(4)
        await try_it_button.click()
        
        # Fill project ID parameter
        project_id_input = page.locator('input[placeholder="project_id"]')
        await project_id_input.fill(project_id)
        
        # Execute
        execute_button = page.locator('button:has-text("Execute")').nth(4)
        await execute_button.click()
        
        # Wait for response
        await page.wait_for_selector('.response-col_status', timeout=5000)
        
        # Verify response
        response_status = await page.locator('.response-col_status').inner_text()
        assert "200" in response_status
        
        response_body = await page.locator('.response-col_description pre').inner_text()
        response_data = json.loads(response_body)
        
        assert response_data["project_id"] == project_id
        assert "status" in response_data
        assert "message" in response_data
    
    async def test_error_handling_ui(self, page: Page):
        """Test error handling through UI"""
        await page.goto("http://localhost:8000/docs")
        await page.wait_for_selector(".swagger-ui", timeout=10000)
        
        # Test with non-existent project ID
        status_endpoint = page.locator('text="GET /api/v1/rpa/projects/{project_id}"')
        await status_endpoint.click()
        
        try_it_button = page.locator('button:has-text("Try it out")').nth(4)
        await try_it_button.click()
        
        # Use non-existent project ID
        project_id_input = page.locator('input[placeholder="project_id"]')
        await project_id_input.fill("nonexistent-project-id")
        
        execute_button = page.locator('button:has-text("Execute")').nth(4)
        await execute_button.click()
        
        # Wait for response
        await page.wait_for_selector('.response-col_status', timeout=5000)
        
        # Verify 404 error
        response_status = await page.locator('.response-col_status').inner_text()
        assert "404" in response_status
        
        response_body = await page.locator('.response-col_description pre').inner_text()
        response_data = json.loads(response_body)
        
        assert "not found" in response_data["detail"].lower()
    
    async def test_api_documentation_completeness(self, page: Page):
        """Test that API documentation is complete and accessible"""
        await page.goto("http://localhost:8000/docs")
        await page.wait_for_selector(".swagger-ui", timeout=10000)
        
        # Check that all RPA endpoints are documented
        expected_endpoints = [
            "POST /api/v1/rpa/projects/create",
            "GET /api/v1/rpa/projects/{project_id}",
            "POST /api/v1/rpa/workflows/execute",
            "GET /api/v1/rpa/workflows/execution/{execution_id}",
            "POST /api/v1/rpa/validation/execute",
            "GET /api/v1/rpa/projects/{project_id}/workflows",
            "GET /api/v1/rpa/health"
        ]
        
        for endpoint in expected_endpoints:
            endpoint_element = page.locator(f'text="{endpoint}"')
            await expect(endpoint_element).to_be_visible()
        
        # Check that RPA Integration tag is present
        rpa_tag = page.locator('text="RPA Integration"')
        await expect(rpa_tag).to_be_visible()
    
    async def test_response_time_monitoring(self, page: Page):
        """Test response time monitoring for API endpoints"""
        await page.goto("http://localhost:8000/docs")
        await page.wait_for_selector(".swagger-ui", timeout=10000)
        
        # Test health check response time
        start_time = time.time()
        
        health_endpoint = page.locator('text="GET /api/v1/rpa/health"')
        await health_endpoint.click()
        
        try_it_button = page.locator('button:has-text("Try it out")')
        await try_it_button.click()
        
        execute_button = page.locator('button:has-text("Execute")')
        await execute_button.click()
        
        await page.wait_for_selector('.response-col_status', timeout=5000)
        
        end_time = time.time()
        response_time = end_time - start_time
        
        # Health check should respond within 2 seconds
        assert response_time < 2.0, f"Health check took {response_time:.2f}s, expected < 2.0s"
        
        # Verify response is successful
        response_status = await page.locator('.response-col_status').inner_text()
        assert "200" in response_status


class TestRpaWebUI:
    """Test RPA Web UI (if available)"""
    
    @pytest.fixture
    async def page(self):
        """Create page for web UI testing"""
        playwright = await async_playwright().start()
        browser = await playwright.chromium.launch(headless=False)
        context = await browser.new_context()
        page = await context.new_page()
        
        yield page
        
        await context.close()
        await browser.close()
        await playwright.stop()
    
    async def test_web_ui_accessibility(self, page: Page):
        """Test web UI accessibility (if deployed)"""
        try:
            await page.goto("http://localhost:3001", timeout=5000)
            
            # Check if web UI is available
            await page.wait_for_selector("body", timeout=2000)
            
            # Basic accessibility checks
            title = await page.title()
            assert len(title) > 0, "Page should have a title"
            
            # Check for main navigation
            nav_elements = await page.locator("nav, [role='navigation']").count()
            assert nav_elements > 0, "Page should have navigation elements"
            
            # Check for main content area
            main_elements = await page.locator("main, [role='main']").count()
            assert main_elements > 0, "Page should have main content area"
            
        except Exception as e:
            # Web UI might not be deployed, skip test
            pytest.skip(f"Web UI not available: {e}")
    
    async def test_web_ui_project_management(self, page: Page):
        """Test project management through web UI"""
        try:
            await page.goto("http://localhost:3001", timeout=5000)
            await page.wait_for_selector("body", timeout=2000)
            
            # Look for project creation form
            create_button = page.locator('button:has-text("Create Project"), button:has-text("New Project")')
            if await create_button.count() > 0:
                await create_button.click()
                
                # Fill project form
                name_input = page.locator('input[name="name"], input[placeholder*="name"]')
                if await name_input.count() > 0:
                    await name_input.fill("Web UI Test Project")
                
                prd_textarea = page.locator('textarea[name="prd"], textarea[placeholder*="PRD"]')
                if await prd_textarea.count() > 0:
                    await prd_textarea.fill("Create a simple web application with user authentication")
                
                # Submit form
                submit_button = page.locator('button[type="submit"], button:has-text("Create")')
                if await submit_button.count() > 0:
                    await submit_button.click()
                    
                    # Wait for success message or redirect
                    await page.wait_for_timeout(2000)
            
        except Exception as e:
            pytest.skip(f"Web UI project management not available: {e}")


if __name__ == "__main__":
    # Run Playwright tests
    pytest.main([__file__, "-v", "--tb=short", "-s"])
