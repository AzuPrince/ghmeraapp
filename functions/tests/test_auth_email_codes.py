import re
import smtplib
import unittest
from unittest.mock import MagicMock, patch

from firebase_functions import https_fn

import main


class AuthEmailCodeTests(unittest.TestCase):
    def test_email_validation_normalizes_valid_address(self):
        self.assertEqual(
            main._require_email_value("  User@Example.COM  "),
            "user@example.com",
        )

    def test_email_validation_rejects_invalid_and_header_injection_values(self):
        invalid_values = (
            "",
            "missing-at.example.com",
            "missing-domain@example",
            "person@example.com\nBcc: attacker@example.com",
        )

        for value in invalid_values:
            with self.subTest(value=value):
                with self.assertRaises(https_fn.HttpsError):
                    main._require_email_value(value)

    def test_generated_codes_are_six_digits(self):
        for _ in range(100):
            self.assertRegex(main._generate_email_code(), re.compile(r"^\d{6}$"))

    @patch("main.smtplib.SMTP_SSL")
    def test_verification_email_uses_configured_sender_and_escapes_html(
        self,
        smtp_ssl_mock,
    ):
        smtp = MagicMock()
        smtp_ssl_mock.return_value.__enter__.return_value = smtp

        with patch.dict(
            main.os.environ,
            {
                "SMTP_HOST": "mail.peatechservice.com",
                "SMTP_PORT": "465",
                "SMTP_USERNAME": "info@peatechservice.com",
                "SMTP_PASSWORD": "test-secret",
                "SMTP_FROM_EMAIL": "mail@peatechservice.com",
                "SMTP_FROM_NAME": "PEATECH SERVICES LLC",
                "SMTP_USE_SSL": "true",
                "SMTP_USE_STARTTLS": "false",
            },
            clear=False,
        ):
            main._send_verification_code_email(
                to_email="person@example.com",
                display_name="<Admin>",
                code="123456",
            )

        smtp_ssl_mock.assert_called_once()
        smtp.login.assert_called_once_with(
            "info@peatechservice.com",
            "test-secret",
        )
        message = smtp.send_message.call_args.args[0]
        self.assertEqual(
            message["From"],
            "PEATECH SERVICES LLC <mail@peatechservice.com>",
        )
        self.assertEqual(message["To"], "person@example.com")
        html_body = message.get_body(preferencelist=("html",)).get_content()
        self.assertIn("123456", html_body)
        self.assertIn("&lt;Admin&gt;", html_body)

    @patch("main.smtplib.SMTP_SSL")
    def test_smtp_failure_returns_safe_client_message(
        self,
        smtp_ssl_mock,
    ):
        smtp_ssl_mock.side_effect = smtplib.SMTPException("internal server detail")

        with patch.dict(
            main.os.environ,
            {"SMTP_PASSWORD": "test-secret"},
            clear=False,
        ):
            with self.assertRaises(https_fn.HttpsError) as raised:
                main._send_password_reset_code_email(
                    to_email="person@example.com",
                    display_name="Person",
                    code="123456",
                )

        self.assertNotIn("internal server detail", str(raised.exception))


if __name__ == "__main__":
    unittest.main()
