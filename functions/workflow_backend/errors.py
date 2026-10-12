from __future__ import annotations

from typing import Any


class WorkflowError(Exception):
    def __init__(
        self,
        message: str,
        status_code: int = 400,
        database: dict[str, Any] | None = None,
    ):
        super().__init__(message)
        self.message = message
        self.status_code = status_code
        self.database = database
