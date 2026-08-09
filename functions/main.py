"""Ghmera - Firebase Cloud Functions (Python).

Includes custom SMTP email verification code sending and password reset features.
"""

from __future__ import annotations

from datetime import datetime, timedelta, timezone
from email.message import EmailMessage
from html import escape
import hashlib
import json
import logging
import os
import re
import secrets
import smtplib
import ssl
import sys
from pathlib import Path
from typing import Any

from firebase_admin import auth as admin_auth
from firebase_admin import firestore, initialize_app
from firebase_functions import https_fn, options, params

FUNCTIONS_ROOT = Path(__file__).resolve().parent
if str(FUNCTIONS_ROOT) not in sys.path:
    sys.path.insert(0, str(FUNCTIONS_ROOT))

from workflow_api import WorkflowError, apply_workflow_operation

initialize_app()

options.set_global_options(region="us-central1", max_instances=10)
logger = logging.getLogger(__name__)

EMAIL_CODE_COLLECTION = "_email_verification_codes"
EMAIL_CODE_TTL_MINUTES = 15
EMAIL_CODE_RESEND_COOLDOWN_SECONDS = 60
EMAIL_CODE_MAX_ATTEMPTS = 5
SMTP_PASSWORD = params.SecretParam("SMTP_PASSWORD")

DEFAULT_SMTP_HOST = "mail.peatechservice.com"
DEFAULT_SMTP_PORT = 465
DEFAULT_SMTP_USERNAME = "info@peatechservice.com"
DEFAULT_SMTP_FROM_EMAIL = "mail@peatechservice.com"
DEFAULT_SMTP_FROM_NAME = "PEATECH SERVICES LLC"


def _registration_code_ref(email: str):
    normalized_email = email.strip().lower()
    document_id = hashlib.sha256(
        f"registration:{normalized_email}".encode("utf-8")
    ).hexdigest()
    return firestore.client().collection(EMAIL_CODE_COLLECTION).document(
        document_id
    )


def _password_reset_code_ref(email: str):
    normalized_email = email.strip().lower()
    document_id = hashlib.sha256(
        f"password-reset:{normalized_email}".encode("utf-8")
    ).hexdigest()
    return firestore.client().collection(EMAIL_CODE_COLLECTION).document(
        document_id
    )


def _generate_email_code() -> str:
    return f"{secrets.randbelow(1_000_000):06d}"


def _hash_email_code(uid: str, code: str) -> str:
    return hashlib.sha256(f"{uid}:{code}".encode("utf-8")).hexdigest()


def _as_utc(dt: datetime | None) -> datetime | None:
    if dt is None:
        return None
    if dt.tzinfo is None:
        return dt.replace(tzinfo=timezone.utc)
    return dt.astimezone(timezone.utc)


def _normalize_email(email: str) -> str:
    return email.strip().lower()


def _require_email_value(value: Any) -> str:
    email = _normalize_email(str(value or ""))
    if len(email) > 254 or re.fullmatch(r"[^@\s]+@[^@\s]+\.[^@\s]+", email) is None:
        raise https_fn.HttpsError(
            code=https_fn.FunctionsErrorCode.INVALID_ARGUMENT,
            message="Enter a valid email address.",
        )
    return email


def _load_user_by_email(email: str):
    try:
        return admin_auth.get_user_by_email(email)
    except admin_auth.UserNotFoundError:
        return None
    except Exception:
        logger.exception("Unable to load Firebase Auth user for %s", email)
        raise https_fn.HttpsError(
            code=https_fn.FunctionsErrorCode.INTERNAL,
            message="Unable to check this account right now. Please try again.",
        )


