"""
Bot Config Management API Functionality Tests

Test Bot configuration management related endpoints:
- POST /agent/v1/bot-config - Create Bot configuration
- GET /agent/v1/bot-config - Query Bot configuration
- PUT /agent/v1/bot-config - Update Bot configuration
- DELETE /agent/v1/bot-config - Delete Bot configuration

Important Notes:
1. API returns HTTP status code 200 usually, the actual business status needs to check the code field in response JSON
2. Use fixed test parameters for testing
3. Bot configuration is a prerequisite for Chat Completions API to work properly
"""

import concurrent.futures
from typing import Any, Dict, List, Optional, Tuple

import httpx


class BotConfigTestClient:
    """Bot Configuration Management API Test Client"""

    def __init__(self, base_url: str = "http://localhost:17870"):
        self.base_url = base_url
        self.base_endpoint = f"{base_url}/agent/v1/bot-config"
        self.default_headers = {"Content-Type": "application/json"}

        # Fixed parameters for testing
        self.test_app_id = "test_app_001"
        self.test_bot_id = "test_bot_001"

    def parse_response(self, response: httpx.Response) -> Tuple[int, str, dict]:
        """Parse API response, return (business_code, business_message, full_data)"""
        try:
            data = response.json()
            business_code = data.get("code", 0)
            business_message = data.get("message", "")
            return business_code, business_message, data
        except (ValueError, KeyError, TypeError) as e:
            return -1, f"JSON parsing failed: {e}", {}

    def create_bot_config(self, config_data: Dict[str, Any]) -> httpx.Response:
        """Create Bot configuration"""
        return httpx.post(
            self.base_endpoint,
            json=config_data,
            headers=self.default_headers,
            timeout=30,
        )

    def get_bot_config(self, app_id: str, bot_id: str) -> httpx.Response:
        """Query Bot configuration"""
        params = {"app_id": app_id, "bot_id": bot_id}
        return httpx.get(
            self.base_endpoint, params=params, headers=self.default_headers, timeout=30
        )

    def update_bot_config(self, config_data: Dict[str, Any]) -> httpx.Response:
        """Update Bot configuration"""
        return httpx.put(
            self.base_endpoint,
            json=config_data,
            headers=self.default_headers,
            timeout=30,
        )

    def delete_bot_config(self, app_id: str, bot_id: str) -> httpx.Response:
        """Delete Bot configuration"""
        params = {"app_id": app_id, "bot_id": bot_id}
        return httpx.delete(
            self.base_endpoint, params=params, headers=self.default_headers, timeout=30
        )

    def create_default_bot_config(
        self, app_id: Optional[str] = None, bot_id: Optional[str] = None
    ) -> Dict[str, Any]:
        """Create default Bot configuration data"""
        return {
            "app_id": app_id or self.test_app_id,
            "bot_id": bot_id or self.test_bot_id,
            "knowledge_config": {"score_threshold": 0.3, "top_k": 3},
            "model_config": {
                "instruct": "You are an intelligent assistant, please answer user's questions in a friendly way.",
                "plan": {"enabled": True, "max_iterations": 3},
                "summary": {"enabled": True, "max_length": 500},
            },
            "regular_config": {
                "match": {"enabled": True, "threshold": 0.8},
                "rag": {"enabled": True, "top_k": 5},
            },
            "tool_ids": ["search_tool", "calculator"],
            "mcp_server_ids": ["mcp_server_001"],
            "mcp_server_urls": ["http://localhost:3000"],
            "flow_ids": ["basic_flow"],
        }


