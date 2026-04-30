import os
import smtplib
import mimetypes
from email.message import EmailMessage


def _get_mail_config() -> tuple[str, str]:
    sender_email = os.getenv("SMTP_EMAIL", "").strip()
    # Gmail app passwords are often copied with spaces (e.g. xxxx xxxx xxxx xxxx).
    app_password = os.getenv("SMTP_APP_PASSWORD", "").replace(" ", "")

    if not sender_email or not app_password:
        raise ValueError("SMTP_EMAIL and SMTP_APP_PASSWORD must be configured in .env")

    return sender_email, app_password


def send_otp_email(recipient_email: str, otp: str, otp_valid_minutes: int = 10) -> None:
    sender_email, app_password = _get_mail_config()

    message = EmailMessage()
    message["Subject"] = "Your CivicVision OTP Code"
    message["From"] = sender_email
    message["To"] = recipient_email
    message.set_content(
        (
            "Hello,\n\n"
            f"Your OTP code is: {otp}\n"
            f"It will expire in {otp_valid_minutes} minutes.\n\n"
            "If you did not request this, please ignore this email.\n\n"
            "- CivicVision"
        )
    )

    with smtplib.SMTP("smtp.gmail.com", 587, timeout=20) as smtp:
        smtp.starttls()
        smtp.login(sender_email, app_password)
        smtp.send_message(message)


def send_emergency_alert_email(
    recipients: list[str],
    complaint_id: str,
    category: str,
    location_name: str,
    latitude: float,
    longitude: float,
    reported_at_iso: str,
    image_path: str | None = None,
) -> None:
    sender_email, app_password = _get_mail_config()
    clean_recipients = [email.strip() for email in recipients if email and email.strip()]
    if not clean_recipients:
        return

    message = EmailMessage()
    message["Subject"] = f"[CRITICAL] Emergency Reported - {category}"
    message["From"] = sender_email
    message["To"] = ", ".join(clean_recipients)
    image_cid = "emergency-image"
    text_body = (
        (
            "Emergency alert from CivicVision\n\n"
            f"Complaint ID: {complaint_id}\n"
            f"Category: {category}\n"
            f"Location: {location_name}\n"
            f"Coordinates: {latitude}, {longitude}\n"
            f"Reported at (UTC): {reported_at_iso}\n\n"
            "Please take immediate action."
        )
    )
    message.set_content(text_body)

    html_body = (
        "<html><body>"
        "<h3>Emergency alert from CivicVision</h3>"
        f"<p><b>Complaint ID:</b> {complaint_id}<br>"
        f"<b>Category:</b> {category}<br>"
        f"<b>Location:</b> {location_name}<br>"
        f"<b>Coordinates:</b> {latitude}, {longitude}<br>"
        f"<b>Reported at (UTC):</b> {reported_at_iso}</p>"
        "<p>Please take immediate action.</p>"
    )

    image_bytes = None
    image_maintype = "image"
    image_subtype = "jpeg"
    image_filename = None

    if image_path and os.path.exists(image_path):
        with open(image_path, "rb") as image_file:
            image_bytes = image_file.read()
        guessed_mime, _ = mimetypes.guess_type(image_path)
        if guessed_mime and "/" in guessed_mime:
            image_maintype, image_subtype = guessed_mime.split("/", 1)
        image_filename = os.path.basename(image_path)
        html_body += f'<p><b>Reported image:</b><br><img src="cid:{image_cid}" style="max-width:640px;border-radius:8px;"></p>'

    html_body += "</body></html>"
    message.add_alternative(html_body, subtype="html")

    if image_bytes is not None:
        html_part = message.get_payload()[-1]
        html_part.add_related(
            image_bytes,
            maintype=image_maintype,
            subtype=image_subtype,
            cid=f"<{image_cid}>",
        )
        message.add_attachment(
            image_bytes,
            maintype=image_maintype,
            subtype=image_subtype,
            filename=image_filename or "emergency.jpg",
        )

    with smtplib.SMTP("smtp.gmail.com", 587, timeout=20) as smtp:
        smtp.starttls()
        smtp.login(sender_email, app_password)
        smtp.send_message(message)
def send_status_update_email(
    recipients: list[str],
    complaint_id: str,
    new_status: str,
    category: str,
    location_name: str,
    latitude: float,
    longitude: float,
):
    maps_link = f"https://www.google.com/maps?q={latitude},{longitude}"
    sender_email, app_password = _get_mail_config()

    clean_recipients = [email.strip() for email in recipients if email and email.strip()]
    if not clean_recipients:
        return

    # Prepare subject and bodies once
    subject = f"Update on your complaint ({complaint_id})"
    
    # Plain text
    text_body = f"""
Hello,

Your complaint has been updated.

Complaint ID: {complaint_id}
Category: {category}
Location: {location_name}
Status: {new_status}

Coordinates: {latitude}, {longitude}

View on map:
{maps_link}

Thank you for using CivicVision.
"""

    # HTML (better UI)
    html_body = f"""
<html>
    <body>
        <h3>Complaint Status Update</h3>
        <p>
            <b>Complaint ID:</b> {complaint_id}<br>
            <b>Category:</b> {category}<br>
            <b>Location:</b> {location_name}<br>
            <b>Status:</b> <span style="color:blue;"><b>{new_status}</b></span><br>
            <b>Coordinates:</b> {latitude}, {longitude}
        </p>
        <p>
            <a href="{maps_link}" 
               style="background:#2196F3;color:white;padding:10px 15px;
                      text-decoration:none;border-radius:5px;">
               📍 View on Map
            </a>
        </p>
        <p>Thank you for using CivicVision.</p>
    </body>
</html>
    """

    # Send individual messages to each recipient
    with smtplib.SMTP("smtp.gmail.com", 587, timeout=20) as smtp:
        smtp.starttls()
        smtp.login(sender_email, app_password)

        for recipient in clean_recipients:
            msg = EmailMessage()

            msg["Subject"] = subject
            msg["From"] = sender_email
            msg["To"] = recipient

            # Plain text
            msg.set_content(text_body)

            # HTML
            msg.add_alternative(html_body, subtype="html")

            # Send to this recipient
            smtp.send_message(msg)