def _verify_stored_code(*, doc_ref, code_identifier: str, code: str) -> dict[str, Any]:
    snap = doc_ref.get()
    if not snap.exists:
        raise https_fn.HttpsError(
            code=https_fn.FunctionsErrorCode.FAILED_PRECONDITION,
            message="Request a verification code first.",
        )

    now = datetime.now(timezone.utc)
    stored = snap.to_dict() or {}
    expires_at = _as_utc(stored.get("expiresAt"))
    if expires_at is None or now >= expires_at:
        doc_ref.delete()
        raise https_fn.HttpsError(
            code=https_fn.FunctionsErrorCode.DEADLINE_EXCEEDED,
            message="This verification code has expired. Request a new one.",
        )

    attempts_remaining = int(stored.get("attemptsRemaining") or 0)
    if attempts_remaining <= 0:
        doc_ref.delete()
        raise https_fn.HttpsError(
            code=https_fn.FunctionsErrorCode.RESOURCE_EXHAUSTED,
            message="Too many incorrect attempts. Request a new code.",
        )

    if stored.get("codeHash") != _hash_email_code(code_identifier, code):
        attempts_remaining -= 1
        if attempts_remaining <= 0:
            doc_ref.delete()
            raise https_fn.HttpsError(
                code=https_fn.FunctionsErrorCode.RESOURCE_EXHAUSTED,
                message="Too many incorrect attempts. Request a new code.",
            )

        doc_ref.set(
            {
                "attemptsRemaining": attempts_remaining,
                "lastAttemptAt": now,
                "updatedAt": firestore.SERVER_TIMESTAMP,
            },
            merge=True,
        )
        raise https_fn.HttpsError(
            code=https_fn.FunctionsErrorCode.INVALID_ARGUMENT,
            message=f"Incorrect verification code. {attempts_remaining} attempt(s) remaining.",
        )

    return stored


def _send_verification_code_email(
    *,
    to_email: str,
    display_name: str | None,
    code: str,
) -> None:
    smtp_host = os.environ.get("SMTP_HOST", DEFAULT_SMTP_HOST).strip()
    smtp_port = int(os.environ.get("SMTP_PORT", str(DEFAULT_SMTP_PORT)))
    smtp_username = os.environ.get("SMTP_USERNAME", DEFAULT_SMTP_USERNAME).strip()
    smtp_password = SMTP_PASSWORD.value.strip()
    from_email = (
        os.environ.get("SMTP_FROM_EMAIL", DEFAULT_SMTP_FROM_EMAIL).strip()
        or DEFAULT_SMTP_FROM_EMAIL
    )
    from_name = (
        os.environ.get("SMTP_FROM_NAME", DEFAULT_SMTP_FROM_NAME).strip()
        or DEFAULT_SMTP_FROM_NAME
    )
    smtp_use_ssl = os.environ.get("SMTP_USE_SSL", "true").lower() == "true"
    smtp_use_starttls = os.environ.get("SMTP_USE_STARTTLS", "false").lower() == "true"

    if not smtp_host or not smtp_username or not smtp_password or not from_email:
        logger.error("SMTP is not fully configured.")
        raise https_fn.HttpsError(
            code=https_fn.FunctionsErrorCode.FAILED_PRECONDITION,
            message="Verification email delivery is not configured.",
        )

    recipient_name = (display_name or "there").strip() or "there"
    escaped_recipient_name = escape(recipient_name)
    subject = "Your Ghmera verification code"
    text_body = (
        f"Hello {recipient_name},\n\n"
        f"Your Ghmera verification code is: {code}\n\n"
        f"Enter this code in the app to finish signing up. "
        f"The code expires in {EMAIL_CODE_TTL_MINUTES} minutes.\n\n"
        "PEATECH SERVICES LLC"
    )
    html_body = f"""
    <html>
      <body style="font-family: Arial, sans-serif; color: #103B36;">
        <p>Hello {escaped_recipient_name},</p>
        <p>Your Ghmera verification code is:</p>
        <p style="font-size: 28px; font-weight: 700; letter-spacing: 6px;">{code}</p>
        <p>Enter this code in the app to finish verifying your email address and signing up.</p>
        <p>This code expires in {EMAIL_CODE_TTL_MINUTES} minutes.</p>
        <p>PEATECH SERVICES LLC</p>
      </body>
    </html>
    """

    message = EmailMessage()
    message["Subject"] = subject
    message["From"] = f"{from_name} <{from_email}>"
    message["To"] = to_email
    message.set_content(text_body)
    message.add_alternative(html_body, subtype="html")

    try:
        if smtp_use_ssl:
            with smtplib.SMTP_SSL(
                smtp_host,
                smtp_port,
                context=ssl.create_default_context(),
            ) as smtp:
                if smtp_username:
                    smtp.login(smtp_username, smtp_password)
                smtp.send_message(message)
            return

        with smtplib.SMTP(smtp_host, smtp_port) as smtp:
            smtp.ehlo()
            if smtp_use_starttls:
                smtp.starttls(context=ssl.create_default_context())
                smtp.ehlo()
            if smtp_username:
                smtp.login(smtp_username, smtp_password)
            smtp.send_message(message)
    except https_fn.HttpsError:
        raise
    except Exception:
        logger.exception("SMTP verification email delivery failed for %s", to_email)
        raise https_fn.HttpsError(
            code=https_fn.FunctionsErrorCode.INTERNAL,
            message="Verification email delivery failed. Please try again.",
        )


