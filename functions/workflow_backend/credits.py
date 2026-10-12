from __future__ import annotations

from typing import Any, Iterable

from .constants import (
    CREDIT_FREE_CATEGORIES,
    HELP_EARNED_CREDITS,
    REQUEST_CREDIT_COST,
    STARTING_HELP_CREDITS,
)

__all__ = ['REQUEST_CREDIT_COST', 'help_credit_summary', 'is_credit_free_request']

_CLOSED_REQUEST_STATUSES = {'completed', 'canceled'}


def is_credit_free_request(request: dict[str, Any]) -> bool:
    return str(request.get('category', '')).strip() in CREDIT_FREE_CATEGORIES


def help_credit_summary(
    user_id: str, requests: Iterable[dict[str, Any]]
) -> dict[str, int]:
    """Derives a user's help credits from the request history.

    Every account starts with STARTING_HELP_CREDITS. An open request holds
    REQUEST_CREDIT_COST, a completed one spends it, and a canceled or deleted
    one releases it. Completing help for someone else earns
    HELP_EARNED_CREDITS, with no upper limit.
    """
    earned = 0
    spent = 0
    held = 0
    for request in requests:
        status = str(request.get('status', '')).strip()
        if request.get('acceptedHelperId') == user_id and status == 'completed':
            earned += HELP_EARNED_CREDITS
        if request.get('requesterId') != user_id or is_credit_free_request(request):
            continue
        if status == 'completed' and request.get('acceptedHelperId'):
            spent += REQUEST_CREDIT_COST
        elif status not in _CLOSED_REQUEST_STATUSES:
            held += REQUEST_CREDIT_COST

    balance = STARTING_HELP_CREDITS + earned - spent
    return {
        'starting': STARTING_HELP_CREDITS,
        'earned': earned,
        'spent': spent,
        'held': held,
        'balance': balance,
        'available': balance - held,
    }
