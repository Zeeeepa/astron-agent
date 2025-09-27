-- Astron-Agent RPA Integration Seed Data
-- Initial data for development and testing

USE astron_unified;

-- ============================================================================
-- RPA Components Seed Data (25 components across 5 categories)
-- ============================================================================

-- UI Testing Components
INSERT INTO rpa_components (id, name, category, description, version, capabilities, configuration_schema, is_active) VALUES
(UUID(), 'rpabrowser', 'ui_testing', 'Browser automation and web interaction component', '1.0.0', 
 JSON_OBJECT(
   'supports_headless', true,
   'browsers', JSON_ARRAY('chromium', 'firefox', 'webkit'),
   'actions', JSON_ARRAY('click', 'type', 'navigate', 'screenshot', 'wait'),
   'selectors', JSON_ARRAY('css', 'xpath', 'text', 'role')
 ),
 JSON_OBJECT(
   'headless', JSON_OBJECT('type', 'boolean', 'default', true),
   'timeout', JSON_OBJECT('type', 'integer', 'default', 30000),
   'viewport', JSON_OBJECT('type', 'object', 'properties', JSON_OBJECT('width', 1920, 'height', 1080))
 ), true),

(UUID(), 'rpacv', 'ui_testing', 'Computer vision and image recognition component', '1.0.0',
 JSON_OBJECT(
   'image_recognition', true,
   'ocr_support', true,
   'template_matching', true,
   'formats', JSON_ARRAY('png', 'jpg', 'bmp', 'tiff')
 ),
 JSON_OBJECT(
   'confidence_threshold', JSON_OBJECT('type', 'number', 'default', 0.8),
   'ocr_language', JSON_OBJECT('type', 'string', 'default', 'eng'),
   'preprocessing', JSON_OBJECT('type', 'boolean', 'default', true)
 ), true),

(UUID(), 'rpawindow', 'ui_testing', 'Desktop window and application automation', '1.0.0',
 JSON_OBJECT(
   'window_management', true,
   'keyboard_input', true,
   'mouse_control', true,
   'process_control', true
 ),
 JSON_OBJECT(
   'window_title_match', JSON_OBJECT('type', 'string', 'default', 'exact'),
   'input_delay', JSON_OBJECT('type', 'integer', 'default', 100),
   'screenshot_on_action', JSON_OBJECT('type', 'boolean', 'default', false)
 ), true);

-- API Testing Components
INSERT INTO rpa_components (id, name, category, description, version, capabilities, configuration_schema, is_active) VALUES
(UUID(), 'rpanetwork', 'api_testing', 'Network requests and HTTP client component', '1.0.0',
 JSON_OBJECT(
   'http_methods', JSON_ARRAY('GET', 'POST', 'PUT', 'DELETE', 'PATCH', 'HEAD', 'OPTIONS'),
   'authentication', JSON_ARRAY('basic', 'bearer', 'api_key', 'oauth2'),
   'formats', JSON_ARRAY('json', 'xml', 'form-data', 'text'),
   'ssl_verification', true
 ),
 JSON_OBJECT(
   'timeout', JSON_OBJECT('type', 'integer', 'default', 30),
   'retries', JSON_OBJECT('type', 'integer', 'default', 3),
   'verify_ssl', JSON_OBJECT('type', 'boolean', 'default', true),
   'follow_redirects', JSON_OBJECT('type', 'boolean', 'default', true)
 ), true),

(UUID(), 'rpaopenapi', 'api_testing', 'OpenAPI specification testing and validation', '1.0.0',
 JSON_OBJECT(
   'spec_validation', true,
   'contract_testing', true,
   'schema_validation', true,
   'response_validation', true
 ),
 JSON_OBJECT(
   'spec_url', JSON_OBJECT('type', 'string', 'required', true),
   'validate_responses', JSON_OBJECT('type', 'boolean', 'default', true),
   'strict_mode', JSON_OBJECT('type', 'boolean', 'default', false)
 ), true);

