"""
Enhanced Component Mapping Service

AI-powered component mapping service that analyzes PRD content
and maps requirements to appropriate RPA components.
"""

import asyncio
import json
import re
from typing import Any, Dict, List, Optional, Tuple
from datetime import datetime

from common_imports import logger, Span


class ComponentMappingService:
    """Enhanced component mapping service with AI-powered analysis"""
    
    def __init__(self):
        self.component_registry = self._initialize_component_registry()
        self.mapping_strategies = self._initialize_mapping_strategies()
        
    def _initialize_component_registry(self) -> Dict[str, Dict[str, Any]]:
        """Initialize the comprehensive RPA component registry"""
        return {
            # UI Testing Components
            "rpabrowser": {
                "category": "ui_testing",
                "description": "Browser automation and web interaction",
                "capabilities": ["click", "type", "navigate", "screenshot", "wait", "form_fill"],
                "supported_browsers": ["chromium", "firefox", "webkit"],
                "keywords": ["browser", "web", "click", "navigate", "form", "ui", "frontend"],
                "complexity_score": 3,
                "reliability_score": 9
            },
            "rpacv": {
                "category": "ui_testing", 
                "description": "Computer vision and image recognition",
                "capabilities": ["image_recognition", "ocr", "template_matching", "visual_validation"],
                "supported_formats": ["png", "jpg", "bmp", "tiff"],
                "keywords": ["image", "vision", "ocr", "screenshot", "visual", "recognition"],
                "complexity_score": 7,
                "reliability_score": 8
            },
            "rpawindow": {
                "category": "ui_testing",
                "description": "Desktop window and application automation",
                "capabilities": ["window_management", "keyboard_input", "mouse_control", "process_control"],
                "keywords": ["desktop", "window", "application", "keyboard", "mouse", "native"],
                "complexity_score": 5,
                "reliability_score": 8
            },
            
            # API Testing Components  
            "rpanetwork": {
                "category": "api_testing",
                "description": "Network requests and HTTP client",
                "capabilities": ["http_methods", "authentication", "ssl_verification", "request_validation"],
                "supported_methods": ["GET", "POST", "PUT", "DELETE", "PATCH", "HEAD", "OPTIONS"],
                "keywords": ["api", "http", "rest", "request", "response", "network", "endpoint"],
                "complexity_score": 4,
                "reliability_score": 9
            },
            "rpaopenapi": {
                "category": "api_testing",
                "description": "OpenAPI specification testing and validation",
                "capabilities": ["spec_validation", "contract_testing", "schema_validation", "swagger"],
                "keywords": ["openapi", "swagger", "specification", "contract", "schema", "validation"],
                "complexity_score": 6,
                "reliability_score": 9
            },
            
            # Data Processing Components
            "rpadatabase": {
                "category": "data_processing",
                "description": "Database operations and SQL execution",
                "capabilities": ["select", "insert", "update", "delete", "transactions", "bulk_operations"],
                "supported_databases": ["mysql", "postgresql", "sqlite", "mongodb"],
                "keywords": ["database", "sql", "query", "data", "table", "record", "crud"],
                "complexity_score": 5,
                "reliability_score": 9
            },
            "rpaexcel": {
                "category": "data_processing",
                "description": "Excel file processing and manipulation",
                "capabilities": ["read", "write", "format", "calculate", "charts", "pivot_tables"],
                "supported_formats": ["xlsx", "xls", "csv"],
                "keywords": ["excel", "spreadsheet", "csv", "data", "calculation", "chart"],
                "complexity_score": 4,
                "reliability_score": 8
            },
            "rpapdf": {
                "category": "data_processing",
                "description": "PDF document processing and extraction",
                "capabilities": ["read", "extract_text", "extract_images", "merge", "split", "form_fill"],
                "keywords": ["pdf", "document", "text", "extract", "merge", "split"],
                "complexity_score": 6,
                "reliability_score": 7
            },
            "rpadocx": {
                "category": "data_processing",
                "description": "Word document processing and generation",
                "capabilities": ["read", "write", "format", "template", "mail_merge", "convert"],
                "supported_formats": ["docx", "doc", "rtf", "txt"],
                "keywords": ["word", "document", "template", "text", "format", "report"],
                "complexity_score": 5,
                "reliability_score": 8
            },
            
            # AI Processing Components
            "rpaai": {
                "category": "ai_processing",
                "description": "AI-powered analysis and decision making",
                "capabilities": ["text_analysis", "code_review", "decision_making", "classification", "nlp"],
                "supported_models": ["gpt-4", "claude-3", "gemini-pro"],
                "keywords": ["ai", "analysis", "decision", "intelligent", "nlp", "classification"],
                "complexity_score": 8,
                "reliability_score": 7
            },
            "rpaverifycode": {
                "category": "ai_processing",
                "description": "Code verification and quality analysis",
                "capabilities": ["syntax", "security", "performance", "best_practices", "static_analysis"],
                "supported_languages": ["python", "javascript", "java", "go", "rust", "typescript"],
                "keywords": ["code", "verification", "quality", "security", "analysis", "review"],
                "complexity_score": 7,
                "reliability_score": 8
            },
            
            # System Automation Components
            "rpasystem": {
                "category": "system_automation",
                "description": "System operations and process management",
                "capabilities": ["file_ops", "process_control", "service_management", "monitoring"],
                "supported_platforms": ["linux", "windows", "macos"],
                "keywords": ["system", "process", "file", "service", "management", "automation"],
                "complexity_score": 6,
                "reliability_score": 8
            },
            "rpaencrypt": {
                "category": "system_automation",
                "description": "Encryption and security operations",
                "capabilities": ["encrypt", "decrypt", "hash", "sign", "verify", "key_management"],
                "supported_algorithms": ["AES", "RSA", "ChaCha20", "Argon2"],
                "keywords": ["encrypt", "security", "hash", "sign", "crypto", "protection"],
                "complexity_score": 7,
                "reliability_score": 9
            },
            "rpaemail": {
                "category": "system_automation",
                "description": "Email processing and automation",
                "capabilities": ["send", "receive", "parse", "filter", "archive", "templates"],
                "supported_protocols": ["SMTP", "IMAP", "POP3"],
                "keywords": ["email", "mail", "send", "receive", "notification", "communication"],
                "complexity_score": 4,
                "reliability_score": 8
            },
            "rpaenterprise": {
                "category": "system_automation",
                "description": "Enterprise integration and workflow",
                "capabilities": ["workflows", "approval_processes", "audit_logging", "integration"],
                "supported_integrations": ["sap", "salesforce", "jira", "confluence", "slack"],
                "keywords": ["enterprise", "workflow", "integration", "approval", "audit"],
                "complexity_score": 8,
                "reliability_score": 7
            }
        }
    
    def _initialize_mapping_strategies(self) -> Dict[str, Any]:
        """Initialize mapping strategies for different project types"""
        return {
            "basic": {
                "max_components": 5,
                "complexity_threshold": 5,
                "focus": "simple_automation"
            },
            "standard": {
                "max_components": 10,
                "complexity_threshold": 7,
                "focus": "comprehensive_testing"
            },
            "comprehensive": {
                "max_components": 15,
                "complexity_threshold": 10,
                "focus": "enterprise_integration"
            }
        }
    
    async def create_project_workflow_mappings(
        self,
        prd_content: str,
        project_config: Dict[str, Any],
        span: Optional[Span] = None
    ) -> Dict[str, Any]:
        """Create comprehensive workflow mappings from PRD content"""
        try:
            if span:
                span.add_info_events(action="create_workflow_mappings", prd_length=len(prd_content))
            
            # Analyze PRD content
            analysis_result = await self._analyze_prd_content(prd_content, project_config)
            
            # Generate component mappings
            component_mappings = await self._generate_component_mappings(
                analysis_result, project_config
            )
            
            # Create execution plan
            execution_plan = await self._create_execution_plan(component_mappings)
            
            # Generate validation strategy
            validation_strategy = await self._create_validation_strategy(
                analysis_result, component_mappings
            )
            
            return {
                "workflow_mappings": component_mappings,
                "execution_plan": execution_plan,
                "validation_strategy": validation_strategy,
                "requirements": analysis_result["requirements"],
                "complexity_analysis": analysis_result["complexity_analysis"],
                "timestamp": datetime.utcnow().isoformat()
            }
            
        except Exception as e:
            logger.error(f"Workflow mapping creation failed: {str(e)}")
            raise
    
    async def _analyze_prd_content(
        self,
        prd_content: str,
        project_config: Dict[str, Any]
    ) -> Dict[str, Any]:
        """Analyze PRD content to extract requirements and complexity"""
        
        # Extract key requirements using pattern matching
        requirements = []
        complexity_indicators = []
        
        # UI/Frontend requirements
        ui_patterns = [
            r"user interface|ui|frontend|web page|form|button|navigation",
            r"browser|web application|responsive|mobile",
            r"click|type|input|select|dropdown|checkbox"
        ]
        
        # API/Backend requirements  
        api_patterns = [
            r"api|endpoint|rest|http|request|response",
            r"authentication|authorization|token|login",
            r"database|sql|query|crud|data"
        ]
        
        # Data processing requirements
        data_patterns = [
            r"excel|csv|spreadsheet|document|pdf|word",
            r"file|upload|download|import|export",
            r"report|chart|calculation|analysis"
        ]
        
        # AI/Intelligence requirements
        ai_patterns = [
            r"intelligent|ai|analysis|decision|classification",
            r"natural language|nlp|text analysis|sentiment",
            r"code review|quality|verification|validation"
        ]
        
        # System/Integration requirements
        system_patterns = [
            r"system|process|automation|workflow",
            r"integration|enterprise|sap|salesforce",
            r"email|notification|security|encryption"
        ]
        
        pattern_groups = {
            "ui_testing": ui_patterns,
            "api_testing": api_patterns,
            "data_processing": data_patterns,
            "ai_processing": ai_patterns,
            "system_automation": system_patterns
        }
        
        # Analyze content for each pattern group
        for category, patterns in pattern_groups.items():
            for pattern in patterns:
                matches = re.findall(pattern, prd_content.lower())
                if matches:
                    requirements.append({
                        "category": category,
                        "pattern": pattern,
                        "matches": len(matches),
                        "confidence": min(len(matches) * 0.2, 1.0)
                    })
        
        # Calculate complexity indicators
        complexity_factors = {
            "authentication": len(re.findall(r"auth|login|user|permission", prd_content.lower())),
            "database_operations": len(re.findall(r"database|sql|data|crud", prd_content.lower())),
            "api_integration": len(re.findall(r"api|endpoint|integration", prd_content.lower())),
            "ui_complexity": len(re.findall(r"form|page|component|interface", prd_content.lower())),
            "business_logic": len(re.findall(r"business|logic|rule|workflow", prd_content.lower()))
        }
        
        total_complexity = sum(complexity_factors.values())
        complexity_level = "basic" if total_complexity < 10 else "standard" if total_complexity < 25 else "comprehensive"
        
        return {
            "requirements": requirements,
            "complexity_analysis": {
                "factors": complexity_factors,
                "total_score": total_complexity,
                "level": complexity_level
            },
            "estimated_components": min(len(requirements), 15),
            "estimated_duration_hours": max(total_complexity * 2, 8)
        }
    
    async def _generate_component_mappings(
        self,
        analysis_result: Dict[str, Any],
        project_config: Dict[str, Any]
    ) -> Dict[str, Any]:
        """Generate component mappings based on analysis results"""
        
        complexity_level = analysis_result["complexity_analysis"]["level"]
        strategy = self.mapping_strategies[complexity_level]
        
        # Group requirements by category
        requirements_by_category = {}
        for req in analysis_result["requirements"]:
            category = req["category"]
            if category not in requirements_by_category:
                requirements_by_category[category] = []
            requirements_by_category[category].append(req)
        
        # Select components for each category
        selected_components = {}
        
        for category, reqs in requirements_by_category.items():
            # Calculate category confidence
            category_confidence = sum(req["confidence"] for req in reqs) / len(reqs)
            
            if category_confidence > 0.3:  # Threshold for inclusion
                # Get components for this category
                category_components = {
                    name: comp for name, comp in self.component_registry.items()
                    if comp["category"] == category
                }
                
                # Select best components based on requirements
                selected = self._select_best_components(
                    category_components, reqs, strategy
                )
                
                if selected:
                    selected_components[category] = selected
        
        return {
            "components": selected_components,
            "total_components": sum(len(comps) for comps in selected_components.values()),
            "strategy_used": complexity_level,
            "confidence_score": self._calculate_overall_confidence(selected_components)
        }
    
    def _select_best_components(
        self,
        category_components: Dict[str, Dict[str, Any]],
        requirements: List[Dict[str, Any]],
        strategy: Dict[str, Any]
    ) -> List[Dict[str, Any]]:
        """Select the best components for given requirements"""
        
        scored_components = []
        
        for comp_name, comp_data in category_components.items():
            score = 0
            
            # Score based on keyword matches
            for req in requirements:
                pattern_words = req["pattern"].split("|")
                for word in pattern_words:
                    if word in comp_data.get("keywords", []):
                        score += req["confidence"] * 2
            
            # Adjust for complexity and reliability
            if comp_data["complexity_score"] <= strategy["complexity_threshold"]:
                score += comp_data["reliability_score"] * 0.1
            
            if score > 0:
                scored_components.append({
                    "name": comp_name,
                    "score": score,
                    "data": comp_data
                })
        
        # Sort by score and return top components
        scored_components.sort(key=lambda x: x["score"], reverse=True)
        max_components = min(len(scored_components), strategy["max_components"] // 2)
        
        return scored_components[:max_components]
    
    def _calculate_overall_confidence(self, selected_components: Dict[str, Any]) -> float:
        """Calculate overall confidence score for component selection"""
        if not selected_components:
            return 0.0
        
        total_score = 0
        total_components = 0
        
        for category, components in selected_components.items():
            for comp in components:
                total_score += comp["score"]
                total_components += 1
        
        return min(total_score / total_components / 10, 1.0) if total_components > 0 else 0.0
    
    async def _create_execution_plan(self, component_mappings: Dict[str, Any]) -> Dict[str, Any]:
        """Create execution plan for selected components"""
        
        execution_phases = []
        phase_number = 1
        
        # Define execution order by category priority
        category_priority = [
            "system_automation",  # Setup and infrastructure first
            "data_processing",    # Data preparation
            "api_testing",        # Backend validation
            "ui_testing",         # Frontend testing
            "ai_processing"       # Analysis and validation last
        ]
        
        for category in category_priority:
            if category in component_mappings["components"]:
                components = component_mappings["components"][category]
                
                phase = {
                    "phase": phase_number,
                    "name": f"{category.replace('_', ' ').title()} Phase",
                    "category": category,
                    "components": [comp["name"] for comp in components],
                    "estimated_duration_minutes": len(components) * 15,
                    "dependencies": [] if phase_number == 1 else [phase_number - 1]
                }
                
                execution_phases.append(phase)
                phase_number += 1
        
        return {
            "phases": execution_phases,
            "total_phases": len(execution_phases),
            "estimated_total_duration_minutes": sum(phase["estimated_duration_minutes"] for phase in execution_phases),
            "parallel_execution_possible": len(execution_phases) > 1
        }
    
    async def _create_validation_strategy(
        self,
        analysis_result: Dict[str, Any],
        component_mappings: Dict[str, Any]
    ) -> Dict[str, Any]:
        """Create validation strategy based on components and requirements"""
        
        validation_types = []
        
        # Determine validation types based on selected components
        if "ui_testing" in component_mappings["components"]:
            validation_types.append({
                "type": "ui_validation",
                "description": "Validate user interface functionality and responsiveness",
                "components": ["rpabrowser", "rpacv", "rpawindow"],
                "confidence_threshold": 0.8
            })
        
        if "api_testing" in component_mappings["components"]:
            validation_types.append({
                "type": "api_validation", 
                "description": "Validate API endpoints and data contracts",
                "components": ["rpanetwork", "rpaopenapi"],
                "confidence_threshold": 0.9
            })
        
        if "data_processing" in component_mappings["components"]:
            validation_types.append({
                "type": "data_validation",
                "description": "Validate data processing and file operations",
                "components": ["rpadatabase", "rpaexcel", "rpapdf", "rpadocx"],
                "confidence_threshold": 0.85
            })
        
        if "ai_processing" in component_mappings["components"]:
            validation_types.append({
                "type": "intelligence_validation",
                "description": "Validate AI-powered analysis and decision making",
                "components": ["rpaai", "rpaverifycode"],
                "confidence_threshold": 0.75
            })
        
        return {
            "validation_types": validation_types,
            "overall_strategy": "comprehensive" if len(validation_types) > 2 else "standard",
            "success_criteria": {
                "minimum_confidence": 0.8,
                "required_validations": len(validation_types),
                "allow_partial_success": analysis_result["complexity_analysis"]["level"] == "basic"
            }
        }
