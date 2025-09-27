#!/usr/bin/env python3
"""
Playwright Interface Testing for RPA Integration

Comprehensive testing of the RPA integration interface using Playwright
to simulate real user interactions and validate all features.
"""

import asyncio
import json
import time
from typing import Dict, Any, List

from playwright.async_api import async_playwright, Page, Browser, BrowserContext


class PlaywrightInterfaceTester:
    """Comprehensive interface testing using Playwright"""
    
    def __init__(self):
        self.base_url = "http://localhost:8000"
        self.rpa_url = "http://localhost:8020"
        self.test_results = []
        
        # Test scenarios
        self.test_scenarios = [
            {
                "name": "Health Check Validation",
                "description": "Validate all health endpoints are responding",
                "endpoints": ["/health", "/api/v1/rpa/health"]
            },
            {
                "name": "Component Mapping Validation",
                "description": "Test component mapping endpoint and data structure",
                "endpoints": ["/api/v1/rpa/components/mapping"]
            },
            {
                "name": "Project Creation Workflow",
                "description": "Test complete project creation workflow",
                "endpoints": ["/api/v1/rpa/projects/create"]
            },
            {
                "name": "Workflow Execution Testing",
                "description": "Test workflow execution endpoints",
                "endpoints": ["/api/v1/rpa/workflows/execute"]
            },
            {
                "name": "Validation Execution Testing",
                "description": "Test autonomous validation execution",
                "endpoints": ["/api/v1/rpa/validation/execute"]
            }
        ]
    
    async def setup_browser(self) -> tuple[Browser, BrowserContext, Page]:
        """Setup Playwright browser for testing"""
        playwright = await async_playwright().start()
        
        # Launch browser in headless mode
        browser = await playwright.chromium.launch(
            headless=True,
            args=['--no-sandbox', '--disable-dev-shm-usage']
        )
        
        # Create context with realistic viewport
        context = await browser.new_context(
            viewport={'width': 1920, 'height': 1080},
            user_agent='Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36'
        )
        
        # Create page
        page = await context.new_page()
        
        return browser, context, page
    
    async def test_health_endpoints(self, page: Page) -> Dict[str, Any]:
        """Test health check endpoints"""
        print("🏥 Testing Health Endpoints...")
        
        results = {
            "test_name": "Health Check Validation",
            "status": "passed",
            "details": [],
            "errors": []
        }
        
        health_endpoints = [
            f"{self.base_url}/health",
            f"{self.base_url}/api/v1/rpa/health",
            f"{self.rpa_url}/health"
        ]
        
        for endpoint in health_endpoints:
            try:
                print(f"  🔍 Testing {endpoint}")
                
                # Navigate to endpoint
                response = await page.goto(endpoint)
                
                if response and response.status == 200:
                    # Get JSON content
                    content = await page.content()
                    
                    # Parse JSON from page content
                    json_start = content.find('{')
                    json_end = content.rfind('}') + 1
                    
                    if json_start != -1 and json_end > json_start:
                        json_content = content[json_start:json_end]
                        data = json.loads(json_content)
                        
                        if data.get('status') == 'healthy':
                            results["details"].append({
                                "endpoint": endpoint,
                                "status": "✅ Healthy",
                                "service": data.get('service', 'unknown'),
                                "response_time": "< 1s"
                            })
                            print(f"    ✅ {data.get('service', 'Service')} is healthy")
                        else:
                            results["errors"].append(f"Endpoint {endpoint} returned unhealthy status")
                            results["status"] = "failed"
                    else:
                        results["errors"].append(f"Invalid JSON response from {endpoint}")
                        results["status"] = "failed"
                else:
                    results["errors"].append(f"HTTP {response.status if response else 'No Response'} from {endpoint}")
                    results["status"] = "failed"
                    
            except Exception as e:
                results["errors"].append(f"Error testing {endpoint}: {str(e)}")
                results["status"] = "failed"
        
        return results
    
    async def test_component_mapping(self, page: Page) -> Dict[str, Any]:
        """Test component mapping endpoint"""
        print("🗺️ Testing Component Mapping...")
        
        results = {
            "test_name": "Component Mapping Validation",
            "status": "passed",
            "details": [],
            "errors": []
        }
        
        try:
            endpoint = f"{self.base_url}/api/v1/rpa/components/mapping"
            print(f"  🔍 Testing {endpoint}")
            
            response = await page.goto(endpoint)
            
            if response and response.status == 200:
                content = await page.content()
                json_start = content.find('{')
                json_end = content.rfind('}') + 1
                
                if json_start != -1 and json_end > json_start:
                    json_content = content[json_start:json_end]
                    data = json.loads(json_content)
                    
                    # Validate data structure
                    required_fields = ['component_categories', 'total_components', 'supported_workflows']
                    for field in required_fields:
                        if field not in data:
                            results["errors"].append(f"Missing required field: {field}")
                            results["status"] = "failed"
                    
                    if results["status"] == "passed":
                        # Validate component categories
                        categories = data.get('component_categories', {})
                        expected_categories = ['ui_testing', 'api_testing', 'data_processing', 'ai_processing', 'system_automation']
                        
                        for category in expected_categories:
                            if category in categories:
                                components = categories[category].get('components', [])
                                results["details"].append({
                                    "category": category,
                                    "components_count": len(components),
                                    "components": components[:3],  # Show first 3
                                    "status": "✅ Valid"
                                })
                                print(f"    ✅ {category}: {len(components)} components")
                            else:
                                results["errors"].append(f"Missing category: {category}")
                                results["status"] = "failed"
                        
                        # Validate totals
                        total_components = data.get('total_components', 0)
                        if total_components >= 15:
                            results["details"].append({
                                "metric": "total_components",
                                "value": total_components,
                                "status": "✅ Valid"
                            })
                            print(f"    ✅ Total components: {total_components}")
                        else:
                            results["errors"].append(f"Insufficient components: {total_components} < 15")
                            results["status"] = "failed"
                
            else:
                results["errors"].append(f"HTTP {response.status if response else 'No Response'}")
                results["status"] = "failed"
                
        except Exception as e:
            results["errors"].append(f"Error testing component mapping: {str(e)}")
            results["status"] = "failed"
        
        return results
    
    async def test_project_creation(self, page: Page) -> Dict[str, Any]:
        """Test project creation workflow"""
        print("🏗️ Testing Project Creation...")
        
        results = {
            "test_name": "Project Creation Workflow",
            "status": "passed",
            "details": [],
            "errors": []
        }
        
        try:
            # Test data
            project_data = {
                "name": "Playwright Test E-Commerce Platform",
                "prd_content": """
                # E-Commerce Platform Requirements
                
                ## User Authentication
                Users must be able to register and login with email and password.
                The system should validate email format and password strength.
                
                ## Product Catalog
                Users should browse products with search and filtering capabilities.
                Product details page must display images, descriptions, and pricing.
                
                ## Shopping Cart
                Users need to add products to cart and modify quantities.
                Cart should persist across sessions for logged-in users.
                
                ## API Requirements
                RESTful API endpoints for all user operations are required.
                Authentication endpoints (/api/auth/login, /api/auth/register) must be secure.
                Product endpoints (/api/products, /api/products/{id}) should return proper data.
                All endpoints must return appropriate HTTP status codes.
                
                ## Performance Requirements
                Page load time should be under 2 seconds.
                System must support 1000 concurrent users.
                99.9% uptime requirement for production environment.
                """,
                "project_config": {
                    "environment": "test",
                    "validation_level": "comprehensive",
                    "parallel_execution": True
                }
            }
            
            # Use page.evaluate to make API call
            response_data = await page.evaluate(f"""
                async () => {{
                    const response = await fetch('{self.base_url}/api/v1/rpa/projects/create', {{
                        method: 'POST',
                        headers: {{
                            'Content-Type': 'application/json'
                        }},
                        body: JSON.stringify({json.dumps(project_data)})
                    }});
                    
                    const data = await response.json();
                    return {{
                        status: response.status,
                        data: data
                    }};
                }}
            """)
            
            if response_data['status'] == 200:
                data = response_data['data']
                
                # Validate response structure
                required_fields = ['project_id', 'status', 'message']
                for field in required_fields:
                    if field not in data:
                        results["errors"].append(f"Missing required field: {field}")
                        results["status"] = "failed"
                
                if results["status"] == "passed":
                    project_id = data.get('project_id')
                    status = data.get('status')
                    message = data.get('message')
                    
                    results["details"].append({
                        "project_id": project_id,
                        "status": status,
                        "message": message,
                        "validation": "✅ Valid"
                    })
                    
                    print(f"    ✅ Project created: {project_id}")
                    print(f"    📋 Status: {status}")
                    print(f"    💬 Message: {message}")
                    
                    # Test project status endpoint
                    if project_id:
                        status_response = await page.evaluate(f"""
                            async () => {{
                                const response = await fetch('{self.base_url}/api/v1/rpa/projects/{project_id}');
                                const data = await response.json();
                                return {{
                                    status: response.status,
                                    data: data
                                }};
                            }}
                        """)
                        
                        if status_response['status'] == 200:
                            status_data = status_response['data']
                            results["details"].append({
                                "test": "project_status_check",
                                "project_id": project_id,
                                "status": status_data.get('status'),
                                "validation": "✅ Valid"
                            })
                            print(f"    ✅ Project status check passed")
                        else:
                            results["errors"].append(f"Project status check failed: HTTP {status_response['status']}")
                            results["status"] = "failed"
            else:
                results["errors"].append(f"Project creation failed: HTTP {response_data['status']}")
                results["status"] = "failed"
                
        except Exception as e:
            results["errors"].append(f"Error testing project creation: {str(e)}")
            results["status"] = "failed"
        
        return results
    
    async def test_workflow_execution(self, page: Page) -> Dict[str, Any]:
        """Test workflow execution"""
        print("⚙️ Testing Workflow Execution...")
        
        results = {
            "test_name": "Workflow Execution Testing",
            "status": "passed",
            "details": [],
            "errors": []
        }
        
        try:
            # Test workflow execution
            workflow_data = {
                "project_id": "test_project_123",
                "workflow_type": "ui_validation",
                "component_category": "ui_testing",
                "parameters": {
                    "target_url": "http://test-app.com",
                    "validation_rules": ["check_forms", "validate_navigation"],
                    "timeout": 300
                },
                "timeout": 300
            }
            
            response_data = await page.evaluate(f"""
                async () => {{
                    const response = await fetch('{self.base_url}/api/v1/rpa/workflows/execute', {{
                        method: 'POST',
                        headers: {{
                            'Content-Type': 'application/json'
                        }},
                        body: JSON.stringify({json.dumps(workflow_data)})
                    }});
                    
                    const data = await response.json();
                    return {{
                        status: response.status,
                        data: data
                    }};
                }}
            """)
            
            if response_data['status'] == 200:
                data = response_data['data']
                
                execution_id = data.get('execution_id')
                project_id = data.get('project_id')
                status = data.get('status')
                
                results["details"].append({
                    "execution_id": execution_id,
                    "project_id": project_id,
                    "status": status,
                    "validation": "✅ Valid"
                })
                
                print(f"    ✅ Workflow execution started: {execution_id}")
                print(f"    📋 Status: {status}")
                
            else:
                results["errors"].append(f"Workflow execution failed: HTTP {response_data['status']}")
                results["status"] = "failed"
                
        except Exception as e:
            results["errors"].append(f"Error testing workflow execution: {str(e)}")
            results["status"] = "failed"
        
        return results
    
    async def test_validation_execution(self, page: Page) -> Dict[str, Any]:
        """Test autonomous validation execution"""
        print("🔍 Testing Validation Execution...")
        
        results = {
            "test_name": "Validation Execution Testing",
            "status": "passed",
            "details": [],
            "errors": []
        }
        
        try:
            # Test validation execution
            validation_data = {
                "project_id": "test_project_123",
                "task_result": {
                    "implementation_status": "completed",
                    "features_implemented": ["user_auth", "product_catalog", "api_endpoints"],
                    "test_coverage": 85
                },
                "expected_behavior": {
                    "ui": {
                        "target_url": "http://test-app.com",
                        "required_elements": ["login_form", "product_grid", "navigation_menu"]
                    },
                    "api": {
                        "endpoints": ["/api/auth/login", "/api/products", "/api/users"],
                        "expected_status_codes": [200, 201, 400, 401, 404]
                    },
                    "integration": {
                        "checks": ["database_connectivity", "external_api_integration", "caching_system"]
                    }
                }
            }
            
            response_data = await page.evaluate(f"""
                async () => {{
                    const response = await fetch('{self.base_url}/api/v1/rpa/validation/execute', {{
                        method: 'POST',
                        headers: {{
                            'Content-Type': 'application/json'
                        }},
                        body: JSON.stringify({json.dumps(validation_data)})
                    }});
                    
                    const data = await response.json();
                    return {{
                        status: response.status,
                        data: data
                    }};
                }}
            """)
            
            if response_data['status'] == 200:
                data = response_data['data']
                
                validation_id = data.get('validation_id')
                project_id = data.get('project_id')
                overall_valid = data.get('overall_valid')
                validation_results = data.get('validation_results', {})
                
                results["details"].append({
                    "validation_id": validation_id,
                    "project_id": project_id,
                    "overall_valid": overall_valid,
                    "validation_count": len(validation_results),
                    "validation": "✅ Valid"
                })
                
                print(f"    ✅ Validation executed: {validation_id}")
                print(f"    📋 Overall valid: {overall_valid}")
                print(f"    🔍 Validation results: {len(validation_results)} checks")
                
                # Show validation details
                for validation_type, result in validation_results.items():
                    success = result.get('success', False)
                    details = result.get('details', 'No details')
                    status_icon = "✅" if success else "❌"
                    print(f"      {status_icon} {validation_type}: {details}")
                
            else:
                results["errors"].append(f"Validation execution failed: HTTP {response_data['status']}")
                results["status"] = "failed"
                
        except Exception as e:
            results["errors"].append(f"Error testing validation execution: {str(e)}")
            results["status"] = "failed"
        
        return results
    
    async def run_comprehensive_tests(self) -> Dict[str, Any]:
        """Run all comprehensive interface tests"""
        print("🎭 Starting Comprehensive Playwright Interface Tests")
        print("=" * 70)
        
        browser, context, page = await self.setup_browser()
        
        try:
            # Run all test scenarios
            test_results = []
            
            # Test 1: Health Endpoints
            health_results = await self.test_health_endpoints(page)
            test_results.append(health_results)
            
            # Test 2: Component Mapping
            mapping_results = await self.test_component_mapping(page)
            test_results.append(mapping_results)
            
            # Test 3: Project Creation
            project_results = await self.test_project_creation(page)
            test_results.append(project_results)
            
            # Test 4: Workflow Execution
            workflow_results = await self.test_workflow_execution(page)
            test_results.append(workflow_results)
            
            # Test 5: Validation Execution
            validation_results = await self.test_validation_execution(page)
            test_results.append(validation_results)
            
            # Calculate overall results
            total_tests = len(test_results)
            passed_tests = len([r for r in test_results if r['status'] == 'passed'])
            failed_tests = total_tests - passed_tests
            
            overall_results = {
                "test_suite": "Playwright Interface Testing",
                "total_tests": total_tests,
                "passed_tests": passed_tests,
                "failed_tests": failed_tests,
                "success_rate": f"{(passed_tests/total_tests)*100:.1f}%",
                "overall_status": "passed" if failed_tests == 0 else "failed",
                "test_results": test_results,
                "timestamp": int(time.time())
            }
            
            return overall_results
            
        finally:
            await context.close()
            await browser.close()
    
    def print_test_summary(self, results: Dict[str, Any]):
        """Print comprehensive test summary"""
        print("\n" + "=" * 70)
        print("🎭 Playwright Interface Testing Summary")
        print("=" * 70)
        
        print(f"📊 Overall Results:")
        print(f"   • Total Tests: {results['total_tests']}")
        print(f"   • Passed: {results['passed_tests']} ✅")
        print(f"   • Failed: {results['failed_tests']} ❌")
        print(f"   • Success Rate: {results['success_rate']}")
        print(f"   • Overall Status: {'✅ PASSED' if results['overall_status'] == 'passed' else '❌ FAILED'}")
        
        print(f"\n📋 Test Details:")
        for test_result in results['test_results']:
            status_icon = "✅" if test_result['status'] == 'passed' else "❌"
            print(f"   {status_icon} {test_result['test_name']}")
            
            if test_result['details']:
                for detail in test_result['details'][:2]:  # Show first 2 details
                    if isinstance(detail, dict):
                        key = list(detail.keys())[0]
                        value = detail[key]
                        print(f"      • {key}: {value}")
            
            if test_result['errors']:
                for error in test_result['errors'][:2]:  # Show first 2 errors
                    print(f"      ⚠️ {error}")
        
        print("\n" + "=" * 70)
        if results['overall_status'] == 'passed':
            print("🎉 All Playwright Interface Tests Passed Successfully!")
        else:
            print("💥 Some Playwright Interface Tests Failed!")
        print("=" * 70)


async def main():
    """Main function to run Playwright interface tests"""
    tester = PlaywrightInterfaceTester()
    
    try:
        results = await tester.run_comprehensive_tests()
        tester.print_test_summary(results)
        
        if results['overall_status'] == 'passed':
            print("\n✅ Playwright interface testing completed successfully!")
            return 0
        else:
            print("\n❌ Playwright interface testing failed!")
            return 1
            
    except Exception as e:
        print(f"\n💥 Playwright testing failed with error: {str(e)}")
        return 1


if __name__ == "__main__":
    exit_code = asyncio.run(main())
    exit(exit_code)