-- Data Processing Components
INSERT INTO rpa_components (id, name, category, description, version, capabilities, configuration_schema, is_active) VALUES
(UUID(), 'rpadatabase', 'data_processing', 'Database operations and SQL execution', '1.0.0',
 JSON_OBJECT(
   'databases', JSON_ARRAY('mysql', 'postgresql', 'sqlite', 'mongodb'),
   'operations', JSON_ARRAY('select', 'insert', 'update', 'delete', 'bulk_operations'),
   'transactions', true,
   'connection_pooling', true
 ),
 JSON_OBJECT(
   'connection_string', JSON_OBJECT('type', 'string', 'required', true),
   'pool_size', JSON_OBJECT('type', 'integer', 'default', 5),
   'timeout', JSON_OBJECT('type', 'integer', 'default', 30)
 ), true),

(UUID(), 'rpaexcel', 'data_processing', 'Excel file processing and manipulation', '1.0.0',
 JSON_OBJECT(
   'formats', JSON_ARRAY('xlsx', 'xls', 'csv'),
   'operations', JSON_ARRAY('read', 'write', 'format', 'calculate', 'chart'),
   'formulas', true,
   'pivot_tables', true
 ),
 JSON_OBJECT(
   'read_only', JSON_OBJECT('type', 'boolean', 'default', false),
   'preserve_formatting', JSON_OBJECT('type', 'boolean', 'default', true),
   'calculate_formulas', JSON_OBJECT('type', 'boolean', 'default', true)
 ), true),

(UUID(), 'rpapdf', 'data_processing', 'PDF document processing and extraction', '1.0.0',
 JSON_OBJECT(
   'operations', JSON_ARRAY('read', 'extract_text', 'extract_images', 'merge', 'split'),
   'ocr_support', true,
   'form_filling', true,
   'digital_signatures', true
 ),
 JSON_OBJECT(
   'ocr_enabled', JSON_OBJECT('type', 'boolean', 'default', false),
   'extract_images', JSON_OBJECT('type', 'boolean', 'default', false),
   'preserve_layout', JSON_OBJECT('type', 'boolean', 'default', true)
 ), true),

(UUID(), 'rpadocx', 'data_processing', 'Word document processing and generation', '1.0.0',
 JSON_OBJECT(
   'operations', JSON_ARRAY('read', 'write', 'format', 'template', 'convert'),
   'formats', JSON_ARRAY('docx', 'doc', 'rtf', 'txt'),
   'templates', true,
   'mail_merge', true
 ),
 JSON_OBJECT(
   'preserve_formatting', JSON_OBJECT('type', 'boolean', 'default', true),
   'track_changes', JSON_OBJECT('type', 'boolean', 'default', false),
   'auto_save', JSON_OBJECT('type', 'boolean', 'default', true)
 ), true);

-- AI Processing Components
INSERT INTO rpa_components (id, name, category, description, version, capabilities, configuration_schema, is_active) VALUES
(UUID(), 'rpaai', 'ai_processing', 'AI-powered analysis and decision making', '1.0.0',
 JSON_OBJECT(
   'models', JSON_ARRAY('gpt-4', 'claude-3', 'gemini-pro'),
   'tasks', JSON_ARRAY('text_analysis', 'code_review', 'decision_making', 'classification'),
   'multimodal', true,
   'fine_tuning', true
 ),
 JSON_OBJECT(
   'model', JSON_OBJECT('type', 'string', 'default', 'gpt-4'),
   'temperature', JSON_OBJECT('type', 'number', 'default', 0.7),
   'max_tokens', JSON_OBJECT('type', 'integer', 'default', 2000),
   'timeout', JSON_OBJECT('type', 'integer', 'default', 60)
 ), true),

(UUID(), 'rpaverifycode', 'ai_processing', 'Code verification and quality analysis', '1.0.0',
 JSON_OBJECT(
   'languages', JSON_ARRAY('python', 'javascript', 'java', 'go', 'rust', 'typescript'),
   'checks', JSON_ARRAY('syntax', 'security', 'performance', 'best_practices'),
   'static_analysis', true,
   'vulnerability_scanning', true
 ),
 JSON_OBJECT(
   'language', JSON_OBJECT('type', 'string', 'required', true),
   'check_level', JSON_OBJECT('type', 'string', 'default', 'standard'),
   'include_suggestions', JSON_OBJECT('type', 'boolean', 'default', true)
 ), true);

