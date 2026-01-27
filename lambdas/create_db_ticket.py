#!/usr/bin/env python3
import os, re, time
from typing import Dict, List, Optional, Union
import requests

def _adf_text(value: str) -> Dict[str, object]:
    return {
        "type": "doc",
        "version": 1,
        "content": [
            {
                "type": "paragraph",
                "content": [{"type": "text", "text": value}],
            }
        ],
    }


CACHED_DATABASE_NAMES_ALLOWED_VALUES = None
CACHED_DATABASE_NAMES_ALLOWED_VALUES_TIMESTAMP = None

def _get_database_names_allowed_values_raw(base_url: str, project_id: str, issue_type_id: str, email: str, token: str) -> List[Dict[str, object]]:
    """
    Fetch allowed values for the database_name field (customfield_10076).
    It is kept in cache so that we don't need to call it so often.
    """
    global CACHED_DATABASE_NAMES_ALLOWED_VALUES, CACHED_DATABASE_NAMES_ALLOWED_VALUES_TIMESTAMP
    if (
        CACHED_DATABASE_NAMES_ALLOWED_VALUES is not None
        and CACHED_DATABASE_NAMES_ALLOWED_VALUES_TIMESTAMP > time.time() - 60 * 30
    ): # 30 minutes caching
        return CACHED_DATABASE_NAMES_ALLOWED_VALUES
    response = requests.get(
        f"{base_url}/rest/api/3/issue/createmeta/{project_id}/issuetypes/{issue_type_id}",
        auth=(email, token),
        headers={"Content-Type": "application/json"},
        timeout=30,
    )
    try:
        response.raise_for_status()
    except requests.exceptions.HTTPError as e:
        print(f"Error getting database names allowed values: {e}")
        print(response.text)
        raise e
    fields = response.json().get("fields", {})
    if isinstance(fields, list):
        field = next(
            (
                item
                for item in fields
                if item.get("key") == "customfield_10076"
                or item.get("fieldId") == "customfield_10076"
            ),
            {},
        )
        allowed_values = field.get("allowedValues", [])
    else:
        allowed_values = fields.get("customfield_10076", {}).get("allowedValues", [])
    CACHED_DATABASE_NAMES_ALLOWED_VALUES = allowed_values
    CACHED_DATABASE_NAMES_ALLOWED_VALUES_TIMESTAMP = time.time()
    return allowed_values


def _get_database_names_allowed_values(base_url: str, project_id: str, issue_type_id: str, email: str, token: str) -> List[str]:
    """
    Get the allowed values for the database_name field (customfield_10076).
    """
    allowed_values = _get_database_names_allowed_values_raw(base_url, project_id, issue_type_id, email, token)
    return [value.get("value") for value in allowed_values if value.get("value")]


def get_database_name_id(base_url: str, project_id: str, issue_type_id: str, email: str, token: str, value: str) -> str:
    """
    Get the ID of an option in checkboxes list.
    """
    allowed_values = _get_database_names_allowed_values_raw(base_url, project_id, issue_type_id, email, token)
    for option in allowed_values:
        if option.get("value") == value:
            option_id = option.get("id")
            if option_id:
                return option_id
    raise ValueError(f"Database name '{value}' has no matching id.")


def _validate_user_list(user_list: str) -> str:
    """
    Validate the user list. It has to be in the format of firstname.lastname, line by line.
    """
    if not user_list:
        return "User list must be not empty"
    for user in user_list.split("\n"):
        if not re.match(r"^[a-z]+\.[a-z]+$", user):
            return f"User {user} is not in the correct format. It should be in the format of firstname.lastname"
    return None

def _validate_permissions(permissions: str) -> str:
    """
    Validate the permissions. It has to be in the format of db.table=SQL VERBS (e.g. accounts.users=SELECT,UPDATE,SHOW VIEW), line by line.
    """
    if not permissions:
        return "Permissions must be not empty"
    for permission in permissions.split("\n"):
        if not re.match(r"^[a-z*]+\.[a-z*]+=[A-Z,a-z ]+[A-Za-z]$", permission):
            return f"Permission {permission} is not in the correct format. It should be in the format of db.table=SQL VERBS (e.g. accounts.users=SELECT,UPDATE)"
    return None

