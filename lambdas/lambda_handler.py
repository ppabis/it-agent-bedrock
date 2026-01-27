import json
import os
import traceback
import boto3
from create_db_ticket import create_db_ticket, create_generic_ticket

JIRA_BASE_URL = os.getenv("JIRA_BASE_URL")
PROJECT_ID = os.getenv("JIRA_PROJECT_ID")
DB_ACCESS_ISSUE_TYPE_ID = os.getenv("DB_ACCESS_ISSUE_TYPE_ID")
GENERIC_ISSUE_TYPE_ID = os.getenv("GENERIC_ISSUE_TYPE_ID")
SECRET_ARN = os.getenv("JIRA_SECRET_ARN")

secretsmanager = boto3.client("secretsmanager")
secret = json.loads(secretsmanager.get_secret_value(SecretId=SECRET_ARN)["SecretString"])

def _parse_array_value(value):
    """Normalize values that represent arrays into a clean list of strings."""
    if value is None:
        return []
    if isinstance(value, list):
        return [item for item in value if item not in (None, "")]
    if isinstance(value, str):
        stripped = value.strip()
        if not stripped:
            return []
        if stripped.startswith("[") and stripped.endswith("]"):
            try:
                parsed = json.loads(stripped)
                if isinstance(parsed, list):
                    return [item for item in parsed if item not in (None, "")]
            except json.JSONDecodeError:
                inner = stripped[1:-1].strip()
                if not inner:
                    return []
                return [
                    item.strip().strip('"').strip("'")
                    for item in inner.split(",")
                    if item.strip()
                ]
        return [item.strip() for item in stripped.split(",") if item.strip()]
    return [value]


def _coerce_value(value, value_type: str):
    """Coerce a value to a specific type if needed (currently arrays only)."""
    if value_type == "array":
        return _parse_array_value(value)
    return value


def _parse_properties_list(properties: list) -> dict:
    """Parse Bedrock properties list into a flattened dictionary."""
    parsed = {}
    for prop in properties:
        name = prop.get("name")
        value = prop.get("value")
        value_type = prop.get("type")
        if not name:
            continue
        coerced = _coerce_value(value, value_type)
        if name in parsed:
            if not isinstance(parsed[name], list):
                parsed[name] = [parsed[name]]
            parsed[name].append(coerced)
        else:
            parsed[name] = coerced
    return parsed


def _parse_request_body(event: dict):
    """Extract structured JSON from various requestBody formats."""
    request_body = event.get("requestBody", {})
    content = request_body.get("content", {})
    application_json = content.get("application/json")
    if isinstance(application_json, dict):
        properties = application_json.get("properties")
        if isinstance(properties, list):
            return _parse_properties_list(properties)
        body = application_json.get("body")
        if isinstance(body, str):
            return json.loads(body)
        if isinstance(body, dict):
            return body
    body = request_body.get("body")
    if isinstance(body, str):
        return json.loads(body)
    if isinstance(body, dict):
        return body
    return None


def _parse_parameters_list(parameters: list) -> dict:
    """Parse Bedrock parameter lists into a dictionary similar to properties."""
    parsed = {}
    for param in parameters:
        name = param.get("name")
        value = param.get("value")
        value_type = param.get("type")
        if not name:
            continue
        coerced = _coerce_value(value, value_type)
        if name in parsed:
            if not isinstance(parsed[name], list):
                parsed[name] = [parsed[name]]
            parsed[name].append(coerced)
        else:
            parsed[name] = coerced
    return parsed


def _parse_tool_input(event: dict) -> dict:
    """Extract the tool input payload from several possible event shapes."""
    if "toolInput" in event:
        return event["toolInput"]
    if "input" in event and isinstance(event["input"], dict):
        return event["input"]
    if "arguments" in event:
        arguments = event["arguments"]
        return json.loads(arguments) if isinstance(arguments, str) else arguments
    if "requestBody" in event:
        parsed = _parse_request_body(event)
        if parsed is not None:
            return parsed
    if "parameters" in event and isinstance(event["parameters"], list):
        return _parse_parameters_list(event["parameters"])
    if "body" in event:
        return json.loads(event["body"]) if isinstance(event["body"], str) else event["body"]
    return event


def _missing_fields(tool_input: dict, required_fields: list) -> list:
    """Return list of required fields that are missing or empty."""
    missing = []
    for field in required_fields:
        value = tool_input.get(field)
        if value in (None, ""):
            missing.append(field)
            continue
        if isinstance(value, list) and not value:
            missing.append(field)
    return missing