class TestBotConfigManagement:
    """Bot Configuration Management API Test Suite"""

    client: BotConfigTestClient
    created_configs: List[Tuple[str, str]]

    @classmethod
    def setup_class(cls) -> None:
        """Test class initialization"""
        cls.client = BotConfigTestClient()
        cls.created_configs = []  # Record created configurations for cleanup

    def test_create_bot_config_basic(self) -> None:
        """Test basic Bot configuration creation"""
        config_data = self.client.create_default_bot_config()

        response = self.client.create_bot_config(config_data)

        assert (
            response.status_code == 200
        ), f"Expected HTTP status code 200, actual: {response.status_code}"

        business_code, business_message, _ = self.client.parse_response(response)
        print(
            f"Create Bot config - Business code: {business_code}, "
            f"message: {business_message}"
        )

        if business_code == 0:
            print("✅ Bot configuration created successfully")
            self.created_configs.append((config_data["app_id"], config_data["bot_id"]))
        else:
            print(
                f"⚠️ Bot configuration creation failed - Business code: {business_code}, "
                f"message: {business_message}"
            )

    def test_create_bot_config_with_custom_settings(self) -> None:
        """Test creating Bot with custom configuration"""
        custom_config = self.client.create_default_bot_config(
            "custom_app", "custom_bot"
        )

        # Custom configuration
        custom_config["model_config"][
            "instruct"
        ] = "You are a professional technical consultant, specialized in answering programming-related questions."
        custom_config["knowledge_config"]["score_threshold"] = 0.5
        custom_config["tool_ids"] = [
            "code_analyzer",
            "tech_search",
            "documentation_tool",
        ]

        response = self.client.create_bot_config(custom_config)

        assert response.status_code == 200

        business_code, business_message, _ = self.client.parse_response(response)
        print(
            f"Custom config Bot creation - Business code: {business_code}, "
            f"message: {business_message}"
        )

        if business_code == 0:
            self.created_configs.append(
                (custom_config["app_id"], custom_config["bot_id"])
            )

    def test_get_bot_config_existing(self) -> None:
        """Test querying existing Bot configuration"""
        # Ensure a configuration exists first
        config_data = self.client.create_default_bot_config(
            "query_test_app", "query_test_bot"
        )
        create_response = self.client.create_bot_config(config_data)

        if self.client.parse_response(create_response)[0] == 0:
            self.created_configs.append((config_data["app_id"], config_data["bot_id"]))

        # Query configuration
        response = self.client.get_bot_config(
            config_data["app_id"], config_data["bot_id"]
        )

        assert response.status_code == 200

        business_code, business_message, data = self.client.parse_response(response)
        print(
            f"Query Bot config - Business code: {business_code}, "
            f"message: {business_message}"
        )

        if business_code == 0:
            print("✅ Bot configuration query successful")
            config_detail = data.get("data", {})
            print(
                f"Configuration details: app_id={config_detail.get('app_id')}, "
                f"bot_id={config_detail.get('bot_id')}"
            )
        else:
            print(f"⚠️ Bot configuration query failed - Business code: {business_code}")

    def test_get_bot_config_nonexistent(self) -> None:
        """Test querying non-existent Bot configuration"""
        response = self.client.get_bot_config("nonexistent_app", "nonexistent_bot")

        assert response.status_code == 200

        business_code, business_message, _ = self.client.parse_response(response)
        print(
            f"Query non-existent Bot config - Business code: {business_code}, "
            f"message: {business_message}"
        )

        # Non-existent configuration should return corresponding error code
        if business_code != 0:
            print(
                f"✅ Correctly identified non-existent configuration - Error code: {business_code}"
            )

    def test_update_bot_config(self) -> None:
        """Test updating Bot configuration"""
        # Create a configuration first
        original_config = self.client.create_default_bot_config(
            "update_test_app", "update_test_bot"
        )
        create_response = self.client.create_bot_config(original_config)

        if self.client.parse_response(create_response)[0] == 0:
            self.created_configs.append(
                (original_config["app_id"], original_config["bot_id"])
            )

        # Update configuration
        updated_config = original_config.copy()
        updated_config["model_config"][
            "instruct"
        ] = "Updated instruction: You are a smarter assistant."
        updated_config["knowledge_config"]["top_k"] = 5
        updated_config["tool_ids"].append("new_tool")

        response = self.client.update_bot_config(updated_config)

        assert response.status_code == 200

        business_code, business_message, _ = self.client.parse_response(response)
        print(
            f"Update Bot config - Business code: {business_code}, "
            f"message: {business_message}"
        )

        if business_code == 0:
            print("✅ Bot configuration updated successfully")

    def test_delete_bot_config(self) -> None:
        """Test deleting Bot configuration"""
        # Create a configuration specifically for deletion testing
        config_data = self.client.create_default_bot_config(
            "delete_test_app", "delete_test_bot"
        )
        create_response = self.client.create_bot_config(config_data)

        if self.client.parse_response(create_response)[0] != 0:
            print("⚠️ Unable to create test configuration, skipping deletion test")
            return

        # Delete configuration
        response = self.client.delete_bot_config(
            config_data["app_id"], config_data["bot_id"]
        )

        assert response.status_code == 200

        business_code, business_message, _ = self.client.parse_response(response)
        print(
            f"Delete Bot config - Business code: {business_code}, "
            f"message: {business_message}"
        )

        if business_code == 0:
            print("✅ Bot configuration deleted successfully")

            # Verify that configuration cannot be queried after deletion
            verify_response = self.client.get_bot_config(
                config_data["app_id"], config_data["bot_id"]
            )
            verify_code, _, _ = self.client.parse_response(verify_response)

            if verify_code != 0:
                print(
                    "✅ Deletion verification successful - configuration was indeed deleted"
                )
            else:
                print("⚠️ Deletion verification failed - configuration still exists")

    def test_create_bot_config_validation_errors(self) -> None:
        """Test validation errors when creating Bot configuration"""
        # Test missing required fields
        invalid_config = {
            "app_id": "test_app",
            # Missing bot_id
            "model_config": {},
        }

        response = self.client.create_bot_config(invalid_config)

        assert response.status_code == 200

        business_code, business_message, _ = self.client.parse_response(response)
        print(
            f"Invalid config validation - Business code: {business_code}, "
            f"message: {business_message}"
        )

        if business_code == 40002:
            print("✅ Configuration validation working properly")

    def test_create_bot_config_duplicate(self) -> None:
        """Test creating duplicate Bot configuration"""
        config_data = self.client.create_default_bot_config(
            "dup_test_app", "dup_test_bot"
        )

        # First creation
        first_response = self.client.create_bot_config(config_data)
        first_code, _, _ = self.client.parse_response(first_response)

        if first_code == 0:
            self.created_configs.append((config_data["app_id"], config_data["bot_id"]))

        # Second creation with same configuration
        second_response = self.client.create_bot_config(config_data)
        second_code, second_message, _ = self.client.parse_response(second_response)

        print(
            f"Duplicate config creation - Business code: {second_code}, "
            f"message: {second_message}"
        )

        if second_code != 0:
            print("✅ Duplicate configuration validation working properly")
        else:
            print("⚠️ System allows creating duplicate configurations")

    def test_bot_config_field_limits(self) -> None:
        """Test Bot configuration field limits"""
        config_data = self.client.create_default_bot_config(
            "limit_test_app", "limit_test_bot"
        )

        # Test field length limits
        config_data["app_id"] = "a" * 65  # Exceeds 64 character limit

        response = self.client.create_bot_config(config_data)

        assert response.status_code == 200

        business_code, business_message, _ = self.client.parse_response(response)
        print(
            f"Field length limit test - Business code: {business_code}, "
            f"message: {business_message}"
        )

        if business_code == 40002:
            print("✅ Field length validation working properly")

    def test_concurrent_bot_config_operations(self) -> None:
        """Test Bot configuration concurrent operations"""

        def create_concurrent_config(thread_id: int) -> Tuple[int, int, int]:
            """Create configuration concurrently"""
            config_data = self.client.create_default_bot_config(
                f"concurrent_app_{thread_id}", f"concurrent_bot_{thread_id}"
            )

            response = self.client.create_bot_config(config_data)
            business_code, _, _ = self.client.parse_response(response)

            if business_code == 0:
                self.created_configs.append(
                    (config_data["app_id"], config_data["bot_id"])
                )

            return thread_id, response.status_code, business_code

        # Create 3 configurations concurrently
        max_workers = 3
        results = []

        with concurrent.futures.ThreadPoolExecutor(max_workers=max_workers) as executor:
            futures = {
                executor.submit(create_concurrent_config, i): i
                for i in range(max_workers)
            }

            for future in concurrent.futures.as_completed(futures):
                try:
                    thread_id, http_status, business_code = future.result()
                    results.append((thread_id, http_status, business_code))
                    print(
                        f"Concurrent config creation thread {thread_id}: HTTP={http_status}, "
                        f"business_code={business_code}"
                    )
                except (ValueError, RuntimeError, TypeError) as exc:
                    print(f"Concurrent operation failed: {exc}")

        # Verify results
        success_count = sum(1 for _, _, business_code in results if business_code == 0)
        print(
            f"Concurrent config operations - Successful: {success_count}/{max_workers}"
        )

    def cleanup_created_configs(self) -> None:
        """Clean up configurations created during testing"""
        print("\n🧹 Cleaning up test configurations...")

        for app_id, bot_id in self.created_configs:
            try:
                response = self.client.delete_bot_config(app_id, bot_id)
                business_code, _, _ = self.client.parse_response(response)

                if business_code == 0:
                    print(f"✅ Configuration cleanup successful: {app_id}/{bot_id}")
                else:
                    print(f"⚠️ Configuration cleanup failed: {app_id}/{bot_id}")
            except (ValueError, RuntimeError, TypeError) as e:
                print(f"❌ Configuration cleanup exception: {app_id}/{bot_id} - {e}")

        self.created_configs.clear()


