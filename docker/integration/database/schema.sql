-- Astron-Agent RPA Integration Database Schema
-- Comprehensive schema for autonomous CI/CD workflows with RPA integration

-- ============================================================================
-- Database Setup
-- ============================================================================

-- Create databases if they don't exist
CREATE DATABASE IF NOT EXISTS astron_unified CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE DATABASE IF NOT EXISTS rpa CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- Use the unified database
USE astron_unified;

-- ============================================================================
-- Core Tables
-- ============================================================================

-- Projects table for PRD-based project management
CREATE TABLE IF NOT EXISTS projects (
    id VARCHAR(36) PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    prd_content LONGTEXT NOT NULL,
    project_config JSON,
    status ENUM('initializing', 'processing_prd', 'ready', 'executing', 'validating', 'completed', 'failed') DEFAULT 'initializing',
    complexity_level ENUM('basic', 'standard', 'comprehensive') DEFAULT 'standard',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    processed_at TIMESTAMP NULL,
    completed_at TIMESTAMP NULL,
    
    -- RPA Integration fields
    rpa_service_url VARCHAR(255) DEFAULT 'http://astron-rpa:8020',
    api_key VARCHAR(255) NULL,
    
    -- Workflow and validation data
    workflow_mappings JSON,
    execution_plan JSON,
    validation_strategy JSON,
    requirements JSON,
    
    -- Metadata
    created_by VARCHAR(255) DEFAULT 'system',
    error_message TEXT NULL,
    
    INDEX idx_status (status),
    INDEX idx_created_at (created_at),
    INDEX idx_complexity (complexity_level)
) ENGINE=InnoDB;

-- Workflow executions table
CREATE TABLE IF NOT EXISTS workflow_executions (
    id VARCHAR(36) PRIMARY KEY,
    project_id VARCHAR(36) NOT NULL,
    workflow_type VARCHAR(100) NOT NULL,
    component_category VARCHAR(100) NOT NULL,
    status ENUM('queued', 'running', 'completed', 'failed', 'cancelled') DEFAULT 'queued',
    parameters JSON,
    result JSON,
    error_message TEXT NULL,
    execution_time_ms INT NULL,
    started_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    completed_at TIMESTAMP NULL,
    timeout_seconds INT DEFAULT 300,
    retry_count INT DEFAULT 0,
    max_retries INT DEFAULT 3,
    
    FOREIGN KEY (project_id) REFERENCES projects(id) ON DELETE CASCADE,
    INDEX idx_project_status (project_id, status),
    INDEX idx_workflow_type (workflow_type),
    INDEX idx_component_category (component_category),
    INDEX idx_started_at (started_at)
) ENGINE=InnoDB;

-- Validation results table
CREATE TABLE IF NOT EXISTS validation_results (
    id VARCHAR(36) PRIMARY KEY,
    project_id VARCHAR(36) NOT NULL,
    execution_id VARCHAR(36) NULL,
    validation_type VARCHAR(100) NOT NULL,
    overall_valid BOOLEAN NOT NULL DEFAULT FALSE,
    validation_results JSON NOT NULL,
    task_result JSON,
    expected_behavior JSON,
    confidence_score DECIMAL(3,2) DEFAULT 0.00,
    timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    validation_time_ms INT NULL,
    
    FOREIGN KEY (project_id) REFERENCES projects(id) ON DELETE CASCADE,
    FOREIGN KEY (execution_id) REFERENCES workflow_executions(id) ON DELETE SET NULL,
    INDEX idx_project_validation (project_id, validation_type),
    INDEX idx_overall_valid (overall_valid),
    INDEX idx_timestamp (timestamp)
) ENGINE=InnoDB;

-- ============================================================================
-- RPA Component Management
-- ============================================================================

-- RPA components registry
CREATE TABLE IF NOT EXISTS rpa_components (
    id VARCHAR(36) PRIMARY KEY,
    name VARCHAR(100) NOT NULL UNIQUE,
    category ENUM('ui_testing', 'api_testing', 'data_processing', 'ai_processing', 'system_automation') NOT NULL,
    description TEXT,
    version VARCHAR(20) DEFAULT '1.0.0',
    capabilities JSON,
    configuration_schema JSON,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    
    INDEX idx_category (category),
    INDEX idx_active (is_active),
    INDEX idx_name (name)
) ENGINE=InnoDB;

