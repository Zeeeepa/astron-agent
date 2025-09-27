"""
RPA Integration Configuration

Configuration settings for Astron-RPA integration including
service URLs, authentication, and component mappings.
"""

import os
from typing import Dict, List, Optional

from pydantic import BaseModel, Field


class RpaServiceConfig(BaseModel):
    """Configuration for RPA service connection"""
    
    openapi_service_url: str = Field(
        default="http://astron-rpa:8020",
        description="Base URL for Astron-RPA OpenAPI service"
    )
    
    mcp_endpoint: str = Field(
        default="/mcp",
        description="MCP endpoint path"
    )
    
    api_key: Optional[str] = Field(
        default=None,
        description="API key for RPA service authentication"
    )
    
    timeout: int = Field(
        default=300,
        description="Default timeout for RPA operations in seconds"
    )
    
    retry_count: int = Field(
        default=3,
        description="Default retry count for failed operations"
    )


class ComponentConfig(BaseModel):
    """Configuration for RPA component categories"""
    
    ui_automation: List[str] = Field(
        default=["rpabrowser", "rpacv", "rpawindow"],
        description="UI automation components"
    )
    
    api_testing: List[str] = Field(
        default=["rpanetwork", "rpaopenapi"],
        description="API testing components"
    )
    
    data_processing: List[str] = Field(
        default=["rpadatabase", "rpaexcel", "rpapdf", "rpadocx"],
        description="Data processing components"
    )
    
    ai_processing: List[str] = Field(
        default=["rpaai", "rpaverifycode"],
        description="AI processing components"
    )
    
    system_automation: List[str] = Field(
        default=["rpasystem", "rpaencrypt", "rpaemail", "rpaenterprise"],
        description="System automation components"
    )


class ValidationConfig(BaseModel):
    """Configuration for validation workflows"""
    
    default_timeout: int = Field(
        default=300,
        description="Default validation timeout in seconds"
    )
    
    confidence_threshold: float = Field(
        default=0.8,
        description="Minimum confidence threshold for validation success"
    )
    
    max_retry_attempts: int = Field(
        default=3,
        description="Maximum retry attempts for failed validations"
    )
    
    screenshot_enabled: bool = Field(
        default=True,
        description="Enable screenshot capture during validation"
    )
    
    detailed_logging: bool = Field(
        default=True,
        description="Enable detailed logging for validation processes"
    )


class WorkflowConfig(BaseModel):
    """Configuration for workflow execution"""
    
    parallel_execution: bool = Field(
        default=True,
        description="Enable parallel execution of workflows"
    )
    
    max_concurrent_workflows: int = Field(
        default=5,
        description="Maximum number of concurrent workflow executions"
    )
    
    workflow_timeout: int = Field(
        default=600,
        description="Default workflow execution timeout in seconds"
    )
    
    auto_retry_failed: bool = Field(
        default=True,
        description="Automatically retry failed workflows"
    )


class RpaIntegrationConfig(BaseModel):
    """Main RPA integration configuration"""
    
    service: RpaServiceConfig = Field(
        default_factory=RpaServiceConfig,
        description="RPA service configuration"
    )
    
    components: ComponentConfig = Field(
        default_factory=ComponentConfig,
        description="RPA component configuration"
    )
    
    validation: ValidationConfig = Field(
        default_factory=ValidationConfig,
        description="Validation configuration"
    )
    
    workflow: WorkflowConfig = Field(
        default_factory=WorkflowConfig,
        description="Workflow execution configuration"
    )
    
    enabled: bool = Field(
        default=True,
        description="Enable RPA integration"
    )
    
    debug_mode: bool = Field(
        default=False,
        description="Enable debug mode for RPA integration"
    )


