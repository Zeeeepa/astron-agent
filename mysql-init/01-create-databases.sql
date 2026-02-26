-- ============================================================================
-- MySQL Database Initialization for Unified Deployment
-- Creates all required databases for both astron-agent and astron-rpa
-- ============================================================================

-- Create databases for astron-rpa services
CREATE DATABASE IF NOT EXISTS `casdoor` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE DATABASE IF NOT EXISTS `rpa_ai` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE DATABASE IF NOT EXISTS `rpa_openapi` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE DATABASE IF NOT EXISTS `rpa_resource` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE DATABASE IF NOT EXISTS `rpa_robot` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- Create databases for astron-agent services
CREATE DATABASE IF NOT EXISTS `agent` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE DATABASE IF NOT EXISTS `rpa_plugin` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE DATABASE IF NOT EXISTS `knowledge` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE DATABASE IF NOT EXISTS `memory` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE DATABASE IF NOT EXISTS `tenant` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE DATABASE IF NOT EXISTS `workflow` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE DATABASE IF NOT EXISTS `astron_console` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- Create users and grant permissions
CREATE USER IF NOT EXISTS 'rpa_user'@'%' IDENTIFIED BY 'RpaUser123!';
CREATE USER IF NOT EXISTS 'agent_user'@'%' IDENTIFIED BY 'AgentUser123!';

-- Grant permissions for RPA services
GRANT ALL PRIVILEGES ON `casdoor`.* TO 'rpa_user'@'%';
GRANT ALL PRIVILEGES ON `rpa_ai`.* TO 'rpa_user'@'%';
GRANT ALL PRIVILEGES ON `rpa_openapi`.* TO 'rpa_user'@'%';
GRANT ALL PRIVILEGES ON `rpa_resource`.* TO 'rpa_user'@'%';
GRANT ALL PRIVILEGES ON `rpa_robot`.* TO 'rpa_user'@'%';

-- Grant permissions for Agent services
GRANT ALL PRIVILEGES ON `agent`.* TO 'agent_user'@'%';
GRANT ALL PRIVILEGES ON `rpa_plugin`.* TO 'agent_user'@'%';
GRANT ALL PRIVILEGES ON `knowledge`.* TO 'agent_user'@'%';
GRANT ALL PRIVILEGES ON `memory`.* TO 'agent_user'@'%';
GRANT ALL PRIVILEGES ON `tenant`.* TO 'agent_user'@'%';
GRANT ALL PRIVILEGES ON `workflow`.* TO 'agent_user'@'%';
GRANT ALL PRIVILEGES ON `astron_console`.* TO 'agent_user'@'%';

-- Grant root access to all databases
GRANT ALL PRIVILEGES ON *.* TO 'root'@'%';

FLUSH PRIVILEGES;

-- ============================================================================
-- Create initial tables for RPA Plugin integration
-- ============================================================================

USE `rpa_plugin`;