-- Component usage tracking
CREATE TABLE IF NOT EXISTS component_usage (
    id VARCHAR(36) PRIMARY KEY,
    component_name VARCHAR(100) NOT NULL,
    project_id VARCHAR(36) NOT NULL,
    execution_id VARCHAR(36) NULL,
    usage_count INT DEFAULT 1,
    success_count INT DEFAULT 0,
    failure_count INT DEFAULT 0,
    avg_execution_time_ms DECIMAL(10,2) DEFAULT 0.00,
    last_used_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    FOREIGN KEY (project_id) REFERENCES projects(id) ON DELETE CASCADE,
    FOREIGN KEY (execution_id) REFERENCES workflow_executions(id) ON DELETE SET NULL,
    INDEX idx_component_project (component_name, project_id),
    INDEX idx_last_used (last_used_at),
    UNIQUE KEY unique_component_project (component_name, project_id)
) ENGINE=InnoDB;

-- ============================================================================
-- Background Tasks and Queue Management
-- ============================================================================

-- Background tasks queue
CREATE TABLE IF NOT EXISTS background_tasks (
    id VARCHAR(36) PRIMARY KEY,
    task_type VARCHAR(100) NOT NULL,
    task_name VARCHAR(255) NOT NULL,
    project_id VARCHAR(36) NULL,
    status ENUM('pending', 'running', 'completed', 'failed', 'cancelled') DEFAULT 'pending',
    priority INT DEFAULT 5,
    parameters JSON,
    result JSON,
    error_message TEXT NULL,
    progress_percentage INT DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    started_at TIMESTAMP NULL,
    completed_at TIMESTAMP NULL,
    retry_count INT DEFAULT 0,
    max_retries INT DEFAULT 3,
    timeout_seconds INT DEFAULT 600,
    
    FOREIGN KEY (project_id) REFERENCES projects(id) ON DELETE CASCADE,
    INDEX idx_status_priority (status, priority),
    INDEX idx_task_type (task_type),
    INDEX idx_created_at (created_at),
    INDEX idx_project_id (project_id)
) ENGINE=InnoDB;

-- ============================================================================
-- System Monitoring and Health
-- ============================================================================

-- System health metrics
CREATE TABLE IF NOT EXISTS system_health (
    id VARCHAR(36) PRIMARY KEY,
    service_name VARCHAR(100) NOT NULL,
    status ENUM('healthy', 'degraded', 'unhealthy') NOT NULL,
    response_time_ms DECIMAL(10,2),
    cpu_usage_percent DECIMAL(5,2),
    memory_usage_percent DECIMAL(5,2),
    disk_usage_percent DECIMAL(5,2),
    active_connections INT DEFAULT 0,
    error_rate_percent DECIMAL(5,2) DEFAULT 0.00,
    last_check_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    metadata JSON,
    
    INDEX idx_service_status (service_name, status),
    INDEX idx_last_check (last_check_at)
) ENGINE=InnoDB;

-- API request logs
CREATE TABLE IF NOT EXISTS api_requests (
    id VARCHAR(36) PRIMARY KEY,
    endpoint VARCHAR(255) NOT NULL,
    method VARCHAR(10) NOT NULL,
    status_code INT NOT NULL,
    response_time_ms DECIMAL(10,2),
    request_size_bytes INT DEFAULT 0,
    response_size_bytes INT DEFAULT 0,
    user_agent VARCHAR(500),
    ip_address VARCHAR(45),
    project_id VARCHAR(36) NULL,
    error_message TEXT NULL,
    timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    FOREIGN KEY (project_id) REFERENCES projects(id) ON DELETE SET NULL,
    INDEX idx_endpoint_method (endpoint, method),
    INDEX idx_status_code (status_code),
    INDEX idx_timestamp (timestamp),
    INDEX idx_project_id (project_id)
) ENGINE=InnoDB;

-- ============================================================================
-- Configuration and Settings
-- ============================================================================

-- System configuration
CREATE TABLE IF NOT EXISTS system_config (
    id VARCHAR(36) PRIMARY KEY,
    config_key VARCHAR(100) NOT NULL UNIQUE,
    config_value JSON NOT NULL,
    description TEXT,
    is_sensitive BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    updated_by VARCHAR(255) DEFAULT 'system',
    
    INDEX idx_config_key (config_key)
) ENGINE=InnoDB;

-- ============================================================================
-- Indexes for Performance Optimization
-- ============================================================================