def _validate_ticket(
    base_url: str,
    project_id: str,
    issue_type_id: str,
    email: str,
    token: str,
    database_names: List[str],
    user_list: str,
    permissions: str,
    business_reason: str,
    access_until: str,
):
    """
    Perform all validations on the new DB ticket.
    """
    allowed_values = _get_database_names_allowed_values(base_url, project_id, issue_type_id, email, token)
    errors = []
    if not all(name in allowed_values for name in database_names):
        errors.append(f"Database names are wrong. Allowed values: {', '.join(allowed_values)}")
    user_list_error = _validate_user_list(user_list)
    if user_list_error:
        errors.append(user_list_error)
    permissions_error = _validate_permissions(permissions)
    if permissions_error:
        errors.append(permissions_error)
    if not access_until or not re.match(r"^\d{4}-\d{2}-\d{2}$", access_until):
        errors.append("Access until must be a date in YYYY-MM-DD format")
    if errors:
        print("Validation errors: " + "\n".join(errors))
        raise ValueError("\n".join(errors))

def create_db_ticket(
    base_url: str,
    project_id: str,
    issue_type_id: str,
    email: str,
    token: str,
    summary: str,
    database_names: List[str],
    user_list: str,
    permissions: str,
    business_reason: str,
    access_until: str,
    description: Optional[str] = None,
) -> dict:
    """
    Create a Jira ticket for the DB access request issue type.

    Required fields are based on Jira create meta:
    - project, summary
    - customfield_10076 (database_name)
    - customfield_10039 (user_list)
    - customfield_10073 (permissions)
    - customfield_10074 (business reason)
    - customfield_10075 (access_until, YYYY-MM-DD)
    """
    _validate_ticket(
        base_url,
        project_id,
        issue_type_id,
        email,
        token,
        database_names,
        user_list,
        permissions,
        business_reason,
        access_until,
    )

    database_name_ids = [
        name if name.isdigit() else get_database_name_id(base_url, project_id, issue_type_id, email, token, name)
        for name in database_names
    ]

    database_field_value = [{"id": name_id} for name_id in database_name_ids]

    fields: dict = {
        "project": {"id": project_id},
        "issuetype": {"id": issue_type_id},
        "summary": summary,
        "customfield_10076": database_field_value,
        "customfield_10039": _adf_text(user_list),
        "customfield_10073": _adf_text(permissions),
        "customfield_10074": _adf_text(business_reason),
    }

    if description:
        fields["description"] = _adf_text(description)
    fields["customfield_10075"] = access_until

    response = requests.post(
        f"{base_url}/rest/api/3/issue",
        auth=(email, token),
        headers={"Content-Type": "application/json"},
        json={"fields": fields},
        timeout=30,
    )
    try:
        response.raise_for_status()
    except requests.exceptions.HTTPError as e:
        print(f"Error creating ticket: {e}")
        print(response.text)
        raise e
    return response.json()


def create_generic_ticket(
    base_url: str,
    project_id: str,
    issue_type_id: str,
    email: str,
    token: str,
    summary: str,
    description: str,
) -> dict:
    """
    Create a Jira ticket with a summary and description.
    """
    fields: dict = {
        "project": {"id": project_id},
        "issuetype": {"id": issue_type_id},
        "summary": summary,
        "description": _adf_text(description),
    }
    response = requests.post(
        f"{base_url}/rest/api/3/issue",
        auth=(email, token),
        headers={"Content-Type": "application/json"},
        json={"fields": fields},
        timeout=30,
    )
    try:
        response.raise_for_status()
    except requests.exceptions.HTTPError as e:
        print(f"Error creating ticket: {e}")
        print(response.text)
        raise e
    return response.json()
