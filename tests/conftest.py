"""
Test configuration and fixtures for Astron-Agent tests
"""

import os
import pytest
import asyncio
from typing import Dict, Any
from dataclasses import dataclass


@dataclass
class TestConfig:
    """Test configuration"""
    agent_url: str = "http://localhost:8000"
    rpa_openapi_url: str = "http://localhost:8020"
    rpa_engine_url: str = "http://localhost:8021"
    mysql_url: str = "mysql://root:root123@localhost:3306/astron_test"
    redis_url: str = "redis://localhost:6379"
    test_timeout: int = 300
    
    def __post_init__(self):
        # Override with environment variables if available
        self.agent_url = os.getenv("TEST_AGENT_URL", self.agent_url)
        self.rpa_openapi_url = os.getenv("TEST_RPA_OPENAPI_URL", self.rpa_openapi_url)
        self.rpa_engine_url = os.getenv("TEST_RPA_ENGINE_URL", self.rpa_engine_url)
        self.mysql_url = os.getenv("TEST_MYSQL_URL", self.mysql_url)
        self.redis_url = os.getenv("TEST_REDIS_URL", self.redis_url)
        self.test_timeout = int(os.getenv("TEST_TIMEOUT", str(self.test_timeout)))


@pytest.fixture(scope="session")
def event_loop():
    """Create an instance of the default event loop for the test session."""
    loop = asyncio.get_event_loop_policy().new_event_loop()
    yield loop
    loop.close()


@pytest.fixture(scope="session")
def test_config():
    """Test configuration fixture"""
    return TestConfig()


@pytest.fixture
def sample_prd_content():
    """Sample PRD content for testing"""
    return """
    # Sample E-commerce Platform PRD
    
    ## Overview
    Build a modern e-commerce platform with comprehensive features.
    
    ## Core Features
    1. User Management
       - User registration and authentication
       - Profile management
       - Role-based access control
    
    2. Product Management
       - Product catalog with categories
       - Search and filtering capabilities
       - Inventory management
       - Product reviews and ratings
    
    3. Shopping Experience
       - Shopping cart functionality
       - Wishlist management
       - Checkout process
       - Multiple payment methods
    
    4. Order Management
       - Order processing workflow
       - Order tracking
       - Return and refund handling
       - Email notifications
    
    5. Admin Dashboard
       - Sales analytics
       - User management
       - Product management
       - Order management
    
    ## Technical Requirements
    - Frontend: React.js with TypeScript
    - Backend: Node.js with Express
    - Database: PostgreSQL
    - Cache: Redis
    - Authentication: JWT
    - Payment: Stripe integration
    - Deployment: Docker containers
    - Monitoring: Prometheus + Grafana
    
    ## Performance Requirements
    - Page load time: < 2 seconds
    - API response time: < 500ms
    - Concurrent users: 1000+
    - Uptime: 99.9%
    
    ## Security Requirements
    - HTTPS encryption
    - Input validation and sanitization
    - SQL injection prevention
    - XSS protection
    - CSRF protection
    - Rate limiting
    
    ## Validation Requirements
    - All user flows must be tested
    - Payment processing must be validated
    - Performance benchmarks must be met
    - Security vulnerabilities must be addressed
    - Cross-browser compatibility
    - Mobile responsiveness
    """


@pytest.fixture
def sample_project_config():
    """Sample project configuration for testing"""
    return {
        "technology_stack": ["React", "Node.js", "PostgreSQL", "Redis"],
        "deployment_target": "Docker",
        "validation_level": "comprehensive",
        "performance_requirements": {
            "page_load_time_ms": 2000,
            "api_response_time_ms": 500,
            "concurrent_users": 1000,
            "uptime_percentage": 99.9
        },
        "security_requirements": {
            "https_required": True,
            "input_validation": True,
            "sql_injection_protection": True,
            "xss_protection": True,
            "csrf_protection": True,
            "rate_limiting": True
        }
    }


@pytest.fixture
def sample_workflow_parameters():
    """Sample workflow parameters for testing"""
    return {
        "ui_testing": {
            "target_url": "http://localhost:3000",
            "test_scenarios": [
                "user_registration",
                "user_login",
                "product_search",
                "add_to_cart",
                "checkout_process",
                "order_tracking"
            ],
            "browser": "chromium",
            "headless": True,
            "viewport": {"width": 1920, "height": 1080},
            "timeout": 30000
        },
        "api_testing": {
            "base_url": "http://localhost:8000/api",
            "test_endpoints": [
                {"method": "POST", "path": "/auth/register", "test_type": "functionality"},
                {"method": "POST", "path": "/auth/login", "test_type": "functionality"},
                {"method": "GET", "path": "/products", "test_type": "performance"},
                {"method": "GET", "path": "/products/{id}", "test_type": "functionality"},
                {"method": "POST", "path": "/cart/add", "test_type": "functionality"},
                {"method": "GET", "path": "/cart", "test_type": "functionality"},
                {"method": "POST", "path": "/orders/create", "test_type": "functionality"},
                {"method": "GET", "path": "/orders/{id}", "test_type": "functionality"}
            ],
            "performance_thresholds": {
                "response_time_ms": 500,
                "throughput_rps": 100,
                "error_rate_percentage": 1.0
            },
            "authentication": {
                "type": "bearer_token",
                "token_endpoint": "/auth/login"
            }
        },
        "data_processing": {
            "input_files": [
                {"type": "excel", "path": "/data/products.xlsx"},
                {"type": "csv", "path": "/data/users.csv"}
            ],
            "output_format": "json",
            "validation_rules": [
                {"field": "email", "type": "email"},
                {"field": "price", "type": "number", "min": 0}
            ]
        }
    }


