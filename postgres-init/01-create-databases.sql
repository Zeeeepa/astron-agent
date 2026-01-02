-- ============================================================================
-- PostgreSQL Database Initialization for astron-agent
-- Creates databases and users for astron-agent services
-- ============================================================================

-- Create additional databases for astron-agent services
CREATE DATABASE agent_analytics;
CREATE DATABASE agent_logs;
CREATE DATABASE agent_metrics;

-- Create users for different services
CREATE USER agent_service WITH PASSWORD 'AgentService123!';
CREATE USER analytics_service WITH PASSWORD 'Analytics123!';
CREATE USER logs_service WITH PASSWORD 'Logs123!';

-- Grant permissions
GRANT ALL PRIVILEGES ON DATABASE sparkdb_manager TO agent_service;
GRANT ALL PRIVILEGES ON DATABASE agent_analytics TO analytics_service;
GRANT ALL PRIVILEGES ON DATABASE agent_logs TO logs_service;
GRANT ALL PRIVILEGES ON DATABASE agent_metrics TO agent_service;

-- Connect to sparkdb_manager and create initial schema
\c sparkdb_manager;

-- Create schema for agent core functionality
CREATE SCHEMA IF NOT EXISTS agent_core;
CREATE SCHEMA IF NOT EXISTS agent_plugins;
CREATE SCHEMA IF NOT EXISTS agent_workflows;

-- Grant schema permissions
GRANT ALL ON SCHEMA agent_core TO agent_service;
GRANT ALL ON SCHEMA agent_plugins TO agent_service;
GRANT ALL ON SCHEMA agent_workflows TO agent_service;