def _send_password_reset_code_email(
    *,
    to_email: str,
    display_name: str | None,
    code: str,
) -> None:
    smtp_host = os.environ.get("SMTP_HOST", DEFAULT_SMTP_HOST).strip()
    smtp_port = int(os.environ.get("SMTP_PORT", str(DEFAULT_SMTP_PORT)))
    smtp_username = os.environ.get("SMTP_USERNAME", DEFAULT_SMTP_USERNAME).strip()
    smtp_password = SMTP_PASSWORD.value.strip()
    from_email = (
        os.environ.get("SMTP_FROM_EMAIL", DEFAULT_SMTP_FROM_EMAIL).strip()
        or DEFAULT_SMTP_FROM_EMAIL
    )
    from_name = (
        os.environ.get("SMTP_FROM_NAME", DEFAULT_SMTP_FROM_NAME).strip()
        or DEFAULT_SMTP_FROM_NAME
    )
    smtp_use_ssl = os.environ.get("SMTP_USE_SSL", "true").lower() == "true"
    smtp_use_starttls = os.environ.get("SMTP_USE_STARTTLS", "false").lower() == "true"

    if not smtp_host or not smtp_username or not smtp_password or not from_email:
        logger.error("SMTP is not fully configured.")
        raise https_fn.HttpsError(
            code=https_fn.FunctionsErrorCode.FAILED_PRECONDITION,
            message="Password reset email delivery is not configured.",
        )

    recipient_name = (display_name or "there").strip() or "there"
    escaped_recipient_name = escape(recipient_name)
    subject = "Your Ghmera password reset code"
    text_body = (
        f"Hello {recipient_name},\n\n"
        f"Your Ghmera password reset code is: {code}\n\n"
        f"Enter this code in the app to set a new password. "
        f"The code expires in {EMAIL_CODE_TTL_MINUTES} minutes.\n\n"
        "PEATECH SERVICES LLC"
    )
    html_body = f"""
    <html>
      <body style="font-family: Arial, sans-serif; color: #103B36;">
        <p>Hello {escaped_recipient_name},</p>
        <p>Your Ghmera password reset code is:</p>
        <p style="font-size: 28px; font-weight: 700; letter-spacing: 6px;">{code}</p>
        <p>Enter this code in the app and choose a new password.</p>
        <p>This code expires in {EMAIL_CODE_TTL_MINUTES} minutes.</p>
        <p>PEATECH SERVICES LLC</p>
      </body>
    </html>
    """

    message = EmailMessage()
    message["Subject"] = subject
    message["From"] = f"{from_name} <{from_email}>"
    message["To"] = to_email
    message.set_content(text_body)
    message.add_alternative(html_body, subtype="html")

    try:
        if smtp_use_ssl:
            with smtplib.SMTP_SSL(
                smtp_host,
                smtp_port,
                context=ssl.create_default_context(),
            ) as smtp:
                if smtp_username:
                    smtp.login(smtp_username, smtp_password)
                smtp.send_message(message)
            return

        with smtplib.SMTP(smtp_host, smtp_port) as smtp:
            smtp.ehlo()
            if smtp_use_starttls:
                smtp.starttls(context=ssl.create_default_context())
                smtp.ehlo()
            if smtp_username:
                smtp.login(smtp_username, smtp_password)
            smtp.send_message(message)
    except https_fn.HttpsError:
        raise
    except Exception:
        logger.exception("SMTP password reset email delivery failed for %s", to_email)
        raise https_fn.HttpsError(
            code=https_fn.FunctionsErrorCode.INTERNAL,
            message="Password reset email delivery failed. Please try again.",
        )