def load_rpa_config() -> RpaIntegrationConfig:
    """
    Load RPA integration configuration from environment variables
    
    Returns:
        RpaIntegrationConfig instance with loaded settings
    """
    config_data = {}
    
    # Service configuration
    service_config = {}
    if os.getenv("RPA_OPENAPI_URL"):
        service_config["openapi_service_url"] = os.getenv("RPA_OPENAPI_URL")
    if os.getenv("RPA_API_KEY"):
        service_config["api_key"] = os.getenv("RPA_API_KEY")
    if os.getenv("RPA_TIMEOUT"):
        service_config["timeout"] = int(os.getenv("RPA_TIMEOUT"))
    if os.getenv("RPA_RETRY_COUNT"):
        service_config["retry_count"] = int(os.getenv("RPA_RETRY_COUNT"))
    
    if service_config:
        config_data["service"] = service_config
    
    # Validation configuration
    validation_config = {}
    if os.getenv("RPA_VALIDATION_TIMEOUT"):
        validation_config["default_timeout"] = int(os.getenv("RPA_VALIDATION_TIMEOUT"))
    if os.getenv("RPA_CONFIDENCE_THRESHOLD"):
        validation_config["confidence_threshold"] = float(os.getenv("RPA_CONFIDENCE_THRESHOLD"))
    if os.getenv("RPA_SCREENSHOT_ENABLED"):
        validation_config["screenshot_enabled"] = os.getenv("RPA_SCREENSHOT_ENABLED").lower() == "true"
    if os.getenv("RPA_DETAILED_LOGGING"):
        validation_config["detailed_logging"] = os.getenv("RPA_DETAILED_LOGGING").lower() == "true"
    
    if validation_config:
        config_data["validation"] = validation_config
    
    # Workflow configuration
    workflow_config = {}
    if os.getenv("RPA_PARALLEL_EXECUTION"):
        workflow_config["parallel_execution"] = os.getenv("RPA_PARALLEL_EXECUTION").lower() == "true"
    if os.getenv("RPA_MAX_CONCURRENT_WORKFLOWS"):
        workflow_config["max_concurrent_workflows"] = int(os.getenv("RPA_MAX_CONCURRENT_WORKFLOWS"))
    if os.getenv("RPA_WORKFLOW_TIMEOUT"):
        workflow_config["workflow_timeout"] = int(os.getenv("RPA_WORKFLOW_TIMEOUT"))
    if os.getenv("RPA_AUTO_RETRY_FAILED"):
        workflow_config["auto_retry_failed"] = os.getenv("RPA_AUTO_RETRY_FAILED").lower() == "true"
    
    if workflow_config:
        config_data["workflow"] = workflow_config
    
    # Global settings
    if os.getenv("RPA_INTEGRATION_ENABLED"):
        config_data["enabled"] = os.getenv("RPA_INTEGRATION_ENABLED").lower() == "true"
    if os.getenv("RPA_DEBUG_MODE"):
        config_data["debug_mode"] = os.getenv("RPA_DEBUG_MODE").lower() == "true"
    
    return RpaIntegrationConfig(**config_data)


# Global configuration instance
rpa_config = load_rpa_config()


def get_component_mapping() -> Dict[str, List[str]]:
    """
    Get component mapping dictionary
    
    Returns:
        Dictionary mapping component categories to component lists
    """
    return {
        "ui_automation": rpa_config.components.ui_automation,
        "api_testing": rpa_config.components.api_testing,
        "data_processing": rpa_config.components.data_processing,
        "ai_processing": rpa_config.components.ai_processing,
        "system_automation": rpa_config.components.system_automation
    }


def get_validation_rules() -> Dict[str, any]:
    """
    Get default validation rules
    
    Returns:
        Dictionary containing default validation rules
    """
    return {
        "timeout": rpa_config.validation.default_timeout,
        "confidence_threshold": rpa_config.validation.confidence_threshold,
        "max_retry_attempts": rpa_config.validation.max_retry_attempts,
        "screenshot_enabled": rpa_config.validation.screenshot_enabled,
        "detailed_logging": rpa_config.validation.detailed_logging
    }


def is_rpa_integration_enabled() -> bool:
    """
    Check if RPA integration is enabled
    
    Returns:
        True if RPA integration is enabled, False otherwise
    """
    return rpa_config.enabled


def get_rpa_service_url() -> str:
    """
    Get RPA service URL
    
    Returns:
        RPA service base URL
    """
    return rpa_config.service.openapi_service_url


def get_rpa_mcp_url() -> str:
    """
    Get RPA MCP endpoint URL
    
    Returns:
        Complete MCP endpoint URL
    """
    return f"{rpa_config.service.openapi_service_url}{rpa_config.service.mcp_endpoint}"