def _normalize_db_ticket_input(tool_input: dict) -> dict:
    """Normalize db ticket input (e.g., ensure database_names is a list)."""
    normalized = dict(tool_input)
    if "database_names" in normalized:
        normalized["database_names"] = _parse_array_value(normalized["database_names"])
    return normalized


def _bedrock_agent_response(event: dict, status_code: int, body: dict) -> dict:
    """Wrap an HTTP response in the Bedrock agent response schema."""
    return {
        "messageVersion": "1.0",
        "response": {
            "actionGroup": event.get("actionGroup", "db-ticket-tools"),
            "apiPath": event.get("apiPath", "/db-ticket"),
            "httpMethod": event.get("httpMethod", "POST"),
            "httpStatusCode": status_code,
            "responseBody": {"application/json": {"body": json.dumps(body)}},
        },
    }


def route_db_ticket(event: dict) -> dict:
    """Handle db-ticket requests, validate input, and create Jira issues."""
    tool_input = _normalize_db_ticket_input(_parse_tool_input(event))
    missing_fields = _missing_fields(
        tool_input,
        [
            "summary",
            "database_names",
            "user_list",
            "permissions",
            "business_reason",
            "access_until",
        ],
    )
    if missing_fields:
        error_body = {"message": f"Missing required fields: {', '.join(missing_fields)}"}
        if "actionGroup" in event:
            return _bedrock_agent_response(event, 400, error_body)
        return {"statusCode": 400, "body": json.dumps(error_body)}
    try:
        response = create_db_ticket(
            base_url=JIRA_BASE_URL,
            project_id=PROJECT_ID,
            issue_type_id=DB_ACCESS_ISSUE_TYPE_ID,
            email=secret["username"],
            token=secret["password"],
            summary=tool_input["summary"],
            database_names=tool_input["database_names"],
            user_list=tool_input["user_list"],
            permissions=tool_input["permissions"],
            business_reason=tool_input["business_reason"],
            access_until=tool_input["access_until"],
            description=tool_input.get("description"),
        )
    except Exception as e:
        error_body = {"message": str(e)}
        print("Error creating DB ticket: " + json.dumps(error_body))
        print(traceback.format_exc())
        if "actionGroup" in event:
            return _bedrock_agent_response(event, 500, error_body)
        return {"statusCode": 500, "body": json.dumps(error_body)}
    
    print("Response: " + json.dumps(response))
    success_body = {"message": "Ticket created successfully with key: " + response["key"]}
    if "actionGroup" in event:
        return _bedrock_agent_response(event, 200, success_body)
    return {"statusCode": 200, "body": json.dumps(success_body)}


def route_generic_ticket(event: dict) -> dict:
    """Handle generic-ticket requests, validate input, and create Jira issues."""
    tool_input = _parse_tool_input(event)
    missing_fields = _missing_fields(tool_input, ["summary", "description"])
    if missing_fields:
        error_body = {"message": f"Missing required fields: {', '.join(missing_fields)}"}
        if "actionGroup" in event:
            return _bedrock_agent_response(event, 400, error_body)
        return {"statusCode": 400, "body": json.dumps(error_body)}
    try:
        response = create_generic_ticket(
            base_url=JIRA_BASE_URL,
            project_id=PROJECT_ID,
            issue_type_id=GENERIC_ISSUE_TYPE_ID,
            email=secret["username"],
            token=secret["password"],
            summary=tool_input["summary"],
            description=tool_input["description"],
        )
    except Exception as e:
        error_body = {"message": str(e)}
        if "actionGroup" in event:
            return _bedrock_agent_response(event, 500, error_body)
        return {"statusCode": 500, "body": json.dumps(error_body)}
    print("Response: " + json.dumps(response))
    success_body = {"message": "Ticket created successfully with key: " + response["key"]}
    if "actionGroup" in event:
        return _bedrock_agent_response(event, 200, success_body)
    return {"statusCode": 200, "body": json.dumps(success_body)}


def lambda_handler(event, context):
    """Entry point for the Lambda: route requests based on the API path."""
    print(json.dumps(event))
    api_path = event.get("apiPath") or event.get("path")
    if api_path == "/db-ticket":
        response = route_db_ticket(event)
        print(json.dumps(response))
        return response
    if api_path == "/generic-ticket":
        response = route_generic_ticket(event)
        print(json.dumps(response))
        return response
    error_body = {"message": f"Unsupported route: {api_path}"}
    if "actionGroup" in event:
        response = _bedrock_agent_response(event, 400, error_body)
        print(json.dumps(response))
        return response
    return {"statusCode": 400, "body": json.dumps(error_body)}