@pytest.fixture
def sample_expected_behavior():
    """Sample expected behavior for validation testing"""
    return {
        "ui_flows": {
            "user_registration": {
                "success_rate": 0.95,
                "avg_time_ms": 3000,
                "max_time_ms": 5000
            },
            "user_login": {
                "success_rate": 0.98,
                "avg_time_ms": 1500,
                "max_time_ms": 3000
            },
            "product_search": {
                "success_rate": 0.99,
                "avg_time_ms": 1000,
                "max_time_ms": 2000
            },
            "add_to_cart": {
                "success_rate": 0.97,
                "avg_time_ms": 1500,
                "max_time_ms": 3000
            },
            "checkout_process": {
                "success_rate": 0.95,
                "avg_time_ms": 5000,
                "max_time_ms": 10000
            }
        },
        "api_endpoints": {
            "response_time_threshold_ms": 500,
            "success_rate_threshold": 0.95,
            "error_rate_threshold": 0.05,
            "throughput_threshold_rps": 100
        },
        "performance_metrics": {
            "page_load_time_ms": 2000,
            "first_contentful_paint_ms": 1000,
            "largest_contentful_paint_ms": 2500,
            "cumulative_layout_shift": 0.1
        },
        "security_requirements": {
            "https_enforced": True,
            "xss_protection": True,
            "csrf_protection": True,
            "sql_injection_protection": True,
            "input_validation": True
        },
        "overall_requirements": {
            "availability": 0.999,
            "performance_score": 0.85,
            "security_score": 0.90,
            "user_satisfaction": 0.80
        }
    }


# Test data cleanup fixtures
@pytest.fixture(autouse=True)
async def cleanup_test_data():
    """Cleanup test data after each test"""
    yield
    # Cleanup logic would go here
    # For now, we'll just pass as this would require database connections
    pass


# Mock fixtures for testing without actual services
@pytest.fixture
def mock_rpa_service():
    """Mock RPA service for testing without actual RPA service"""
    class MockRpaService:
        def __init__(self):
            self.projects = {}
            self.executions = {}
            self.validations = {}
        
        async def create_project(self, project_data):
            project_id = f"mock-project-{len(self.projects)}"
            self.projects[project_id] = {
                **project_data,
                "id": project_id,
                "status": "ready",
                "workflow_mappings": {
                    "ui_testing": {"components": ["rpabrowser", "rpacv"]},
                    "api_testing": {"components": ["rpanetwork", "rpaopenapi"]},
                    "data_processing": {"components": ["rpadatabase", "rpaexcel"]}
                }
            }
            return {"project_id": project_id, "status": "ready"}
        
        async def execute_workflow(self, workflow_request):
            execution_id = f"mock-execution-{len(self.executions)}"
            self.executions[execution_id] = {
                **workflow_request,
                "id": execution_id,
                "status": "completed",
                "result": {"success": True, "details": "Mock execution completed"}
            }
            return {"execution_id": execution_id, "status": "completed"}
        
        async def validate_results(self, validation_request):
            validation_id = f"mock-validation-{len(self.validations)}"
            self.validations[validation_id] = {
                **validation_request,
                "id": validation_id,
                "overall_valid": True,
                "validation_results": {
                    "ui_validation": {"success": True, "details": "All UI tests passed"},
                    "api_validation": {"success": True, "details": "All API tests passed"},
                    "performance_validation": {"success": True, "details": "Performance requirements met"},
                    "security_validation": {"success": True, "details": "Security requirements met"}
                }
            }
            return self.validations[validation_id]
    
    return MockRpaService()


# Pytest configuration
def pytest_configure(config):
    """Configure pytest"""
    config.addinivalue_line(
        "markers", "integration: mark test as integration test"
    )
    config.addinivalue_line(
        "markers", "unit: mark test as unit test"
    )
    config.addinivalue_line(
        "markers", "performance: mark test as performance test"
    )
    config.addinivalue_line(
        "markers", "slow: mark test as slow running"
    )
