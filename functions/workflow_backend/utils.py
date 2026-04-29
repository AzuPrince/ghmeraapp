from __future__ import annotations

import copy
from datetime import datetime, timezone
from typing import Any


def _as_map(value: Any) -> dict[str, Any]:
    if not isinstance(value, dict):
        return {}
    return {str(key): copy.deepcopy(item) for key, item in value.items()}


def _as_map_list(value: Any) -> list[dict[str, Any]]:
    if not isinstance(value, list):
        return []

    result: list[dict[str, Any]] = []
    for item in value:
        if isinstance(item, dict):
            result.append(_as_map(item))
    return result


def _copy_string_list(value: Any) -> list[str]:
    if not isinstance(value, list):
        return []
    return [str(item) for item in value]


def _now_iso() -> str:
    return datetime.now(timezone.utc).isoformat()


def _read_int(value: Any, fallback: int = 0) -> int:
    if isinstance(value, bool):
        return int(value)
    if isinstance(value, int):
        return value
    if isinstance(value, float):
        return int(value)
    try:
        return int(str(value))
    except (TypeError, ValueError):
        return fallback


def _read_float(value: Any, fallback: float = 0.0) -> float:
    if isinstance(value, (int, float)):
        return float(value)
    try:
        return float(str(value))
    except (TypeError, ValueError):
        return fallback


def _clamp_int(value: Any, minimum: int, maximum: int) -> int:
    return max(minimum, min(maximum, _read_int(value, minimum)))


def _first_name(full_name: Any) -> str:
    parts = str(full_name or '').strip().split()
    return parts[0] if parts else 'there'


def _normalize_text(value: Any) -> str:
    return str(value or '').strip().lower()