@https_fn.on_call(secrets=[SMTP_PASSWORD])
def send_registration_verification_code(req: https_fn.CallableRequest) -> dict[str, Any]:
    data = req.data or {}
    email = _require_email_value(data.get("email"))
    display_name = str(data.get("displayName") or "").strip() or None

    existing_user = _load_user_by_email(email)
    if existing_user is not None and existing_user.email_verified:
        raise https_fn.HttpsError(
            code=https_fn.FunctionsErrorCode.ALREADY_EXISTS,
            message="This email is already registered and verified. Please sign in.",
        )

    doc_ref = _registration_code_ref(email)
    now = datetime.now(timezone.utc)
    snap = doc_ref.get()
    if snap.exists:
        existing = snap.to_dict() or {}
        sent_at = _as_utc(existing.get("sentAt"))
        if sent_at is not None:
            remaining = EMAIL_CODE_RESEND_COOLDOWN_SECONDS - int((now - sent_at).total_seconds())
            if remaining > 0:
                raise https_fn.HttpsError(
                    code=https_fn.FunctionsErrorCode.RESOURCE_EXHAUSTED,
                    message=f"Wait {remaining} seconds before requesting a new code.",
                )

    code = _generate_email_code()
    doc_ref.set(
        {
            "email": email,
            "codeHash": _hash_email_code(email, code),
            "sentAt": now,
            "expiresAt": now + timedelta(minutes=EMAIL_CODE_TTL_MINUTES),
            "attemptsRemaining": EMAIL_CODE_MAX_ATTEMPTS,
            "updatedAt": firestore.SERVER_TIMESTAMP,
        },
        merge=True,
    )
    try:
        _send_verification_code_email(
            to_email=email,
            display_name=display_name,
            code=code,
        )
    except Exception:
        doc_ref.delete()
        raise

    return {"ok": True, "email": email, "expiresInMinutes": EMAIL_CODE_TTL_MINUTES}


@https_fn.on_call()
def complete_email_registration(req: https_fn.CallableRequest) -> dict[str, Any]:
    data = req.data or {}
    email = _require_email_value(data.get("email"))
    code = str(data.get("code") or "").strip()
    password = str(data.get("password") or "")
    display_name = str(data.get("displayName") or "").strip()

    if len(code) != 6 or not code.isdigit():
        raise https_fn.HttpsError(
            code=https_fn.FunctionsErrorCode.INVALID_ARGUMENT,
            message="Enter the 6-digit verification code from your email.",
        )
    if len(password) < 6:
        raise https_fn.HttpsError(
            code=https_fn.FunctionsErrorCode.INVALID_ARGUMENT,
            message="Password must be at least 6 characters.",
        )

    doc_ref = _registration_code_ref(email)
    stored = _verify_stored_code(
        doc_ref=doc_ref,
        code_identifier=email,
        code=code,
    )

    if (stored.get("email") or "") != email:
        doc_ref.delete()
        raise https_fn.HttpsError(
            code=https_fn.FunctionsErrorCode.FAILED_PRECONDITION,
            message="Verification request does not match this email.",
        )

    existing_user = _load_user_by_email(email)
    resolved_name = display_name or (existing_user.display_name if existing_user else email.split("@")[0])

    try:
        if existing_user is None:
            user_record = admin_auth.create_user(
                email=email,
                password=password,
                display_name=resolved_name,
                email_verified=True,
            )
        else:
            user_record = admin_auth.update_user(
                existing_user.uid,
                password=password,
                display_name=resolved_name,
                email_verified=True,
            )
    except Exception:
        logger.exception("Failed to create or update Firebase Auth user for %s", email)
        raise https_fn.HttpsError(
            code=https_fn.FunctionsErrorCode.INTERNAL,
            message="Failed to create the user account. Please try again.",
        )

    custom_token = admin_auth.create_custom_token(user_record.uid).decode("utf-8")
    doc_ref.delete()

    return {
        "ok": True,
        "uid": user_record.uid,
        "email": email,
        "customToken": custom_token,
    }


