#!/usr/bin/env python3
"""
Autonomous PRD Workflow Example

Demonstrates how to use the Astron-Agent + Astron-RPA integration
to create an autonomous CI/CD workflow from a PRD document.
"""

import asyncio
import json
import time
from typing import Dict, Any

import aiohttp
from pydantic import BaseModel


class AutonomousPRDWorkflow:
    """Example autonomous workflow using Astron-Agent + Astron-RPA integration"""
    
    def __init__(self, agent_url: str = "http://localhost:8000"):
        """
        Initialize the autonomous workflow
        
        Args:
            agent_url: Base URL for Astron-Agent API
        """
        self.agent_url = agent_url
        self.rpa_api_base = f"{agent_url}/api/v1/rpa"
        
    async def run_autonomous_workflow(self, prd_content: str, project_name: str) -> Dict[str, Any]:
        """
        Run complete autonomous workflow from PRD to validation
        
        Args:
            prd_content: Product Requirements Document content
            project_name: Name for the project
            
        Returns:
            Complete workflow results
        """
        print(f"🚀 Starting Autonomous PRD Workflow: {project_name}")
        
        workflow_results = {
            "project_name": project_name,
            "started_at": int(time.time()),
            "steps": {}
        }
        
        try:
            # Step 1: Create project and process PRD
            print("\n📋 Step 1: Creating project and processing PRD...")
            project_result = await self._create_project(prd_content, project_name)
            workflow_results["steps"]["create_project"] = project_result
            
            project_id = project_result["project_id"]
            print(f"✅ Project created: {project_id}")
            
            # Step 2: Wait for PRD processing to complete
            print("\n⏳ Step 2: Waiting for PRD processing...")
            await self._wait_for_prd_processing(project_id)
            print("✅ PRD processing completed")
            
            # Step 3: Get generated workflows
            print("\n🔧 Step 3: Retrieving generated workflows...")
            workflows = await self._get_project_workflows(project_id)
            workflow_results["steps"]["workflows"] = workflows
            print(f"✅ Retrieved {len(workflows.get('workflow_mappings', {}))} workflows")
            
            # Step 4: Execute UI validation workflow
            print("\n🖥️ Step 4: Executing UI validation...")
            ui_result = await self._execute_ui_validation(project_id)
            workflow_results["steps"]["ui_validation"] = ui_result
            print(f"✅ UI validation: {ui_result['status']}")
            
            # Step 5: Execute API validation workflow
            print("\n🔗 Step 5: Executing API validation...")
            api_result = await self._execute_api_validation(project_id)
            workflow_results["steps"]["api_validation"] = api_result
            print(f"✅ API validation: {api_result['status']}")
            
            # Step 6: Execute comprehensive autonomous validation
            print("\n🔍 Step 6: Running comprehensive validation...")
            validation_result = await self._execute_comprehensive_validation(project_id)
            workflow_results["steps"]["comprehensive_validation"] = validation_result
            print(f"✅ Comprehensive validation: {'PASSED' if validation_result['overall_valid'] else 'FAILED'}")
            
            # Step 7: Generate final report
            print("\n📊 Step 7: Generating final report...")
            final_report = self._generate_final_report(workflow_results)
            workflow_results["final_report"] = final_report
            
            workflow_results["completed_at"] = int(time.time())
            workflow_results["duration"] = workflow_results["completed_at"] - workflow_results["started_at"]
            workflow_results["status"] = "completed"
            
            print(f"\n🎉 Autonomous workflow completed in {workflow_results['duration']}s")
            return workflow_results
            
        except Exception as e:
            print(f"\n❌ Workflow failed: {str(e)}")
            workflow_results["error"] = str(e)
            workflow_results["status"] = "failed"
            workflow_results["completed_at"] = int(time.time())
            return workflow_results
    
    async def _create_project(self, prd_content: str, project_name: str) -> Dict[str, Any]:
        """Create project with PRD content"""
        
        payload = {
            "name": project_name,
            "prd_content": prd_content,
            "project_config": {
                "environment": "development",
                "validation_level": "comprehensive",
                "parallel_execution": True
            }
        }
        
        async with aiohttp.ClientSession() as session:
            async with session.post(
                f"{self.rpa_api_base}/projects/create",
                json=payload
            ) as response:
                if response.status != 200:
                    raise Exception(f"Failed to create project: {response.status}")
                return await response.json()
    
    async def _wait_for_prd_processing(self, project_id: str, max_wait: int = 300) -> None:
        """Wait for PRD processing to complete"""
        
        start_time = time.time()
        
        while time.time() - start_time < max_wait:
            async with aiohttp.ClientSession() as session:
                async with session.get(
                    f"{self.rpa_api_base}/projects/{project_id}"
                ) as response:
                    if response.status != 200:
                        raise Exception(f"Failed to get project status: {response.status}")
                    
                    project_data = await response.json()
                    status = project_data.get("status")
                    
                    if status == "ready":
                        return
                    elif status == "failed":
                        raise Exception(f"PRD processing failed: {project_data.get('error', 'Unknown error')}")
                    
                    print(f"  Status: {status}... waiting")
                    await asyncio.sleep(10)
        
        raise Exception("PRD processing timeout")
    
    async def _get_project_workflows(self, project_id: str) -> Dict[str, Any]:
        """Get generated workflows for project"""
        
        async with aiohttp.ClientSession() as session:
            async with session.get(
                f"{self.rpa_api_base}/projects/{project_id}/workflows"
            ) as response:
                if response.status != 200:
                    raise Exception(f"Failed to get workflows: {response.status}")
                return await response.json()
    
    async def _execute_ui_validation(self, project_id: str) -> Dict[str, Any]:
        """Execute UI validation workflow"""
        
        payload = {
            "project_id": project_id,
            "workflow_type": "ui_validation",
            "component_category": "ui_testing",
            "parameters": {
                "target_url": "http://localhost:3000",
                "validation_rules": ["responsiveness", "accessibility", "functionality"],
                "screenshot_enabled": True
            },
            "timeout": 300
        }
        
        return await self._execute_workflow_and_wait(payload)
    
    async def _execute_api_validation(self, project_id: str) -> Dict[str, Any]:
        """Execute API validation workflow"""
        
        payload = {
            "project_id": project_id,
            "workflow_type": "api_validation",
            "component_category": "api_testing",
            "parameters": {
                "endpoints": ["/api/health", "/api/auth/login", "/api/dashboard"],
                "validation_rules": ["status_codes", "response_validation", "performance"],
                "performance_threshold": 2000
            },
            "timeout": 300
        }
        
        return await self._execute_workflow_and_wait(payload)
    
    async def _execute_workflow_and_wait(self, payload: Dict[str, Any]) -> Dict[str, Any]:
        """Execute workflow and wait for completion"""
        
        # Start workflow execution
        async with aiohttp.ClientSession() as session:
            async with session.post(
                f"{self.rpa_api_base}/workflows/execute",
                json=payload
            ) as response:
                if response.status != 200:
                    raise Exception(f"Failed to execute workflow: {response.status}")
                
                execution_data = await response.json()
                execution_id = execution_data["execution_id"]
        
        # Wait for completion
        start_time = time.time()
        max_wait = payload.get("timeout", 300) + 60  # Add buffer
        
        while time.time() - start_time < max_wait:
            async with aiohttp.ClientSession() as session:
                async with session.get(
                    f"{self.rpa_api_base}/workflows/execution/{execution_id}"
                ) as response:
                    if response.status != 200:
                        raise Exception(f"Failed to get execution status: {response.status}")
                    
                    execution_result = await response.json()
                    status = execution_result.get("status")
                    
                    if status in ["completed", "failed"]:
                        return execution_result
                    
                    await asyncio.sleep(5)
        
        raise Exception("Workflow execution timeout")
    
    async def _execute_comprehensive_validation(self, project_id: str) -> Dict[str, Any]:
        """Execute comprehensive autonomous validation"""
        
        payload = {
            "project_id": project_id,
            "task_result": {
                "implementation_status": "completed",
                "features_implemented": ["authentication", "dashboard", "api_endpoints"],
                "test_coverage": 85.5,
                "performance_metrics": {
                    "response_time": 150,
                    "throughput": 1000,
                    "error_rate": 0.1
                }
            },
            "expected_behavior": {
                "ui": {
                    "target_url": "http://localhost:3000",
                    "elements": ["login_form", "dashboard", "navigation"],
                    "rules": ["responsive", "accessible", "functional"]
                },
                "api": {
                    "endpoints": ["/api/auth/login", "/api/dashboard", "/api/health"],
                    "responses": {"login": 200, "dashboard": 200, "health": 200},
                    "rules": ["performance", "security", "reliability"]
                },
                "integration": {
                    "checks": ["database_connectivity", "external_services", "caching"],
                    "data": {"consistency": True, "integrity": True},
                    "performance": {"response_time": 200, "throughput": 500}
                }
            }
        }
        
        async with aiohttp.ClientSession() as session:
            async with session.post(
                f"{self.rpa_api_base}/validation/execute",
                json=payload
            ) as response:
                if response.status != 200:
                    raise Exception(f"Failed to execute validation: {response.status}")
                return await response.json()
    
    def _generate_final_report(self, workflow_results: Dict[str, Any]) -> Dict[str, Any]:
        """Generate final workflow report"""
        
        steps = workflow_results.get("steps", {})
        
        # Calculate success metrics
        ui_success = steps.get("ui_validation", {}).get("status") == "completed"
        api_success = steps.get("api_validation", {}).get("status") == "completed"
        validation_success = steps.get("comprehensive_validation", {}).get("overall_valid", False)
        
        overall_success = ui_success and api_success and validation_success
        
        # Generate recommendations
        recommendations = []
        if not ui_success:
            recommendations.append("Review UI implementation and fix validation issues")
        if not api_success:
            recommendations.append("Check API endpoints and fix performance/reliability issues")
        if not validation_success:
            recommendations.append("Address comprehensive validation failures before deployment")
        
        if overall_success:
            recommendations.append("System is ready for deployment")
        
        return {
            "overall_success": overall_success,
            "success_rate": sum([ui_success, api_success, validation_success]) / 3,
            "validation_summary": {
                "ui_validation": "✅ PASSED" if ui_success else "❌ FAILED",
                "api_validation": "✅ PASSED" if api_success else "❌ FAILED",
                "comprehensive_validation": "✅ PASSED" if validation_success else "❌ FAILED"
            },
            "recommendations": recommendations,
            "deployment_ready": overall_success
        }