-- Create initial tables for agent core
CREATE TABLE IF NOT EXISTS agent_core.agents (
    id SERIAL PRIMARY KEY,
    agent_id VARCHAR(255) UNIQUE NOT NULL,
    name VARCHAR(255) NOT NULL,
    description TEXT,
    status VARCHAR(50) DEFAULT 'active',
    configuration JSONB,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS agent_core.agent_sessions (
    id SERIAL PRIMARY KEY,
    session_id VARCHAR(255) UNIQUE NOT NULL,
    agent_id VARCHAR(255) REFERENCES agent_core.agents(agent_id),
    status VARCHAR(50) DEFAULT 'active',
    metadata JSONB,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Create tables for plugin management
CREATE TABLE IF NOT EXISTS agent_plugins.plugin_registry (
    id SERIAL PRIMARY KEY,
    plugin_id VARCHAR(255) UNIQUE NOT NULL,
    plugin_name VARCHAR(255) NOT NULL,
    plugin_type VARCHAR(100) NOT NULL,
    version VARCHAR(50),
    status VARCHAR(50) DEFAULT 'active',
    configuration JSONB,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Insert RPA plugin registration
INSERT INTO agent_plugins.plugin_registry (
    plugin_id, plugin_name, plugin_type, version, configuration
) VALUES (
    'rpa-plugin-v1',
    'RPA Integration Plugin',
    'rpa',
    '1.0.0',
    '{
        "api_endpoints": {
            "task_create": "http://rpa-openapi-service:8020/api/v1/tasks/create",
            "task_query": "http://rpa-openapi-service:8020/api/v1/tasks",
            "ai_service": "http://rpa-ai-service:8010",
            "resource_service": "http://rpa-resource-service:8030",
            "robot_service": "http://rpa-robot-service:8040"
        },
        "authentication": {
            "type": "api_key",
            "api_key_header": "X-API-Key"
        },
        "timeout_settings": {
            "connection_timeout": 30,
            "read_timeout": 300,
            "task_monitoring_interval": 10
        }
    }'::jsonb
) ON CONFLICT (plugin_id) DO UPDATE SET
    configuration = EXCLUDED.configuration,
    updated_at = CURRENT_TIMESTAMP;

-- Create workflow tables
CREATE TABLE IF NOT EXISTS agent_workflows.workflows (
    id SERIAL PRIMARY KEY,
    workflow_id VARCHAR(255) UNIQUE NOT NULL,
    name VARCHAR(255) NOT NULL,
    description TEXT,
    definition JSONB NOT NULL,
    status VARCHAR(50) DEFAULT 'active',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS agent_workflows.workflow_executions (
    id SERIAL PRIMARY KEY,
    execution_id VARCHAR(255) UNIQUE NOT NULL,
    workflow_id VARCHAR(255) REFERENCES agent_workflows.workflows(workflow_id),
    status VARCHAR(50) DEFAULT 'pending',
    input_data JSONB,
    output_data JSONB,
    error_message TEXT,
    started_at TIMESTAMP,
    completed_at TIMESTAMP,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Create indexes for better performance
CREATE INDEX IF NOT EXISTS idx_agents_agent_id ON agent_core.agents(agent_id);
CREATE INDEX IF NOT EXISTS idx_agents_status ON agent_core.agents(status);
CREATE INDEX IF NOT EXISTS idx_sessions_agent_id ON agent_core.agent_sessions(agent_id);
CREATE INDEX IF NOT EXISTS idx_sessions_status ON agent_core.agent_sessions(status);
CREATE INDEX IF NOT EXISTS idx_plugins_type ON agent_plugins.plugin_registry(plugin_type);
CREATE INDEX IF NOT EXISTS idx_plugins_status ON agent_plugins.plugin_registry(status);
CREATE INDEX IF NOT EXISTS idx_workflows_status ON agent_workflows.workflows(status);
CREATE INDEX IF NOT EXISTS idx_executions_workflow_id ON agent_workflows.workflow_executions(workflow_id);
CREATE INDEX IF NOT EXISTS idx_executions_status ON agent_workflows.workflow_executions(status);

-- Connect to agent_analytics database
\c agent_analytics;

-- Create analytics tables
CREATE TABLE IF NOT EXISTS usage_metrics (
    id SERIAL PRIMARY KEY,
    metric_name VARCHAR(255) NOT NULL,
    metric_value NUMERIC,
    metric_type VARCHAR(100),
    tags JSONB,
    timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS performance_metrics (
    id SERIAL PRIMARY KEY,
    service_name VARCHAR(255) NOT NULL,
    endpoint VARCHAR(500),
    response_time_ms INTEGER,
    status_code INTEGER,
    error_message TEXT,
    timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Create indexes for analytics
CREATE INDEX IF NOT EXISTS idx_usage_metrics_name ON usage_metrics(metric_name);
CREATE INDEX IF NOT EXISTS idx_usage_metrics_timestamp ON usage_metrics(timestamp);
CREATE INDEX IF NOT EXISTS idx_performance_service ON performance_metrics(service_name);
CREATE INDEX IF NOT EXISTS idx_performance_timestamp ON performance_metrics(timestamp);

-- Connect to agent_logs database
\c agent_logs;

-- Create logging tables
CREATE TABLE IF NOT EXISTS application_logs (
    id SERIAL PRIMARY KEY,
    service_name VARCHAR(255) NOT NULL,
    log_level VARCHAR(50) NOT NULL,
    message TEXT NOT NULL,
    context JSONB,
    timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS audit_logs (
    id SERIAL PRIMARY KEY,
    user_id VARCHAR(255),
    action VARCHAR(255) NOT NULL,
    resource_type VARCHAR(255),
    resource_id VARCHAR(255),
    details JSONB,
    ip_address INET,
    user_agent TEXT,
    timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Create indexes for logs
CREATE INDEX IF NOT EXISTS idx_app_logs_service ON application_logs(service_name);
CREATE INDEX IF NOT EXISTS idx_app_logs_level ON application_logs(log_level);
CREATE INDEX IF NOT EXISTS idx_app_logs_timestamp ON application_logs(timestamp);
CREATE INDEX IF NOT EXISTS idx_audit_logs_user ON audit_logs(user_id);
CREATE INDEX IF NOT EXISTS idx_audit_logs_action ON audit_logs(action);
CREATE INDEX IF NOT EXISTS idx_audit_logs_timestamp ON audit_logs(timestamp);