-- System Automation Components
INSERT INTO rpa_components (id, name, category, description, version, capabilities, configuration_schema, is_active) VALUES
(UUID(), 'rpasystem', 'system_automation', 'System operations and process management', '1.0.0',
 JSON_OBJECT(
   'operations', JSON_ARRAY('file_ops', 'process_control', 'service_management', 'monitoring'),
   'platforms', JSON_ARRAY('linux', 'windows', 'macos'),
   'remote_execution', true,
   'scheduling', true
 ),
 JSON_OBJECT(
   'platform', JSON_OBJECT('type', 'string', 'default', 'linux'),
   'timeout', JSON_OBJECT('type', 'integer', 'default', 300),
   'retry_on_failure', JSON_OBJECT('type', 'boolean', 'default', true)
 ), true),

(UUID(), 'rpaencrypt', 'system_automation', 'Encryption and security operations', '1.0.0',
 JSON_OBJECT(
   'algorithms', JSON_ARRAY('AES', 'RSA', 'ChaCha20', 'Argon2'),
   'operations', JSON_ARRAY('encrypt', 'decrypt', 'hash', 'sign', 'verify'),
   'key_management', true,
   'secure_storage', true
 ),
 JSON_OBJECT(
   'algorithm', JSON_OBJECT('type', 'string', 'default', 'AES'),
   'key_size', JSON_OBJECT('type', 'integer', 'default', 256),
   'secure_delete', JSON_OBJECT('type', 'boolean', 'default', true)
 ), true),

(UUID(), 'rpaemail', 'system_automation', 'Email processing and automation', '1.0.0',
 JSON_OBJECT(
   'protocols', JSON_ARRAY('SMTP', 'IMAP', 'POP3'),
   'operations', JSON_ARRAY('send', 'receive', 'parse', 'filter', 'archive'),
   'attachments', true,
   'templates', true
 ),
 JSON_OBJECT(
   'server', JSON_OBJECT('type', 'string', 'required', true),
   'port', JSON_OBJECT('type', 'integer', 'default', 587),
   'use_tls', JSON_OBJECT('type', 'boolean', 'default', true),
   'timeout', JSON_OBJECT('type', 'integer', 'default', 30)
 ), true),

(UUID(), 'rpaenterprise', 'system_automation', 'Enterprise integration and workflow', '1.0.0',
 JSON_OBJECT(
   'integrations', JSON_ARRAY('sap', 'salesforce', 'jira', 'confluence', 'slack'),
   'workflows', true,
   'approval_processes', true,
   'audit_logging', true
 ),
 JSON_OBJECT(
   'integration_type', JSON_OBJECT('type', 'string', 'required', true),
   'api_version', JSON_OBJECT('type', 'string', 'default', 'latest'),
   'batch_size', JSON_OBJECT('type', 'integer', 'default', 100)
 ), true);

-- ============================================================================
-- System Configuration Seed Data
-- ============================================================================

INSERT INTO system_config (id, config_key, config_value, description, is_sensitive) VALUES
(UUID(), 'rpa.default_timeout', JSON_OBJECT('value', 300), 'Default timeout for RPA operations in seconds', false),
(UUID(), 'rpa.max_concurrent_workflows', JSON_OBJECT('value', 5), 'Maximum number of concurrent workflow executions', false),
(UUID(), 'rpa.retry_attempts', JSON_OBJECT('value', 3), 'Default number of retry attempts for failed operations', false),
(UUID(), 'rpa.confidence_threshold', JSON_OBJECT('value', 0.8), 'Minimum confidence threshold for validation', false),
(UUID(), 'system.health_check_interval', JSON_OBJECT('value', 30), 'Health check interval in seconds', false),
(UUID(), 'system.log_retention_days', JSON_OBJECT('value', 30), 'Number of days to retain system logs', false),
(UUID(), 'api.rate_limit_per_minute', JSON_OBJECT('value', 100), 'API rate limit per minute per client', false),
(UUID(), 'monitoring.metrics_enabled', JSON_OBJECT('value', true), 'Enable system metrics collection', false);