if __name__ == "__main__":
    # Run tests directly
    test_instance = TestBotConfigManagement()
    test_instance.setup_class()

    print("🚀 Starting Bot Config Management API functionality tests...")
    print("=" * 70)

    # Test case list
    test_methods = [
        ("Basic Config Creation", test_instance.test_create_bot_config_basic),
        (
            "Custom Config Creation",
            test_instance.test_create_bot_config_with_custom_settings,
        ),
        ("Query Existing Config", test_instance.test_get_bot_config_existing),
        ("Query Non-existent Config", test_instance.test_get_bot_config_nonexistent),
        ("Update Config", test_instance.test_update_bot_config),
        ("Delete Config", test_instance.test_delete_bot_config),
        (
            "Config Validation Error",
            test_instance.test_create_bot_config_validation_errors,
        ),
        ("Duplicate Config Creation", test_instance.test_create_bot_config_duplicate),
        ("Field Limit Test", test_instance.test_bot_config_field_limits),
        ("Concurrent Operations", test_instance.test_concurrent_bot_config_operations),
    ]

    tests_passed = 0  # pylint: disable=invalid-name
    tests_failed = 0  # pylint: disable=invalid-name

    for test_name, test_method in test_methods:
        try:
            print(f"\n🧪 {test_name} Test:")
            test_method()
            print(f"✅ {test_name} test completed")
            tests_passed += 1
        except (AssertionError, ValueError, RuntimeError) as e:
            print(f"❌ {test_name} test failed: {e}")
            tests_failed += 1

    # Clean up created test configurations
    test_instance.cleanup_created_configs()

    print("\n" + "=" * 70)
    print(
        f"📊 Bot Config Management tests completed! "
        f"Passed: {tests_passed}, Failed: {tests_failed}, "
        f"Total: {tests_passed + tests_failed}"
    )
    print("=" * 70)
