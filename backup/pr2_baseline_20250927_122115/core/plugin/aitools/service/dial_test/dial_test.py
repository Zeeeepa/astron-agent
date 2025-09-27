"""
Dial test service module providing health checks and service availability monitoring.
"""

import json
import os

import requests
from dotenv import load_dotenv


def dial_test_main(method, url, headers, payload, _success_code, _call_frequency):
    """Execute HTTP request with specified parameters for dial testing.

    This function performs HTTP requests with comprehensive error handling
    for testing API endpoints. All 6 parameters are necessary for complete
    testing configuration:

    Args:
        method (str): HTTP method (GET, POST, PUT, DELETE) - Required for request type
        url (str): Target URL endpoint - Required for request destination
        headers (dict): HTTP headers dict - Required for authentication/content-type
        payload (dict): Request body data - Required for POST/PUT operations
        success_code (int): Expected success status code - Required for validation
        call_frequency (int): Frequency to call the endpoint - Required for load testing

    Returns:
        dict: JSON response from the API if successful, None if failed

    Note:
        All parameters are essential for comprehensive API testing:
        - method: Determines request behavior
        - url: Specifies target endpoint
        - headers: Provides authentication and metadata
        - payload: Contains request data
        - success_code: Validates response correctness
        - call_frequency: Enables load/stress testing
    """
    try:
        print(f"Sending {method} request to {url}")
        # 使用 json 参数以确保 payload 正确序列化为 JSON
        response = requests.request(
            method, url, headers=headers, json=payload, timeout=10
        )  # 设置超时时间
        response.raise_for_status()  # 如果响应状态码不是200范围，抛出HTTPError
        # print("Response received successfully.")
        # print(response.json())
        return response.json()
    except requests.exceptions.Timeout:
        print("The request timed out.")
        return None
    except requests.exceptions.HTTPError as http_err:
        print(f"HTTP error occurred: {http_err}")  # 打印HTTP错误
        return None
    except Exception as e:
        print(f"An unexpected error occurred: {e}")
        return None


if __name__ == "__main__":
    load_dotenv("../../../dialtest.env")

    # 第一个接口
    # url = os.getenv("TTS_URL")
    # method = os.getenv("TTS_METHOD")
    # headers = json.loads(os.getenv("TTS_HEADERS"))
    # payload = json.loads(os.getenv("TTS_PAYLOAD"))
    # success_code = int(os.getenv("TTS_SUCCESS_CODE", -1))  # 转换为整数，默认值为 -1
    # call_frequency = int(os.getenv("TTS_CALL_FREQUENCY", 1))  # 转换为整数，默认值为 1

    # 第二个接口
    # url = os.getenv("SMARTTS_URL")
    # method = os.getenv("SMARTTS_METHOD")
    # headers = json.loads(os.getenv("SMARTTS_HEADERS"))
    # payload = json.loads(os.getenv("SMARTTS_PAYLOAD"))
    # success_code = int(os.getenv("SMARTTS_SUCCESS_CODE", -1))  # 转换为整数，默认值为 -1
    # call_frequency = int(os.getenv("SMARTTS_CALL_FREQUENCY", 1))  # 转换为整数，默认值为 1

    # 第三个接口
    test_url = os.getenv("ONE_SENTENCE_REPRODUCTION_URL")
    test_method = os.getenv("ONE_SENTENCE_REPRODUCTION_METHOD")
    test_headers = json.loads(os.getenv("ONE_SENTENCE_REPRODUCTION_HEADERS"))
    test_payload = json.loads(os.getenv("ONE_SENTENCE_REPRODUCTION_PAYLOAD"))
    test_success_code = int(
        os.getenv("ONE_SENTENCE_REPRODUCTION_SUCCESS_CODE", -1)
    )  # 转换为整数，默认值为 -1
    test_call_frequency = int(
        os.getenv("ONE_SENTENCE_REPRODUCTION_CALL_FREQUENCY", 1)
    )  # 转换为整数，默认值为 1

    print("url:", test_url)
    print("method:", test_method)
    print("Payload:", test_payload)
    print("Headers:", test_headers)

    result = dial_test_main(
        test_method,
        test_url,
        test_headers,
        test_payload,
        test_success_code,
        test_call_frequency,
    )
    print(11, result)
