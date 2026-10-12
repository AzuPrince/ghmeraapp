from __future__ import annotations

from typing import Any, Iterable

from .constants import (
    ASK_CREDIT_COST,
    CREDIT_FREE_CATEGORIES,
    HELP_EARNED_CREDITS,
    RECEIVE_CREDIT_COST,
    STARTING_HELP_CREDITS,
)

_CLOSED_REQUEST_STATUSES = {'completed', 'canceled'}
REQUEST_CREDIT_COST = ASK_CREDIT_COST + RECEIVE_CREDIT_COST


def is_credit_free_request(request: dict[str, Any]) -> bool:
    return str(request.get('category', '')).strip() in CREDIT_FREE_CATEGORIES


def help_credit_summary(
    user_id: str, requests: Iterable[dict[str, Any]]
) -> dict[str, int]:
    """Derives a user's help credits from the request history.

    Every account starts with STARTING_HELP_CREDITS. Asking and receiving are
    charged separately: an open request holds both charges, a completed one
    spends both, and a canceled or deleted one releases both. Completing help
    for someone else earns HELP_EARNED_CREDITS.
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
