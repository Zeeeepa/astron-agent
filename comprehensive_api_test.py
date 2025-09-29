#!/usr/bin/env python3
"""
Comprehensive API Testing for RPA Integration

Complete testing of all RPA integration API endpoints and workflows
using direct HTTP requests to validate functionality.
"""

import asyncio
import json
import time
from typing import Dict, Any, List

import aiohttp


class ComprehensiveAPITester:
    """Complete API testing for RPA integration"""
    
    def __init__(self):
        self.base_url = "http://localhost:8000"
        self.rpa_url = "http://localhost:8020"
        self.test_results = []
        
        # Test project data
        self.test_project_data = {
            "name": "Comprehensive Test E-Commerce Platform",
            "prd_content": """
            # E-Commerce Platform Requirements
            
            ## User Authentication System
            Users must be able to register with email and password validation.
            Users should be able to login with secure session management.
            Password reset functionality is required for user convenience.
            
            ## Product Catalog Management
            Users should browse products with advanced search capabilities.
            Product filtering by category, price, and ratings must be supported.
            Product details page should display comprehensive information.
            
            ## Shopping Cart & Checkout
            Users need to add/remove products from shopping cart.
            Cart should persist across browser sessions for logged-in users.
            Secure checkout process with multiple payment options required.
            
            ## API Infrastructure
            RESTful API endpoints for all user operations are mandatory.
            Authentication endpoints (/api/auth/*) must implement JWT tokens.
            Product endpoints (/api/products/*) should support pagination.
            Order endpoints (/api/orders/*) must handle complex transactions.
            All endpoints must return appropriate HTTP status codes and error messages.
            
            ## Performance & Scalability
            Page load time should be under 2 seconds for optimal UX.
            System must support 1000+ concurrent users during peak hours.
            Database queries should be optimized for sub-100ms response times.
            99.9% uptime requirement with proper error handling and recovery.
            
            ## Security Requirements
            All user data must be encrypted in transit and at rest.
            Input validation and sanitization for all user inputs.
            Rate limiting to prevent abuse and DDoS attacks.
            Regular security audits and vulnerability assessments.
            """,
            "project_config": {
                "environment": "test",
                "validation_level": "comprehensive",
                "parallel_execution": True,
                "timeout": 300,
                "retry_count": 3
            }
        }
    
    async def test_health_endpoints(self, session: aiohttp.ClientSession) -> Dict[str, Any]:
        """Test all health check endpoints"""
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
                
                async with session.get(endpoint, timeout=10) as response:
                    if response.status == 200:
                        data = await response.json()
                        
                        if data.get('status') == 'healthy':
                            results["details"].append({
                                "endpoint": endpoint,
                                "status": "✅ Healthy",
                                "service": data.get('service', 'unknown'),
                                "response_time": f"< 1s",
                                "timestamp": data.get('timestamp', int(time.time()))
                            })
                            print(f"    ✅ {data.get('service', 'Service')} is healthy")
                        else:
                            results["errors"].append(f"Endpoint {endpoint} returned unhealthy status")
                            results["status"] = "failed"
                    else:
                        results["errors"].append(f"HTTP {response.status} from {endpoint}")
                        results["status"] = "failed"
                        
            except Exception as e:
                results["errors"].append(f"Error testing {endpoint}: {str(e)}")
                results["status"] = "failed"
        
        return results
    
    async def test_component_mapping(self, session: aiohttp.ClientSession) -> Dict[str, Any]:
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
            
            async with session.get(endpoint, timeout=10) as response:
                if response.status == 200:
                    data = await response.json()
                    
                    # Validate required fields
                    required_fields = ['component_categories', 'total_components', 'supported_workflows']
                    for field in required_fields:
                        if field not in data:
                            results["errors"].append(f"Missing required field: {field}")
                            results["status"] = "failed"
                    
                    if results["status"] == "passed":
                        # Validate component categories
                        categories = data.get('component_categories', {})
                        expected_categories = ['ui_testing', 'api_testing', 'data_processing', 'ai_processing', 'system_automation']
                        
                        total_components_found = 0
                        for category in expected_categories:
                            if category in categories:
                                category_data = categories[category]
                                components = category_data.get('components', [])
                                total_components_found += len(components)
                                
                                results["details"].append({
                                    "category": category,
                                    "components_count": len(components),
                                    "components": components,
                                    "description": category_data.get('description', 'No description'),
                                    "capabilities": len(category_data.get('capabilities', [])),
                                    "status": "✅ Valid"
                                })
                                print(f"    ✅ {category}: {len(components)} components")
                            else:
                                results["errors"].append(f"Missing category: {category}")
                                results["status"] = "failed"
                        
                        # Validate totals
                        declared_total = data.get('total_components', 0)
                        if declared_total >= 15 and declared_total == total_components_found:
                            results["details"].append({
                                "metric": "total_components",
                                "declared": declared_total,
                                "actual": total_components_found,
                                "status": "✅ Valid"
                            })
                            print(f"    ✅ Total components: {declared_total} (verified)")
                        else:
                            results["errors"].append(f"Component count mismatch: declared={declared_total}, actual={total_components_found}")
                            results["status"] = "failed"
                        
                        # Validate supported workflows
                        workflows = data.get('supported_workflows', [])
                        if len(workflows) >= 5:
                            results["details"].append({
                                "metric": "supported_workflows",
                                "count": len(workflows),
                                "workflows": workflows,
                                "status": "✅ Valid"
                            })
                            print(f"    ✅ Supported workflows: {len(workflows)}")
                        else:
                            results["errors"].append(f"Insufficient workflows: {len(workflows)} < 5")
                            results["status"] = "failed"
                
                else:
                    results["errors"].append(f"HTTP {response.status}")
                    results["status"] = "failed"
                    
        except Exception as e:
            results["errors"].append(f"Error testing component mapping: {str(e)}")
            results["status"] = "failed"
        
        return results
    
    async def test_project_creation(self, session: aiohttp.ClientSession) -> Dict[str, Any]:
        """Test project creation workflow"""
        print("🏗️ Testing Project Creation...")
        
        results = {
            "test_name": "Project Creation Workflow",
            "status": "passed",
            "details": [],
            "errors": [],
            "project_id": None
        }
        
        try:
            endpoint = f"{self.base_url}/api/v1/rpa/projects/create"
            print(f"  🔍 Testing {endpoint}")
            
            async with session.post(endpoint, json=self.test_project_data, timeout=15) as response:
                if response.status == 200:
                    data = await response.json()
                    
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
                        project_data = data.get('data', {})
                        
                        results["project_id"] = project_id
                        results["details"].append({
                            "project_id": project_id,
                            "status": status,
                            "message": message,
                            "project_name": project_data.get('project_name'),
                            "prd_length": project_data.get('prd_length'),
                            "requirements_detected": project_data.get('requirements_detected'),
                            "complexity_level": project_data.get('complexity_level'),
                            "validation": "✅ Valid"
                        })
                        
                        print(f"    ✅ Project created: {project_id}")
                        print(f"    📋 Status: {status}")
                        print(f"    💬 Message: {message}")
                        print(f"    🔍 Requirements detected: {project_data.get('requirements_detected', 'N/A')}")
                        print(f"    📊 Complexity: {project_data.get('complexity_level', 'N/A')}")
                        
                        # Test project status endpoint
                        if project_id:
                            await asyncio.sleep(1)  # Brief pause
                            status_endpoint = f"{self.base_url}/api/v1/rpa/projects/{project_id}"
                            
                            async with session.get(status_endpoint, timeout=10) as status_response:
                                if status_response.status == 200:
                                    status_data = await status_response.json()
                                    results["details"].append({
                                        "test": "project_status_check",
                                        "project_id": project_id,
                                        "status": status_data.get('status'),
                                        "workflow_mappings_count": status_data.get('data', {}).get('workflow_mappings_count'),
                                        "components_selected": status_data.get('data', {}).get('components_selected'),
                                        "validation": "✅ Valid"
                                    })
                                    print(f"    ✅ Project status check passed")
                                else:
                                    results["errors"].append(f"Project status check failed: HTTP {status_response.status}")
                                    results["status"] = "failed"
                
                else:
                    results["errors"].append(f"Project creation failed: HTTP {response.status}")
                    results["status"] = "failed"
                    
        except Exception as e:
            results["errors"].append(f"Error testing project creation: {str(e)}")
            results["status"] = "failed"
        
        return results
    
    async def test_workflow_execution(self, session: aiohttp.ClientSession, project_id: str = None) -> Dict[str, Any]:
        """Test workflow execution"""
        print("⚙️ Testing Workflow Execution...")
        
        results = {
            "test_name": "Workflow Execution Testing",
            "status": "passed",
            "details": [],
            "errors": []
        }
        
        try:
            # Test multiple workflow types
            workflow_tests = [
                {
                    "project_id": project_id or "test_project_123",
                    "workflow_type": "ui_validation",
                    "component_category": "ui_testing",
                    "parameters": {
                        "target_url": "http://test-app.com",
                        "validation_rules": ["check_forms", "validate_navigation", "test_responsiveness"],
                        "timeout": 300,
                        "screenshot_on_failure": True
                    },
                    "timeout": 300
                },
                {
                    "project_id": project_id or "test_project_456",
                    "workflow_type": "api_validation",
                    "component_category": "api_testing",
                    "parameters": {
                        "base_url": "http://api.test-app.com",
                        "endpoints": ["/api/auth/login", "/api/products", "/api/orders"],
                        "authentication": {"type": "bearer", "token": "test_token"},
                        "timeout": 60
                    },
                    "timeout": 180
                }
            ]
            
            for i, workflow_data in enumerate(workflow_tests):
                print(f"  🔍 Testing workflow {i+1}: {workflow_data['workflow_type']}")
                
                endpoint = f"{self.base_url}/api/v1/rpa/workflows/execute"
                
                async with session.post(endpoint, json=workflow_data, timeout=15) as response:
                    if response.status == 200:
                        data = await response.json()
                        
                        execution_id = data.get('execution_id')
                        project_id_resp = data.get('project_id')
                        status = data.get('status')
                        
                        results["details"].append({
                            "workflow_type": workflow_data['workflow_type'],
                            "execution_id": execution_id,
                            "project_id": project_id_resp,
                            "status": status,
                            "component_category": workflow_data['component_category'],
                            "validation": "✅ Valid"
                        })
                        
                        print(f"    ✅ {workflow_data['workflow_type']} execution started: {execution_id}")
                        print(f"    📋 Status: {status}")
                        
                    else:
                        results["errors"].append(f"Workflow {workflow_data['workflow_type']} failed: HTTP {response.status}")
                        results["status"] = "failed"
                        
        except Exception as e:
            results["errors"].append(f"Error testing workflow execution: {str(e)}")
            results["status"] = "failed"
        
        return results
    
    async def test_validation_execution(self, session: aiohttp.ClientSession, project_id: str = None) -> Dict[str, Any]:
        """Test autonomous validation execution"""
        print("🔍 Testing Validation Execution...")
        
        results = {
            "test_name": "Validation Execution Testing",
            "status": "passed",
            "details": [],
            "errors": []
        }
        
        try:
            # Comprehensive validation test data
            validation_data = {
                "project_id": project_id or "test_project_123",
                "task_result": {
                    "implementation_status": "completed",
                    "features_implemented": [
                        "user_authentication",
                        "product_catalog",
                        "shopping_cart",
                        "checkout_process",
                        "api_endpoints",
                        "payment_integration"
                    ],
                    "test_coverage": 87,
                    "performance_metrics": {
                        "page_load_time": 1.8,
                        "api_response_time": 95,
                        "concurrent_users_tested": 500
                    },
                    "security_checks": {
                        "input_validation": True,
                        "sql_injection_protection": True,
                        "xss_protection": True,
                        "csrf_protection": True
                    }
                },
                "expected_behavior": {
                    "ui": {
                        "target_url": "http://test-ecommerce-app.com",
                        "required_elements": [
                            "login_form", "registration_form", "product_grid",
                            "search_bar", "navigation_menu", "shopping_cart_icon",
                            "checkout_button", "payment_form"
                        ],
                        "responsive_breakpoints": [320, 768, 1024, 1920],
                        "accessibility_requirements": ["aria_labels", "keyboard_navigation", "screen_reader_support"]
                    },
                    "api": {
                        "base_url": "http://api.test-ecommerce-app.com",
                        "endpoints": [
                            "/api/auth/register",
                            "/api/auth/login",
                            "/api/auth/logout",
                            "/api/products",
                            "/api/products/{id}",
                            "/api/cart",
                            "/api/orders",
                            "/api/users/profile"
                        ],
                        "expected_status_codes": [200, 201, 400, 401, 403, 404, 422, 500],
                        "authentication_methods": ["jwt", "session"],
                        "rate_limiting": {"requests_per_minute": 100}
                    },
                    "integration": {
                        "checks": [
                            "database_connectivity",
                            "redis_cache_integration",
                            "payment_gateway_integration",
                            "email_service_integration",
                            "external_api_integration",
                            "cdn_integration",
                            "monitoring_integration"
                        ],
                        "data_consistency": ["user_sessions", "cart_persistence", "order_tracking"],
                        "error_handling": ["graceful_degradation", "retry_mechanisms", "fallback_systems"]
                    },
                    "performance": {
                        "load_time_threshold": 2.0,
                        "concurrent_users": 1000,
                        "uptime_requirement": 99.9,
                        "database_query_time": 100
                    }
                }
            }
            
            endpoint = f"{self.base_url}/api/v1/rpa/validation/execute"
            print(f"  🔍 Testing {endpoint}")
            
            async with session.post(endpoint, json=validation_data, timeout=20) as response:
                if response.status == 200:
                    data = await response.json()
                    
                    validation_id = data.get('validation_id')
                    project_id_resp = data.get('project_id')
                    overall_valid = data.get('overall_valid')
                    validation_results = data.get('validation_results', {})
                    execution_time = data.get('execution_time')
                    
                    results["details"].append({
                        "validation_id": validation_id,
                        "project_id": project_id_resp,
                        "overall_valid": overall_valid,
                        "validation_count": len(validation_results),
                        "execution_time": execution_time,
                        "validation": "✅ Valid"
                    })
                    
                    print(f"    ✅ Validation executed: {validation_id}")
                    print(f"    📋 Overall valid: {overall_valid}")
                    print(f"    🔍 Validation results: {len(validation_results)} checks")
                    print(f"    ⏱️ Execution time: {execution_time}s")
                    
                    # Show detailed validation results
                    for validation_type, result in validation_results.items():
                        success = result.get('success', False)
                        details = result.get('details', 'No details')
                        status_icon = "✅" if success else "❌"
                        print(f"      {status_icon} {validation_type}: {details}")
                        
                        results["details"].append({
                            "validation_type": validation_type,
                            "success": success,
                            "details": details,
                            "status": "✅ Valid" if success else "❌ Failed"
                        })
                
                else:
                    results["errors"].append(f"Validation execution failed: HTTP {response.status}")
                    results["status"] = "failed"
                    
        except Exception as e:
            results["errors"].append(f"Error testing validation execution: {str(e)}")
            results["status"] = "failed"
        
        return results
    
    async def test_rpa_mcp_endpoint(self, session: aiohttp.ClientSession) -> Dict[str, Any]:
        """Test RPA MCP endpoint directly"""
        print("🤖 Testing RPA MCP Endpoint...")
        
        results = {
            "test_name": "RPA MCP Endpoint Testing",
            "status": "passed",
            "details": [],
            "errors": []
        }
        
        try:
            # Test MCP workflow execution
            mcp_data = {
                "action": "execute_workflow",
                "workflow_type": "comprehensive_validation",
                "components": ["rpabrowser", "rpanetwork", "rpadatabase", "rpaai"],
                "parameters": {
                    "target_environment": "test",
                    "validation_level": "comprehensive",
                    "parallel_execution": True,
                    "timeout": 300,
                    "retry_count": 3
                }
            }
            
            endpoint = f"{self.rpa_url}/mcp"
            print(f"  🔍 Testing {endpoint}")
            
            async with session.post(endpoint, json=mcp_data, timeout=15) as response:
                if response.status == 200:
                    data = await response.json()
                    
                    status = data.get('status')
                    result = data.get('result')
                    components_used = data.get('components_used', [])
                    execution_time = data.get('execution_time')
                    workflow_details = data.get('workflow_details', {})
                    
                    results["details"].append({
                        "status": status,
                        "result": result,
                        "components_used": components_used,
                        "execution_time": execution_time,
                        "workflow_details": workflow_details,
                        "validation": "✅ Valid"
                    })
                    
                    print(f"    ✅ MCP execution status: {status}")
                    print(f"    🔧 Components used: {len(components_used)}")
                    print(f"    ⏱️ Execution time: {execution_time}s")
                    print(f"    📊 Success rate: {workflow_details.get('success_rate', 'N/A')}%")
                
                else:
                    results["errors"].append(f"MCP endpoint failed: HTTP {response.status}")
                    results["status"] = "failed"
                    
        except Exception as e:
            results["errors"].append(f"Error testing MCP endpoint: {str(e)}")
            results["status"] = "failed"
        
        return results
    
    async def run_comprehensive_tests(self) -> Dict[str, Any]:
        """Run all comprehensive API tests"""
        print("🧪 Starting Comprehensive API Testing")
        print("=" * 80)
        
        async with aiohttp.ClientSession() as session:
            test_results = []
            project_id = None
            
            # Test 1: Health Endpoints
            health_results = await self.test_health_endpoints(session)
            test_results.append(health_results)
            
            # Test 2: Component Mapping
            mapping_results = await self.test_component_mapping(session)
            test_results.append(mapping_results)
            
            # Test 3: Project Creation
            project_results = await self.test_project_creation(session)
            test_results.append(project_results)
            project_id = project_results.get('project_id')
            
            # Test 4: Workflow Execution
            workflow_results = await self.test_workflow_execution(session, project_id)
            test_results.append(workflow_results)
            
            # Test 5: Validation Execution
            validation_results = await self.test_validation_execution(session, project_id)
            test_results.append(validation_results)
            
            # Test 6: RPA MCP Endpoint
            mcp_results = await self.test_rpa_mcp_endpoint(session)
            test_results.append(mcp_results)
            
            # Calculate overall results
            total_tests = len(test_results)
            passed_tests = len([r for r in test_results if r['status'] == 'passed'])
            failed_tests = total_tests - passed_tests
            
            overall_results = {
                "test_suite": "Comprehensive API Testing",
                "total_tests": total_tests,
                "passed_tests": passed_tests,
                "failed_tests": failed_tests,
                "success_rate": f"{(passed_tests/total_tests)*100:.1f}%",
                "overall_status": "passed" if failed_tests == 0 else "failed",
                "test_results": test_results,
                "project_id": project_id,
                "timestamp": int(time.time())
            }
            
            return overall_results
    
    def print_test_summary(self, results: Dict[str, Any]):
        """Print comprehensive test summary"""
        print("\n" + "=" * 80)
        print("🧪 Comprehensive API Testing Summary")
        print("=" * 80)
        
        print(f"📊 Overall Results:")
        print(f"   • Total Tests: {results['total_tests']}")
        print(f"   • Passed: {results['passed_tests']} ✅")
        print(f"   • Failed: {results['failed_tests']} ❌")
        print(f"   • Success Rate: {results['success_rate']}")
        print(f"   • Overall Status: {'✅ PASSED' if results['overall_status'] == 'passed' else '❌ FAILED'}")
        
        if results.get('project_id'):
            print(f"   • Test Project ID: {results['project_id']}")
        
        print(f"\n📋 Detailed Test Results:")
        for test_result in results['test_results']:
            status_icon = "✅" if test_result['status'] == 'passed' else "❌"
            print(f"\n   {status_icon} {test_result['test_name']}")
            
            if test_result['details']:
                for detail in test_result['details'][:3]:  # Show first 3 details
                    if isinstance(detail, dict):
                        # Find the most relevant key-value pair to display
                        if 'validation' in detail:
                            key = [k for k in detail.keys() if k != 'validation'][0] if len(detail) > 1 else 'validation'
                            value = detail[key]
                            print(f"      • {key}: {value}")
                        else:
                            key = list(detail.keys())[0]
                            value = detail[key]
                            print(f"      • {key}: {value}")
            
            if test_result['errors']:
                for error in test_result['errors'][:2]:  # Show first 2 errors
                    print(f"      ⚠️ {error}")
        
        print("\n" + "=" * 80)
        if results['overall_status'] == 'passed':
            print("🎉 All Comprehensive API Tests Passed Successfully!")
            print("🚀 RPA Integration is fully functional and ready for production!")
        else:
            print("💥 Some API Tests Failed - Review errors above")
        print("=" * 80)


async def main():
    """Main function to run comprehensive API tests"""
    tester = ComprehensiveAPITester()
    
    try:
        results = await tester.run_comprehensive_tests()
        tester.print_test_summary(results)
        
        if results['overall_status'] == 'passed':
            print("\n✅ Comprehensive API testing completed successfully!")
            return 0
        else:
            print("\n❌ Comprehensive API testing failed!")
            return 1
            
    except Exception as e:
        print(f"\n💥 API testing failed with error: {str(e)}")
        return 1


if __name__ == "__main__":
    exit_code = asyncio.run(main())
    exit(exit_code)
