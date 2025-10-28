"""
Component Mapping Service

Maps PRD requirements to appropriate RPA components and creates
intelligent workflow mappings for autonomous CI/CD execution.
"""

import re
import time
from typing import Any, Dict, List, Optional, Tuple

from pydantic import BaseModel, Field

from common_imports import logger, Span
from service.plugin.astron_rpa_plugin import AstronRpaPlugin, RpaWorkflowConfig


class RequirementAnalysis(BaseModel):
    """Analysis result for a single requirement"""
    
    id: str = Field(..., description="Requirement ID")
    type: str = Field(..., description="Requirement type")
    priority: str = Field(default="medium", description="Priority level")
    complexity: float = Field(default=0.5, description="Complexity score (0-1)")
    components_needed: List[str] = Field(default_factory=list, description="Required RPA components")
    validation_strategy: str = Field(default="standard", description="Validation approach")
    estimated_duration: int = Field(default=300, description="Estimated execution time in seconds")


class ProjectWorkflowMapping(BaseModel):
    """Complete workflow mapping for a project"""
    
    project_id: str = Field(..., description="Project identifier")
    requirements: List[RequirementAnalysis] = Field(default_factory=list, description="Analyzed requirements")
    workflow_mappings: Dict[str, Any] = Field(default_factory=dict, description="Component workflow mappings")
    execution_plan: Dict[str, Any] = Field(default_factory=dict, description="Execution plan")
    validation_strategy: Dict[str, Any] = Field(default_factory=dict, description="Validation strategy")
    estimated_total_duration: int = Field(default=0, description="Total estimated duration")