@https_fn.on_call(secrets=[SMTP_PASSWORD])
def send_password_reset_code(req: https_fn.CallableRequest) -> dict[str, Any]:
    data = req.data or {}
    email = _require_email_value(data.get("email"))

    existing_user = _load_user_by_email(email)
    if existing_user is None:
        raise https_fn.HttpsError(
            code=https_fn.FunctionsErrorCode.NOT_FOUND,
            message="This email is not registered.",
        )

    doc_ref = _password_reset_code_ref(email)
    now = datetime.now(timezone.utc)
    snap = doc_ref.get()
    if snap.exists:
        existing = snap.to_dict() or {}
        sent_at = _as_utc(existing.get("sentAt"))
        if sent_at is not None:
            remaining = EMAIL_CODE_RESEND_COOLDOWN_SECONDS - int((now - sent_at).total_seconds())
            if remaining > 0:
                raise https_fn.HttpsError(
                    code=https_fn.FunctionsErrorCode.RESOURCE_EXHAUSTED,
                    message=f"Wait {remaining} seconds before requesting a new code.",
                )

    code = _generate_email_code()
    doc_ref.set(
        {
            "email": email,
            "codeHash": _hash_email_code(email, code),
            "sentAt": now,
            "expiresAt": now + timedelta(minutes=EMAIL_CODE_TTL_MINUTES),
            "attemptsRemaining": EMAIL_CODE_MAX_ATTEMPTS,
            "updatedAt": firestore.SERVER_TIMESTAMP,
        },
        merge=True,
    )
    try:
        _send_password_reset_code_email(
            to_email=email,
            display_name=existing_user.display_name,
            code=code,
        )
    except Exception:
        doc_ref.delete()
        raise

    return {"ok": True, "email": email, "expiresInMinutes": EMAIL_CODE_TTL_MINUTES}


@https_fn.on_call()
def complete_password_reset(req: https_fn.CallableRequest) -> dict[str, Any]:
    data = req.data or {}
    email = _require_email_value(data.get("email"))
    code = str(data.get("code") or "").strip()
    password = str(data.get("password") or "")

    if len(code) != 6 or not code.isdigit():
        raise https_fn.HttpsError(
            code=https_fn.FunctionsErrorCode.INVALID_ARGUMENT,
            message="Enter the 6-digit password reset code.",
        )
    if len(password) < 6:
        raise https_fn.HttpsError(
            code=https_fn.FunctionsErrorCode.INVALID_ARGUMENT,
            message="Password must be at least 6 characters.",
        )

    existing_user = _load_user_by_email(email)
    if existing_user is None:
        raise https_fn.HttpsError(
            code=https_fn.FunctionsErrorCode.FAILED_PRECONDITION,
            message="Request a new reset code.",
        )

    doc_ref = _password_reset_code_ref(email)
    stored = _verify_stored_code(
        doc_ref=doc_ref,
        code_identifier=email,
        code=code,
    )

    if (stored.get("email") or "") != email:
        doc_ref.delete()
        raise https_fn.HttpsError(
            code=https_fn.FunctionsErrorCode.FAILED_PRECONDITION,
            message="Reset code does not match this email.",
        )

    try:
        admin_auth.update_user(existing_user.uid, password=password)
        admin_auth.revoke_refresh_tokens(existing_user.uid)
    except Exception:
        logger.exception("Failed to reset password for Firebase Auth user %s", email)
        raise https_fn.HttpsError(
            code=https_fn.FunctionsErrorCode.INTERNAL,
            message="Password reset failed. Please try again.",
        )
    doc_ref.delete()

    return {"ok": True, "email": email}


@https_fn.on_request()
def hello_world(req: https_fn.Request) -> https_fn.Response:
    return https_fn.Response("Hello from Ghmera Cloud Functions!")


def _cors_headers(origin: str | None) -> dict[str, str]:
    return {
        'Access-Control-Allow-Origin': origin or '*',
        'Access-Control-Allow-Headers': 'Content-Type, Authorization',
        'Access-Control-Allow-Methods': 'POST, OPTIONS',
    }


