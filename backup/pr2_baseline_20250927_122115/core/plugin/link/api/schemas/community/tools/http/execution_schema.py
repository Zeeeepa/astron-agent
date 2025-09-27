"""HTTP execution DTO definitions for community tools.

This module defines Pydantic data transfer objects (DTOs) used for HTTP-based
tool execution requests and responses within the community tools framework.
"""

from pydantic import BaseModel


class HttpRunHeader(BaseModel):
    """Header information for HTTP tool execution requests.

    Contains authentication and identification data required for tool execution.
    """

    app_id: str
    uid: str | None = None


class HttpRunParameter(BaseModel):
    """Parameters for HTTP tool execution.

    Specifies which tool, operation, and version to execute.
    """

    tool_id: str = None
    operation_id: str = None
    version: str = None


class HttpRunPayload(BaseModel):
    """Payload data for HTTP tool execution.

    Contains the actual message or data to be processed by the tool.
    """

    message: dict = None


class HttpRunRequest(BaseModel):
    """Complete HTTP tool execution request.

    Combines header, parameter, and payload information for tool execution.
    """

    header: HttpRunHeader = None
    parameter: HttpRunParameter = None
    payload: HttpRunPayload = None


class HttpRunResponseHeader(BaseModel):
    """Header information for HTTP tool execution responses.

    Contains response status, message, and session identifier.
    """

    code: int
    message: str
    sid: str


class HttpRunResponse(BaseModel):
    """Complete HTTP tool execution response.

    Contains both header information and the actual response payload.
    """

    header: HttpRunResponseHeader
    payload: dict


class ToolDebugRequest(BaseModel):
    """Request data for tool debugging operations.

    Contains HTTP request details and OpenAPI schema for debugging purposes.
    """

    server: str = None
    method: str = None
    path: dict = None
    query: dict = None
    header: dict = None
    body: dict = None
    openapi_schema: str = ""


class ToolDebugResponseHeader(BaseModel):
    """Header information for tool debugging responses.

    Contains debug operation status, message, and session identifier.
    """

    code: int
    message: str
    sid: str


class ToolDebugResponse(BaseModel):
    """Complete tool debugging response.

    Contains both header information and debugging payload data.
    """

    header: ToolDebugResponseHeader
    payload: dict