-- Composite indexes for common queries
CREATE INDEX idx_projects_status_created ON projects(status, created_at);
CREATE INDEX idx_executions_project_status_started ON workflow_executions(project_id, status, started_at);
CREATE INDEX idx_validations_project_timestamp ON validation_results(project_id, timestamp);
CREATE INDEX idx_tasks_status_priority_created ON background_tasks(status, priority, created_at);
CREATE INDEX idx_health_service_check ON system_health(service_name, last_check_at);
CREATE INDEX idx_requests_endpoint_timestamp ON api_requests(endpoint, timestamp);

-- ============================================================================
-- Views for Common Queries
-- ============================================================================

-- Project summary view
CREATE OR REPLACE VIEW project_summary AS
SELECT 
    p.id,
    p.name,
    p.status,
    p.complexity_level,
    p.created_at,
    p.updated_at,
    COUNT(DISTINCT we.id) as total_executions,
    COUNT(DISTINCT CASE WHEN we.status = 'completed' THEN we.id END) as completed_executions,
    COUNT(DISTINCT CASE WHEN we.status = 'failed' THEN we.id END) as failed_executions,
    COUNT(DISTINCT vr.id) as total_validations,
    COUNT(DISTINCT CASE WHEN vr.overall_valid = TRUE THEN vr.id END) as passed_validations,
    AVG(vr.confidence_score) as avg_confidence_score
FROM projects p
LEFT JOIN workflow_executions we ON p.id = we.project_id
LEFT JOIN validation_results vr ON p.id = vr.project_id
GROUP BY p.id, p.name, p.status, p.complexity_level, p.created_at, p.updated_at;

-- Component performance view
CREATE OR REPLACE VIEW component_performance AS
SELECT 
    rc.name,
    rc.category,
    COALESCE(cu.usage_count, 0) as total_usage,
    COALESCE(cu.success_count, 0) as success_count,
    COALESCE(cu.failure_count, 0) as failure_count,
    CASE 
        WHEN COALESCE(cu.usage_count, 0) > 0 
        THEN ROUND((COALESCE(cu.success_count, 0) * 100.0) / cu.usage_count, 2)
        ELSE 0 
    END as success_rate_percent,
    COALESCE(cu.avg_execution_time_ms, 0) as avg_execution_time_ms,
    cu.last_used_at
FROM rpa_components rc
LEFT JOIN (
    SELECT 
        component_name,
        SUM(usage_count) as usage_count,
        SUM(success_count) as success_count,
        SUM(failure_count) as failure_count,
        AVG(avg_execution_time_ms) as avg_execution_time_ms,
        MAX(last_used_at) as last_used_at
    FROM component_usage
    GROUP BY component_name
) cu ON rc.name = cu.component_name
WHERE rc.is_active = TRUE;

-- ============================================================================
-- Triggers for Audit and Maintenance
-- ============================================================================

-- Update project status based on executions
DELIMITER //
CREATE TRIGGER update_project_status_after_execution
    AFTER UPDATE ON workflow_executions
    FOR EACH ROW
BEGIN
    IF NEW.status = 'completed' AND OLD.status != 'completed' THEN
        -- Check if all executions for this project are completed
        IF NOT EXISTS (
            SELECT 1 FROM workflow_executions 
            WHERE project_id = NEW.project_id 
            AND status IN ('queued', 'running')
        ) THEN
            UPDATE projects 
            SET status = 'ready', updated_at = CURRENT_TIMESTAMP 
            WHERE id = NEW.project_id AND status = 'executing';
        END IF;
    END IF;
END//
DELIMITER ;

-- Clean up old API request logs (keep last 30 days)
DELIMITER //
CREATE EVENT IF NOT EXISTS cleanup_old_api_requests
ON SCHEDULE EVERY 1 DAY
STARTS CURRENT_TIMESTAMP
DO
BEGIN
    DELETE FROM api_requests 
    WHERE timestamp < DATE_SUB(NOW(), INTERVAL 30 DAY);
END//
DELIMITER ;

-- Clean up old system health records (keep last 7 days)
DELIMITER //
CREATE EVENT IF NOT EXISTS cleanup_old_health_records
ON SCHEDULE EVERY 1 DAY
STARTS CURRENT_TIMESTAMP
DO
BEGIN
    DELETE FROM system_health 
    WHERE last_check_at < DATE_SUB(NOW(), INTERVAL 7 DAY);
END//
DELIMITER ;

-- Enable event scheduler
SET GLOBAL event_scheduler = ON;