-- ============================================================================
-- Sample Project Data for Testing
-- ============================================================================

-- Sample project for testing
INSERT INTO projects (id, name, prd_content, project_config, status, complexity_level, rpa_service_url, created_by) VALUES
(UUID(), 'Sample E-Commerce Platform', 
 'Build a comprehensive e-commerce platform with user authentication, product catalog, shopping cart, payment integration, and admin dashboard. The system should support multiple payment methods, inventory management, order tracking, and customer support features.',
 JSON_OBJECT(
   'target_platform', 'web',
   'technologies', JSON_ARRAY('React', 'Node.js', 'MySQL', 'Redis'),
   'deployment', 'docker',
   'testing_required', true,
   'performance_requirements', JSON_OBJECT('response_time', '< 200ms', 'concurrent_users', 1000)
 ),
 'ready',
 'comprehensive',
 'http://astron-rpa:8020',
 'system');

-- Sample background task
INSERT INTO background_tasks (id, task_type, task_name, status, priority, parameters) VALUES
(UUID(), 'prd_processing', 'Process Sample E-Commerce PRD', 'completed', 1,
 JSON_OBJECT(
   'prd_length', 500,
   'complexity_indicators', JSON_ARRAY('authentication', 'payments', 'inventory', 'admin'),
   'estimated_components', 15
 ));

-- ============================================================================
-- System Health Initial Data
-- ============================================================================

INSERT INTO system_health (id, service_name, status, response_time_ms, cpu_usage_percent, memory_usage_percent, active_connections) VALUES
(UUID(), 'astron-agent', 'healthy', 45.2, 15.5, 32.1, 5),
(UUID(), 'astron-rpa-openapi', 'healthy', 38.7, 12.3, 28.9, 3),
(UUID(), 'astron-rpa-engine', 'healthy', 52.1, 18.2, 35.4, 2),
(UUID(), 'mysql', 'healthy', 12.5, 8.1, 45.2, 8),
(UUID(), 'redis-cluster', 'healthy', 3.2, 5.5, 15.8, 12);

-- ============================================================================
-- Component Usage Statistics (Sample Data)
-- ============================================================================

-- Get the project ID for sample data
SET @sample_project_id = (SELECT id FROM projects WHERE name = 'Sample E-Commerce Platform' LIMIT 1);

INSERT INTO component_usage (id, component_name, project_id, usage_count, success_count, failure_count, avg_execution_time_ms) VALUES
(UUID(), 'rpabrowser', @sample_project_id, 25, 23, 2, 1250.5),
(UUID(), 'rpanetwork', @sample_project_id, 18, 18, 0, 340.2),
(UUID(), 'rpadatabase', @sample_project_id, 12, 11, 1, 85.7),
(UUID(), 'rpaai', @sample_project_id, 8, 7, 1, 2150.3),
(UUID(), 'rpaverifycode', @sample_project_id, 15, 14, 1, 890.1);

-- ============================================================================
-- Validation and Verification
-- ============================================================================

-- Verify all components are inserted
SELECT 
    category,
    COUNT(*) as component_count,
    GROUP_CONCAT(name ORDER BY name) as components
FROM rpa_components 
WHERE is_active = TRUE 
GROUP BY category 
ORDER BY category;

-- Verify system configuration
SELECT config_key, JSON_EXTRACT(config_value, '$.value') as value, description 
FROM system_config 
ORDER BY config_key;

-- Show project summary
SELECT * FROM project_summary;

-- Show component performance
SELECT * FROM component_performance ORDER BY success_rate_percent DESC;

-- Final verification message
SELECT 
    'Database seed completed successfully!' as message,
    (SELECT COUNT(*) FROM rpa_components WHERE is_active = TRUE) as total_components,
    (SELECT COUNT(*) FROM projects) as total_projects,
    (SELECT COUNT(*) FROM system_config) as config_entries,
    NOW() as seeded_at;
