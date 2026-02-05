"""
Email sending utility with pluggable backends.
Default 'console' backend prints verification codes to stdout for dev/testing.
"""
import os
import logging
import smtplib
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart
from abc import ABC, abstractmethod

logger = logging.getLogger(__name__)


class EmailBackend(ABC):
    """Abstract base class for email backends."""

    @abstractmethod
    def send(self, to_email, subject, body_text, body_html=None):
        """Send an email."""
        pass


class ConsoleBackend(EmailBackend):
    """Console backend that prints emails to stdout (for development/testing)."""

    def send(self, to_email, subject, body_text, body_html=None):
        message = (
            f"\n{'='*50}\n"
            f"[EMAIL] To: {to_email}\n"
            f"Subject: {subject}\n"
            f"{'='*50}\n"
            f"{body_text}\n"
            f"{'='*50}\n"
        )
        print(message)
        logger.info("Email sent via console backend to %s", to_email)


class SMTPBackend(EmailBackend):
    """SMTP backend with TLS support."""

    def __init__(self):
        self.host = os.getenv('SMTP_HOST')
        self.port = int(os.getenv('SMTP_PORT', '587'))
        self.user = os.getenv('SMTP_USER')
        self.password = os.getenv('SMTP_PASS')
        self.from_email = os.getenv('SMTP_FROM_EMAIL', self.user)
        self.use_tls = os.getenv('SMTP_USE_TLS', 'true').lower() == 'true'

        if not all([self.host, self.user, self.password]):
            raise ValueError(
                "SMTP backend requires SMTP_HOST, SMTP_USER, and SMTP_PASS environment variables"
            )

    def send(self, to_email, subject, body_text, body_html=None):
        msg = MIMEMultipart('alternative')
        msg['Subject'] = subject
        msg['From'] = self.from_email
        msg['To'] = to_email

        msg.attach(MIMEText(body_text, 'plain'))
        if body_html:
            msg.attach(MIMEText(body_html, 'html'))

        try:
            with smtplib.SMTP(self.host, self.port) as server:
                if self.use_tls:
                    server.starttls()
                server.login(self.user, self.password)
                server.sendmail(self.from_email, to_email, msg.as_string())
            logger.info("Email sent via SMTP to %s", to_email)
        except smtplib.SMTPException as e:
            logger.error("SMTP error sending email to %s: %s", to_email, str(e))
            raise


class SendGridBackend(EmailBackend):
    """SendGrid backend using the sendgrid SDK."""

    def __init__(self):
        self.api_key = os.getenv('SENDGRID_API_KEY')
        self.from_email = os.getenv('SENDGRID_FROM_EMAIL', 'noreply@example.com')

        if not self.api_key:
            raise ValueError(
                "SendGrid backend requires SENDGRID_API_KEY environment variable"
            )

    def send(self, to_email, subject, body_text, body_html=None):
        try:
            from sendgrid import SendGridAPIClient
            from sendgrid.helpers.mail import Mail, Email, To, Content
        except ImportError:
            raise ImportError(
                "sendgrid package is required for SendGrid backend. "
                "Install with: pip install sendgrid"
            )

        message = Mail(
            from_email=Email(self.from_email),
            to_emails=To(to_email),
            subject=subject,
            plain_text_content=Content("text/plain", body_text)
        )

        if body_html:
            message.add_content(Content("text/html", body_html))

        try:
            sg = SendGridAPIClient(self.api_key)
            response = sg.send(message)
            logger.info(
                "Email sent via SendGrid to %s (status: %s)",
                to_email,
                response.status_code
            )
        except Exception as e:
            logger.error("SendGrid error sending email to %s: %s", to_email, str(e))
            raise


def get_email_backend():
    """Get the configured email backend instance."""
    backend_name = os.getenv('EMAIL_BACKEND', 'console').lower()

    if backend_name == 'console':
        return ConsoleBackend()
    elif backend_name == 'smtp':
        return SMTPBackend()
    elif backend_name == 'sendgrid':
        return SendGridBackend()
    else:
        raise ValueError(f"Unknown EMAIL_BACKEND: {backend_name}")


