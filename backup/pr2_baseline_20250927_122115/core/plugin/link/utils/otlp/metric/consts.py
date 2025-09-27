"""OTLP metric constants and descriptors.

Defines metric names, constants, and descriptions for OpenTelemetry (OTLP) telemetry
data collection. Includes constants for tracking server request metrics,
performance data, and service monitoring.
"""

# Server request error count - error code
SERVER_REQUEST_TOTAL = "server_request_total"
# Outbound error count - error code
RELY_SERVER_REQUEST = "rely_server_request"
# Server request performance - latency
SERVER_REQUEST_TIME = "server_request_time"
SERVER_REQUEST_TIME_MICROSECONDS = "server_request_time_microseconds"

# Server request performance - latency at app ID level
SERVER_APPID_REQUEST_TIME = "server_appid_request_time"
# Outbound performance - latency
RELY_SERVER_REQUEST_TIME = "rely_server_request_time"
# Server request traffic - concurrency
SERVER_CONC = "server_conc"
# Outbound traffic - concurrency
RELY_SERVER_CONC = "rely_server_conc"


SERVER_REQUEST_DESC = "Server request error count"
RELY_SERVER_REQUEST_DESC = "Server outbound error count"
SERVER_REQUEST_TIME_DESC = "Server request performance"
RELY_SERVER_REQUEST_TIME_DESC = "Server outbound performance"
SERVER_CONC_DESC = "Server request concurrency count"
RELY_SERVER_CONC_DESC = "Server outbound concurrency count"
