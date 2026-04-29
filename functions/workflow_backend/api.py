from __future__ import annotations

from typing import Any

from .errors import WorkflowError
from .state import WorkflowState
from .utils import _as_map


def apply_workflow_operation(
    body: dict[str, Any],
) -> tuple[dict[str, Any], dict[str, Any] | None]:
    if not isinstance(body, dict):
        raise WorkflowError('Invalid workflow payload.')

    operation = str(body.get('operation', '')).strip()
    raw_database = _as_map(body.get('database'))
    current_user_id = str(body.get('currentUserId', '')).strip()
    payload = _as_map(body.get('payload'))

    if not operation:
        raise WorkflowError('Missing workflow operation.')
    if not raw_database:
        raise WorkflowError('Missing app-state database payload.')

    state = WorkflowState(
        raw_database=raw_database,
        current_user_id=current_user_id,
    )
    handler_name = {
        'create_help_request': 'create_help_request',
        'update_help_request': 'update_help_request',
        'delete_help_request': 'delete_help_request',
        'cancel_accepted_request': 'cancel_accepted_request',
        'request_helper_for_my_request': 'request_helper_for_my_request',
        'volunteer_for_help_request': 'volunteer_for_help_request',
        'start_request_work': 'start_request_work',
        'confirm_request_completion': 'confirm_request_completion',
        'submit_review_for_request': 'submit_review_for_request',
        'submit_participant_safety_report': 'submit_participant_safety_report',
        'report_user_account': 'report_user_account',
        'send_message': 'send_message',
    }.get(operation)

    if handler_name is None:
        raise WorkflowError(f'Unsupported workflow operation: {operation}')

    handler = getattr(state, handler_name)
    result = handler(payload)
    return state.to_raw_database(), result