def _require_workflow_identity(req: https_fn.Request) -> dict[str, Any]:
    authorization = str(req.headers.get('Authorization') or '').strip()
    scheme, separator, token = authorization.partition(' ')
    if not separator or scheme.lower() != 'bearer' or not token.strip():
        raise WorkflowError('Sign in is required.', status_code=401)

    try:
        decoded_token = admin_auth.verify_id_token(
            token.strip(),
            check_revoked=True,
        )
    except Exception:
        logger.warning('Workflow API rejected an invalid authentication token.')
        raise WorkflowError(
            'Your session is no longer valid. Please sign in again.',
            status_code=401,
        )

    uid = str(decoded_token.get('uid') or decoded_token.get('sub') or '').strip()
    email = _normalize_email(str(decoded_token.get('email') or ''))
    email_verified = decoded_token.get('email_verified') is True
    if not uid or not email or not email_verified:
        raise WorkflowError(
            'The signed-in account does not have a verified email identity.',
            status_code=403,
        )

    return {'uid': uid, 'email': email}


def _resolve_authenticated_workflow_user_id(
    raw_database: dict[str, Any],
    *,
    uid: str,
    email: str,
) -> str:
    canonical_user_id = f'user_{uid}'
    email_matches: list[str] = []

    for bucket_key, raw_bucket in raw_database.items():
        if str(bucket_key).startswith('_') or not isinstance(raw_bucket, dict):
            continue

        raw_user = raw_bucket.get('user')
        if not isinstance(raw_user, dict):
            continue

        user_id = str(raw_user.get('id') or '').strip()
        user_email = _normalize_email(str(raw_user.get('email') or ''))
        if not user_id or user_email != email:
            continue

        if user_id == canonical_user_id:
            return canonical_user_id
        email_matches.append(user_id)

    unique_matches = list(dict.fromkeys(email_matches))
    if len(unique_matches) == 1:
        return unique_matches[0]

    raise WorkflowError(
        'The signed-in account could not be matched to the app profile.',
        status_code=403,
    )


def _secure_workflow_body(
    body: dict[str, Any],
    identity: dict[str, Any],
) -> dict[str, Any]:
    raw_database = body.get('database')
    if not isinstance(raw_database, dict):
        raise WorkflowError('Missing app-state database payload.')

    authenticated_email = _normalize_email(str(identity.get('email') or ''))
    current_user_id = _resolve_authenticated_workflow_user_id(
        raw_database,
        uid=str(identity.get('uid') or '').strip(),
        email=authenticated_email,
    )

    secured_database = dict(raw_database)
    raw_meta = raw_database.get('_meta')
    secured_meta = dict(raw_meta) if isinstance(raw_meta, dict) else {}
    secured_meta['currentUserId'] = current_user_id
    secured_meta['currentUserEmail'] = authenticated_email
    secured_database['_meta'] = secured_meta

    secured_body = dict(body)
    secured_body['currentUserId'] = current_user_id
    secured_body['database'] = secured_database
    return secured_body


@https_fn.on_request()
def workflow_api(req: https_fn.Request) -> https_fn.Response:
    headers = _cors_headers(req.headers.get('Origin'))

    if req.method == 'OPTIONS':
        return https_fn.Response('', status=204, headers=headers)

    if req.method != 'POST':
        return https_fn.Response(
            json.dumps({'ok': False, 'error': 'Method not allowed.'}),
            status=405,
            headers=headers,
            content_type='application/json',
        )

    try:
        body = req.get_json(silent=True)
        if not isinstance(body, dict):
            raise WorkflowError('Invalid JSON body.')

        identity = _require_workflow_identity(req)
        secured_body = _secure_workflow_body(body, identity)
        updated_database, result = apply_workflow_operation(secured_body)
        return https_fn.Response(
            json.dumps({'ok': True, 'database': updated_database, 'result': result}),
            status=200,
            headers=headers,
            content_type='application/json',
        )
    except WorkflowError as error:
        return https_fn.Response(
            json.dumps({'ok': False, 'error': error.message}),
            status=error.status_code,
            headers=headers,
            content_type='application/json',
        )
    except Exception as error:
        print(f'Workflow API failed: {error}')
        return https_fn.Response(
            json.dumps({'ok': False, 'error': 'Internal server error.'}),
            status=500,
            headers=headers,
            content_type='application/json',
        )