-- RPA Task tracking table
CREATE TABLE IF NOT EXISTS `rpa_tasks` (
    `id` BIGINT AUTO_INCREMENT PRIMARY KEY,
    `task_id` VARCHAR(255) NOT NULL UNIQUE,
    `project_id` VARCHAR(255) NOT NULL,
    `exec_position` VARCHAR(255),
    `params` JSON,
    `status` ENUM('pending', 'running', 'completed', 'failed', 'timeout') DEFAULT 'pending',
    `result` JSON,
    `error_message` TEXT,
    `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    `completed_at` TIMESTAMP NULL,
    INDEX `idx_task_id` (`task_id`),
    INDEX `idx_project_id` (`project_id`),
    INDEX `idx_status` (`status`),
    INDEX `idx_created_at` (`created_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- RPA API access logs
CREATE TABLE IF NOT EXISTS `rpa_api_logs` (
    `id` BIGINT AUTO_INCREMENT PRIMARY KEY,
    `task_id` VARCHAR(255),
    `api_endpoint` VARCHAR(500) NOT NULL,
    `http_method` VARCHAR(10) NOT NULL,
    `request_payload` JSON,
    `response_payload` JSON,
    `status_code` INT,
    `response_time_ms` INT,
    `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX `idx_task_id` (`task_id`),
    INDEX `idx_api_endpoint` (`api_endpoint`),
    INDEX `idx_created_at` (`created_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- RPA service health monitoring
CREATE TABLE IF NOT EXISTS `rpa_service_health` (
    `id` BIGINT AUTO_INCREMENT PRIMARY KEY,
    `service_name` VARCHAR(100) NOT NULL,
    `service_url` VARCHAR(500) NOT NULL,
    `status` ENUM('healthy', 'unhealthy', 'unknown') DEFAULT 'unknown',
    `response_time_ms` INT,
    `last_check_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    `error_message` TEXT,
    UNIQUE KEY `unique_service` (`service_name`),
    INDEX `idx_service_name` (`service_name`),
    INDEX `idx_status` (`status`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Insert initial RPA service health records
INSERT INTO `rpa_service_health` (`service_name`, `service_url`, `status`) VALUES
('ai-service', 'http://rpa-ai-service:8010', 'unknown'),
('openapi-service', 'http://rpa-openapi-service:8020', 'unknown'),
('resource-service', 'http://rpa-resource-service:8030', 'unknown'),
('robot-service', 'http://rpa-robot-service:8040', 'unknown')
ON DUPLICATE KEY UPDATE 
    `service_url` = VALUES(`service_url`),
    `last_check_at` = CURRENT_TIMESTAMP;

-- ============================================================================
-- Create initial configuration tables
-- ============================================================================

USE `astron_console`;

-- System configuration table
CREATE TABLE IF NOT EXISTS `system_config` (
    `id` BIGINT AUTO_INCREMENT PRIMARY KEY,
    `config_key` VARCHAR(255) NOT NULL UNIQUE,
    `config_value` TEXT,
    `config_type` ENUM('string', 'number', 'boolean', 'json') DEFAULT 'string',
    `description` TEXT,
    `is_encrypted` BOOLEAN DEFAULT FALSE,
    `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    INDEX `idx_config_key` (`config_key`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Insert initial system configuration
INSERT INTO `system_config` (`config_key`, `config_value`, `config_type`, `description`) VALUES
('rpa.integration.enabled', 'true', 'boolean', 'Enable RPA platform integration'),
('rpa.api.base_url', 'http://rpa-openapi-service:8020', 'string', 'Base URL for RPA API services'),
('rpa.frontend.url', 'http://localhost:32742', 'string', 'RPA frontend URL for user access'),
('agent.api.base_url', 'http://agent-core-agent:17870', 'string', 'Base URL for Agent API services'),
('agent.frontend.url', 'http://localhost:1881', 'string', 'Agent console frontend URL'),
('system.deployment.mode', 'unified', 'string', 'Deployment mode: unified, standalone, or distributed'),
('system.version', '1.0.0', 'string', 'System version'),
('monitoring.enabled', 'true', 'boolean', 'Enable system monitoring and health checks')
ON DUPLICATE KEY UPDATE 
    `config_value` = VALUES(`config_value`),
    `updated_at` = CURRENT_TIMESTAMP;

-- Service registry table
CREATE TABLE IF NOT EXISTS `service_registry` (
    `id` BIGINT AUTO_INCREMENT PRIMARY KEY,
    `service_name` VARCHAR(100) NOT NULL,
    `service_type` ENUM('rpa', 'agent', 'infrastructure', 'frontend') NOT NULL,
    `service_url` VARCHAR(500) NOT NULL,
    `health_check_url` VARCHAR(500),
    `status` ENUM('active', 'inactive', 'maintenance') DEFAULT 'active',
    `version` VARCHAR(50),
    `description` TEXT,
    `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    UNIQUE KEY `unique_service_name` (`service_name`),
    INDEX `idx_service_type` (`service_type`),
    INDEX `idx_status` (`status`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Insert service registry entries
INSERT INTO `service_registry` (`service_name`, `service_type`, `service_url`, `health_check_url`, `description`) VALUES
-- RPA Services
('rpa-ai-service', 'rpa', 'http://rpa-ai-service:8010', 'http://rpa-ai-service:8010/health', 'RPA AI processing service'),
('rpa-openapi-service', 'rpa', 'http://rpa-openapi-service:8020', 'http://rpa-openapi-service:8020/health', 'RPA OpenAPI gateway service'),
('rpa-resource-service', 'rpa', 'http://rpa-resource-service:8030', 'http://rpa-resource-service:8030/health', 'RPA resource management service'),
('rpa-robot-service', 'rpa', 'http://rpa-robot-service:8040', 'http://rpa-robot-service:8040/health', 'RPA robot execution service'),
('rpa-frontend', 'frontend', 'http://rpa-frontend:80', 'http://rpa-frontend:80', 'RPA web interface'),
-- Agent Services
('agent-core-agent', 'agent', 'http://agent-core-agent:17870', 'http://agent-core-agent:17870/health', 'Core agent service'),
('agent-core-rpa', 'agent', 'http://agent-core-rpa:8003', 'http://agent-core-rpa:8003/health', 'Agent RPA plugin service'),
('agent-core-knowledge', 'agent', 'http://agent-core-knowledge:7881', 'http://agent-core-knowledge:7881/health', 'Agent knowledge service'),
('agent-core-memory', 'agent', 'http://agent-core-memory:7882', 'http://agent-core-memory:7882/health', 'Agent memory service'),
('agent-core-tenant', 'agent', 'http://agent-core-tenant:7883', 'http://agent-core-tenant:7883/health', 'Agent tenant service'),
('agent-core-workflow', 'agent', 'http://agent-core-workflow:7880', 'http://agent-core-workflow:7880/health', 'Agent workflow service'),
('agent-console-frontend', 'frontend', 'http://agent-console-frontend:1881', 'http://agent-console-frontend:1881', 'Agent console web interface'),
('agent-console-hub', 'agent', 'http://agent-console-hub:8080', 'http://agent-console-hub:8080/health', 'Agent console backend service'),
-- Infrastructure Services
('mysql', 'infrastructure', 'mysql:3306', NULL, 'MySQL database server'),
('redis', 'infrastructure', 'redis:6379', NULL, 'Redis cache server'),
('minio', 'infrastructure', 'minio:9000', 'http://minio:9000/minio/health/live', 'MinIO object storage'),
('postgres', 'infrastructure', 'postgres:5432', NULL, 'PostgreSQL database server'),
('elasticsearch', 'infrastructure', 'elasticsearch:9200', 'http://elasticsearch:9200/_cluster/health', 'Elasticsearch search engine'),
('kafka', 'infrastructure', 'kafka:29092', NULL, 'Apache Kafka message broker')
ON DUPLICATE KEY UPDATE 
    `service_url` = VALUES(`service_url`),
    `health_check_url` = VALUES(`health_check_url`),
    `description` = VALUES(`description`),
    `updated_at` = CURRENT_TIMESTAMP;