class ComponentMappingService:
    """Service for mapping requirements to RPA components"""
    
    def __init__(self):
        """Initialize the component mapping service"""
        
        # Component categories and their capabilities
        self.component_capabilities = {
            "ui_testing": {
                "components": ["rpabrowser", "rpacv", "rpawindow"],
                "capabilities": [
                    "web_automation", "ui_validation", "screenshot_capture",
                    "element_interaction", "form_filling", "navigation"
                ],
                "use_cases": [
                    "user interface testing", "web application validation",
                    "ui element verification", "user experience testing"
                ]
            },
            "api_testing": {
                "components": ["rpanetwork", "rpaopenapi"],
                "capabilities": [
                    "api_validation", "endpoint_testing", "integration_testing",
                    "response_validation", "performance_testing", "load_testing"
                ],
                "use_cases": [
                    "api endpoint validation", "service integration testing",
                    "microservice communication", "rest api testing"
                ]
            },
            "data_processing": {
                "components": ["rpadatabase", "rpaexcel", "rpapdf", "rpadocx"],
                "capabilities": [
                    "data_validation", "report_generation", "document_processing",
                    "database_operations", "file_manipulation", "data_transformation"
                ],
                "use_cases": [
                    "data integrity validation", "report generation",
                    "document processing", "database testing"
                ]
            },
            "ai_processing": {
                "components": ["rpaai", "rpaverifycode"],
                "capabilities": [
                    "intelligent_validation", "code_verification", "ai_analysis",
                    "pattern_recognition", "anomaly_detection", "smart_validation"
                ],
                "use_cases": [
                    "intelligent code analysis", "ai-powered validation",
                    "pattern matching", "anomaly detection"
                ]
            },
            "system_automation": {
                "components": ["rpasystem", "rpaencrypt", "rpaemail", "rpaenterprise"],
                "capabilities": [
                    "system_monitoring", "security_operations", "notifications",
                    "process_automation", "infrastructure_management", "deployment_automation"
                ],
                "use_cases": [
                    "system health monitoring", "deployment automation",
                    "notification systems", "security validation"
                ]
            }
        }
        
        # Requirement type patterns for intelligent classification
        self.requirement_patterns = {
            "ui": [
                r"user interface", r"ui", r"frontend", r"web page", r"form",
                r"button", r"navigation", r"layout", r"responsive", r"visual"
            ],
            "api": [
                r"api", r"endpoint", r"service", r"rest", r"graphql",
                r"microservice", r"integration", r"webhook", r"http"
            ],
            "data": [
                r"database", r"data", r"storage", r"persistence", r"sql",
                r"nosql", r"migration", r"backup", r"report", r"analytics"
            ],
            "ai": [
                r"artificial intelligence", r"ai", r"machine learning", r"ml",
                r"intelligent", r"smart", r"prediction", r"analysis", r"nlp"
            ],
            "system": [
                r"system", r"infrastructure", r"deployment", r"monitoring",
                r"security", r"performance", r"scalability", r"availability"
            ]
        }
    
    async def create_project_workflow_mappings(self,
                                             prd_content: str,
                                             project_config: Dict[str, Any],
                                             span: Span) -> Dict[str, Any]:
        """
        Create comprehensive workflow mappings for a project
        
        Args:
            prd_content: Product Requirements Document content
            project_config: Project configuration
            span: Tracing span for observability
            
        Returns:
            Dictionary containing complete workflow mappings
        """
        try:
            project_id = project_config.get("project_id", f"project_{int(time.time())}")
            
            # Step 1: Parse and analyze requirements
            requirements = await self._parse_requirements(prd_content, span)
            
            # Step 2: Analyze each requirement
            analyzed_requirements = []
            for req in requirements:
                analysis = await self._analyze_requirement(req, span)
                analyzed_requirements.append(analysis)
            
            # Step 3: Create workflow mappings
            workflow_mappings = await self._create_workflow_mappings(analyzed_requirements, span)
            
            # Step 4: Create execution plan
            execution_plan = self._create_execution_plan(analyzed_requirements, workflow_mappings)
            
            # Step 5: Create validation strategy
            validation_strategy = self._create_validation_strategy(analyzed_requirements)
            
            # Calculate total estimated duration
            total_duration = sum(req.estimated_duration for req in analyzed_requirements)
            
            span.add_info_events(
                project_id=project_id,
                requirements_count=len(analyzed_requirements),
                workflow_mappings_count=len(workflow_mappings),
                total_estimated_duration=total_duration
            )
            
            return {
                "project_id": project_id,
                "requirements": [req.dict() for req in analyzed_requirements],
                "workflow_mappings": workflow_mappings,
                "execution_plan": execution_plan,
                "validation_strategy": validation_strategy,
                "estimated_total_duration": total_duration
            }
            
        except Exception as e:
            error_msg = f"Failed to create project workflow mappings: {str(e)}"
            logger.error(error_msg)
            span.add_info_events(error=error_msg)
            
            return {
                "project_id": project_config.get("project_id", "unknown"),
                "requirements": [],
                "workflow_mappings": {},
                "execution_plan": {},
                "validation_strategy": {},
                "estimated_total_duration": 0,
                "error": error_msg
            }
    
    async def _parse_requirements(self, prd_content: str, span: Span) -> List[Dict[str, Any]]:
        """Parse requirements from PRD content"""
        requirements = []
        
        # Simple requirement extraction (in production, this would use NLP/AI)
        lines = prd_content.split('\n')
        current_requirement = None
        
        for line in lines:
            line = line.strip()
            
            # Look for requirement indicators
            if any(indicator in line.lower() for indicator in ['requirement', 'feature', 'functionality', 'must', 'should']):
                if current_requirement:
                    requirements.append(current_requirement)
                
                current_requirement = {
                    "id": f"req_{len(requirements) + 1}",
                    "title": line,
                    "description": line,
                    "content": [line],
                    "priority": self._extract_priority(line),
                    "type": "general"
                }
            elif current_requirement and line:
                current_requirement["content"].append(line)
                current_requirement["description"] += f" {line}"
        
        # Add the last requirement
        if current_requirement:
            requirements.append(current_requirement)
        
        # If no structured requirements found, create general ones
        if not requirements:
            requirements = [
                {
                    "id": "req_general",
                    "title": "General System Requirements",
                    "description": prd_content[:500] + "..." if len(prd_content) > 500 else prd_content,
                    "content": [prd_content],
                    "priority": "medium",
                    "type": "general"
                }
            ]
        
        span.add_info_events(requirements_parsed=len(requirements))
        return requirements
    
    async def _analyze_requirement(self, requirement: Dict[str, Any], span: Span) -> RequirementAnalysis:
        """Analyze a single requirement and determine component needs"""
        
        req_text = requirement.get("description", "").lower()
        req_type = self._classify_requirement_type(req_text)
        complexity = self._calculate_complexity(requirement)
        components_needed = self._determine_components(req_type, req_text)
        validation_strategy = self._determine_validation_strategy(req_type, complexity)
        estimated_duration = self._estimate_duration(req_type, complexity)
        
        return RequirementAnalysis(
            id=requirement.get("id", f"req_{int(time.time())}"),
            type=req_type,
            priority=requirement.get("priority", "medium"),
            complexity=complexity,
            components_needed=components_needed,
            validation_strategy=validation_strategy,
            estimated_duration=estimated_duration
        )
    
    def _classify_requirement_type(self, req_text: str) -> str:
        """Classify requirement type based on content"""
        
        type_scores = {}
        
        for req_type, patterns in self.requirement_patterns.items():
            score = 0
            for pattern in patterns:
                matches = len(re.findall(pattern, req_text, re.IGNORECASE))
                score += matches
            type_scores[req_type] = score
        
        # Return the type with highest score, default to 'system'
        if not type_scores or max(type_scores.values()) == 0:
            return "system"
        
        return max(type_scores, key=type_scores.get)
    
    def _calculate_complexity(self, requirement: Dict[str, Any]) -> float:
        """Calculate complexity score for a requirement"""
        
        complexity_factors = {
            "length": len(requirement.get("description", "")),
            "technical_terms": len(re.findall(r'\b(api|database|integration|security|performance)\b', 
                                            requirement.get("description", "").lower())),
            "priority": {"high": 0.8, "medium": 0.5, "low": 0.3}.get(
                requirement.get("priority", "medium"), 0.5)
        }
        
        # Normalize and combine factors
        length_score = min(complexity_factors["length"] / 1000, 1.0)  # Max 1.0 for 1000+ chars
        technical_score = min(complexity_factors["technical_terms"] / 10, 1.0)  # Max 1.0 for 10+ terms
        priority_score = complexity_factors["priority"]
        
        # Weighted average
        complexity = (length_score * 0.3 + technical_score * 0.4 + priority_score * 0.3)
        return round(complexity, 2)
    
    def _determine_components(self, req_type: str, req_text: str) -> List[str]:
        """Determine which RPA components are needed for a requirement"""
        
        # Map requirement types to component categories
        type_to_category = {
            "ui": "ui_testing",
            "api": "api_testing", 
            "data": "data_processing",
            "ai": "ai_processing",
            "system": "system_automation"
        }
        
        category = type_to_category.get(req_type, "system_automation")
        return self.component_capabilities[category]["components"]
    
    def _determine_validation_strategy(self, req_type: str, complexity: float) -> str:
        """Determine validation strategy based on type and complexity"""
        
        if complexity > 0.7:
            return "comprehensive"
        elif complexity > 0.4:
            return "standard"
        else:
            return "basic"
    
    def _estimate_duration(self, req_type: str, complexity: float) -> int:
        """Estimate execution duration for a requirement"""
        
        base_durations = {
            "ui": 240,      # 4 minutes
            "api": 180,     # 3 minutes
            "data": 300,    # 5 minutes
            "ai": 420,      # 7 minutes
            "system": 360   # 6 minutes
        }
        
        base_duration = base_durations.get(req_type, 300)
        complexity_multiplier = 1 + complexity  # 1.0 to 2.0
        
        return int(base_duration * complexity_multiplier)
    
    async def _create_workflow_mappings(self, 
                                      requirements: List[RequirementAnalysis],
                                      span: Span) -> Dict[str, Any]:
        """Create workflow mappings for all requirements"""
        
        mappings = {}
        
        for req in requirements:
            category = self._get_category_for_type(req.type)
            
            mappings[req.id] = {
                "requirement": req.dict(),
                "component_category": category,
                "components": req.components_needed,
                "workflow_config": {
                    "workflow_type": f"{req.type}_validation",
                    "parameters": {
                        "validation_strategy": req.validation_strategy,
                        "complexity_level": req.complexity,
                        "priority": req.priority,
                        "timeout": req.estimated_duration
                    },
                    "validation_rules": self._get_validation_rules(req.type, req.validation_strategy)
                }
            }
        
        return mappings
    
    def _get_category_for_type(self, req_type: str) -> str:
        """Get component category for requirement type"""
        
        type_to_category = {
            "ui": "ui_testing",
            "api": "api_testing",
            "data": "data_processing", 
            "ai": "ai_processing",
            "system": "system_automation"
        }
        
        return type_to_category.get(req_type, "system_automation")
    
    def _get_validation_rules(self, req_type: str, validation_strategy: str) -> List[str]:
        """Get validation rules for requirement type and strategy"""
        
        base_rules = {
            "ui": ["element_presence", "functionality", "responsiveness"],
            "api": ["response_validation", "status_codes", "performance"],
            "data": ["data_integrity", "consistency", "backup_validation"],
            "ai": ["accuracy", "performance", "edge_cases"],
            "system": ["availability", "performance", "security"]
        }
        
        rules = base_rules.get(req_type, ["basic_validation"])
        
        if validation_strategy == "comprehensive":
            rules.extend(["stress_testing", "edge_case_validation", "security_checks"])
        elif validation_strategy == "standard":
            rules.extend(["performance_checks"])
        
        return rules
    
    def _create_execution_plan(self, 
                             requirements: List[RequirementAnalysis],
                             workflow_mappings: Dict[str, Any]) -> Dict[str, Any]:
        """Create execution plan for all workflows"""
        
        # Group requirements by priority and type for optimal execution
        priority_groups = {"high": [], "medium": [], "low": []}
        type_groups = {}
        
        for req in requirements:
            priority_groups[req.priority].append(req.id)
            
            if req.type not in type_groups:
                type_groups[req.type] = []
            type_groups[req.type].append(req.id)
        
        # Create parallel execution groups (same type can run in parallel)
        parallel_groups = list(type_groups.values())
        
        # Calculate total estimated duration with parallelization
        max_group_duration = 0
        for group in parallel_groups:
            group_duration = sum(
                req.estimated_duration for req in requirements 
                if req.id in group
            )
            max_group_duration = max(max_group_duration, group_duration)
        
        return {
            "total_requirements": len(requirements),
            "execution_order": priority_groups["high"] + priority_groups["medium"] + priority_groups["low"],
            "parallel_groups": parallel_groups,
            "priority_groups": priority_groups,
            "type_groups": type_groups,
            "estimated_duration": max_group_duration,
            "parallelization_factor": len(parallel_groups)
        }
    
    def _create_validation_strategy(self, requirements: List[RequirementAnalysis]) -> Dict[str, Any]:
        """Create overall validation strategy for the project"""
        
        strategy_counts = {}
        complexity_levels = []
        
        for req in requirements:
            strategy = req.validation_strategy
            strategy_counts[strategy] = strategy_counts.get(strategy, 0) + 1
            complexity_levels.append(req.complexity)
        
        avg_complexity = sum(complexity_levels) / len(complexity_levels) if complexity_levels else 0
        primary_strategy = max(strategy_counts, key=strategy_counts.get) if strategy_counts else "standard"
        
        return {
            "primary_strategy": primary_strategy,
            "strategy_distribution": strategy_counts,
            "average_complexity": round(avg_complexity, 2),
            "validation_phases": [
                "component_validation",
                "integration_validation", 
                "end_to_end_validation"
            ],
            "success_criteria": {
                "minimum_pass_rate": 0.8,
                "critical_requirements_pass_rate": 1.0,
                "performance_threshold": "acceptable"
            }
        }
    
    def _extract_priority(self, text: str) -> str:
        """Extract priority from requirement text"""
        
        text_lower = text.lower()
        
        if any(word in text_lower for word in ["critical", "urgent", "high", "must"]):
            return "high"
        elif any(word in text_lower for word in ["low", "nice", "optional"]):
            return "low"
        else:
            return "medium"