async def main():
    """Main example function"""
    
    # Example PRD content
    prd_content = """
    # E-Commerce Platform Requirements
    
    ## User Authentication
    - Users must be able to register with email and password
    - Users must be able to login with valid credentials
    - System should validate email format and password strength
    - Failed login attempts should be logged and rate-limited
    
    ## Product Catalog
    - Users should be able to browse products by category
    - Product search functionality with filters
    - Product details page with images and descriptions
    - Shopping cart functionality with add/remove items
    
    ## API Requirements
    - RESTful API endpoints for all user operations
    - Authentication endpoints (/api/auth/login, /api/auth/register)
    - Product endpoints (/api/products, /api/products/{id})
    - Cart endpoints (/api/cart, /api/cart/add, /api/cart/remove)
    - All endpoints should return proper HTTP status codes
    - API response time should be under 200ms for 95% of requests
    
    ## Data Requirements
    - User data stored securely with encrypted passwords
    - Product catalog stored in database with proper indexing
    - Shopping cart data persisted across sessions
    - Order history maintained for users
    
    ## Performance Requirements
    - Page load time under 2 seconds
    - Support for 1000 concurrent users
    - 99.9% uptime requirement
    - Database queries optimized for performance
    
    ## Security Requirements
    - HTTPS encryption for all communications
    - Input validation and sanitization
    - Protection against SQL injection and XSS
    - Secure session management
    """
    
    # Initialize workflow
    workflow = AutonomousPRDWorkflow()
    
    # Run autonomous workflow
    results = await workflow.run_autonomous_workflow(
        prd_content=prd_content,
        project_name="E-Commerce Platform Validation"
    )
    
    # Print results
    print("\n" + "="*80)
    print("🎯 AUTONOMOUS WORKFLOW RESULTS")
    print("="*80)
    
    print(f"\n📊 **Final Report**:")
    final_report = results.get("final_report", {})
    print(f"• **Overall Success**: {'✅ YES' if final_report.get('overall_success') else '❌ NO'}")
    print(f"• **Success Rate**: {final_report.get('success_rate', 0):.1%}")
    print(f"• **Deployment Ready**: {'✅ YES' if final_report.get('deployment_ready') else '❌ NO'}")
    
    print(f"\n🔍 **Validation Summary**:")
    validation_summary = final_report.get("validation_summary", {})
    for validation_type, status in validation_summary.items():
        print(f"• **{validation_type.replace('_', ' ').title()}**: {status}")
    
    print(f"\n💡 **Recommendations**:")
    for i, recommendation in enumerate(final_report.get("recommendations", []), 1):
        print(f"{i}. {recommendation}")
    
    print(f"\n⏱️ **Execution Time**: {results.get('duration', 0)}s")
    print(f"📋 **Project ID**: {results.get('steps', {}).get('create_project', {}).get('project_id', 'N/A')}")
    
    # Save detailed results
    with open("autonomous_workflow_results.json", "w") as f:
        json.dump(results, f, indent=2)
    
    print(f"\n💾 **Detailed results saved to**: autonomous_workflow_results.json")
    
    return results


if __name__ == "__main__":
    # Run the example
    asyncio.run(main())