def send_email(to_email, subject, body_text, body_html=None):
    """Send an email using the configured backend."""
    backend = get_email_backend()
    backend.send(to_email, subject, body_text, body_html)


def send_verification_email(to_email, code):
    """Send a verification email with the given code."""
    subject = "Your Verification Code"
    body_text = (
        f"Your verification code is: {code}\n\n"
        f"This code expires in 15 minutes.\n\n"
        f"If you did not request this code, please ignore this email."
    )
    body_html = f"""
    <html>
    <body style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto;">
        <h2 style="color: #333;">Verification Code</h2>
        <p>Your verification code is:</p>
        <div style="background: #f5f5f5; padding: 20px; text-align: center; margin: 20px 0;">
            <span style="font-size: 32px; font-weight: bold; letter-spacing: 4px; color: #007bff;">{code}</span>
        </div>
        <p style="color: #666;">This code expires in 15 minutes.</p>
        <p style="color: #999; font-size: 12px;">If you did not request this code, please ignore this email.</p>
    </body>
    </html>
    """
    send_email(to_email, subject, body_text, body_html)
    logger.info("Verification code sent to %s", to_email)


def send_account_approved_email(to_email, name):
    """Send notification that user's account has been approved."""
    subject = "Your Account Has Been Approved"
    body_text = (
        f"Hello {name},\n\n"
        f"Great news! Your account has been approved.\n\n"
        f"You can now log in to the app and start tracking your blood pressure.\n\n"
        f"Thank you for joining!"
    )
    body_html = f"""
    <html>
    <body style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto;">
        <h2 style="color: #28a745;">Account Approved!</h2>
        <p>Hello {name},</p>
        <p>Great news! Your account has been approved.</p>
        <p>You can now log in to the app and start tracking your blood pressure.</p>
        <p style="margin-top: 30px;">Thank you for joining!</p>
    </body>
    </html>
    """
    send_email(to_email, subject, body_text, body_html)
    logger.info("Account approved email sent to %s", to_email)


def send_login_otp_email(to_email, code):
    """Send a login OTP code for MFA verification."""
    subject = "Your Login Verification Code"
    body_text = (
        f"Your login verification code is: {code}\n\n"
        f"This code expires in 10 minutes.\n\n"
        f"If you did not attempt to log in, please secure your account."
    )
    body_html = f"""
    <html>
    <body style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto;">
        <h2 style="color: #333;">Login Verification Code</h2>
        <p>Your login verification code is:</p>
        <div style="background: #f5f5f5; padding: 20px; text-align: center; margin: 20px 0;">
            <span style="font-size: 32px; font-weight: bold; letter-spacing: 4px; color: #007bff;">{code}</span>
        </div>
        <p style="color: #666;">This code expires in 10 minutes.</p>
        <p style="color: #999; font-size: 12px;">If you did not attempt to log in, please secure your account immediately.</p>
    </body>
    </html>
    """
    send_email(to_email, subject, body_text, body_html)
    logger.info("Login OTP code sent to %s", to_email)


def send_cuff_shipped_email(to_email, name, tracking_number):
    """Send notification that user's cuff has been shipped."""
    subject = "Your Blood Pressure Cuff Has Shipped"
    body_text = (
        f"Hello {name},\n\n"
        f"Your blood pressure cuff has been shipped!\n\n"
        f"Tracking Number: {tracking_number}\n\n"
        f"You can track your package using this number on the carrier's website.\n\n"
        f"Thank you!"
    )
    body_html = f"""
    <html>
    <body style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto;">
        <h2 style="color: #007bff;">Your Cuff Has Shipped!</h2>
        <p>Hello {name},</p>
        <p>Your blood pressure cuff has been shipped!</p>
        <div style="background: #f5f5f5; padding: 15px; margin: 20px 0; border-radius: 5px;">
            <strong>Tracking Number:</strong> {tracking_number}
        </div>
        <p>You can track your package using this number on the carrier's website.</p>
        <p style="margin-top: 30px;">Thank you!</p>
    </body>
    </html>
    """
    send_email(to_email, subject, body_text, body_html)
    logger.info("Cuff shipped email sent to %s", to_email)
