import logging
import threading
from app.models.caregiver_patient import CaregiverPatientLink
from app.models.seizure_event import SeizureEvent
from app.services.email_service import EmailService
from app.models.user import User

logger = logging.getLogger(__name__)


def _maps_link(lat, lng):
    return f'https://maps.google.com/?q={lat},{lng}'


def _send_fcm_push(fcm_token, patient_name, probability, latitude=None, longitude=None):
    """
    Send a high-priority FCM data message to a caregiver's device.
    The Flutter app will receive this and trigger the local alarm.
    Requires firebase-admin and a serviceAccountKey.json in the project root.
    """
    try:
        import firebase_admin
        from firebase_admin import credentials, messaging

        # Initialise once per process
        if not firebase_admin._apps:
            cred = credentials.Certificate('serviceAccountKey.json')
            firebase_admin.initialize_app(cred)

        location_str = (
            f'{latitude},{longitude}'
            if latitude is not None and longitude is not None
            else ''
        )

        message = messaging.Message(
            token=fcm_token,
            # data payload — Flutter background handler reads these keys
            data={
                'type':         'seizure_alert',
                'patient_name': str(patient_name),
                'probability':  str(round(probability * 100, 1)),
                'latitude':     str(latitude)  if latitude  is not None else '',
                'longitude':    str(longitude) if longitude is not None else '',
                'maps_link':    _maps_link(latitude, longitude) if location_str else '',
            },
            android=messaging.AndroidConfig(
                priority='high',
                notification=messaging.AndroidNotification(
                    title=f'🚨 SEIZURE — {patient_name}',
                    body=f'Confidence: {round(probability * 100, 1)}% — Tap to view location',
                    channel_id='epiguard_caregiver_alarm',
                    default_sound=True,
                ),
            ),
            apns=messaging.APNSConfig(
                payload=messaging.APNSPayload(
                    aps=messaging.Aps(
                        alert=messaging.ApsAlert(
                            title=f'🚨 SEIZURE — {patient_name}',
                            body=f'Confidence: {round(probability * 100, 1)}%',
                        ),
                        sound='default',
                        badge=1,
                    ),
                ),
            ),
        )

        response = messaging.send(message)
        logger.info(f"FCM push sent: {response}")
        return True

    except Exception as e:
        logger.error(f"FCM push failed: {str(e)}")
        return False


def notify_caregivers(patient_id, event_id, probability, latitude=None, longitude=None):
    """
    Look up all caregivers linked to this patient and:
    1. Send a high-priority FCM push (triggers alarm on caregiver's phone)
    2. Send an email alert as a fallback

    Runs in a background thread so the Flask response is not delayed.
    """
    def _run():
        try:
            # Get patient name
            patient = User.get_user_by_id(patient_id)
            patient_name = patient['name'] if patient else f'Patient #{patient_id}'

            caregivers = CaregiverPatientLink.get_caregivers_for_patient(patient_id)
            if not caregivers:
                logger.warning(f"No caregivers found for patient {patient_id}")
                return

            # Build location text for email
            if latitude is not None and longitude is not None:
                location_text = (
                    f'<p style="margin: 8px 0;">'
                    f'<strong>📍 Live Location:</strong> '
                    f'<a href="{_maps_link(latitude, longitude)}" style="color:#e74c3c;">Open in Google Maps</a>'
                    f'</p>'
                )
            else:
                location_text = '<p style="color:#999; font-size:13px;">Location unavailable</p>'

            html_body = f"""
            <html>
                <body style="font-family: Arial, sans-serif; background-color: #f5f5f5; padding: 20px;">
                    <div style="max-width: 600px; margin: 0 auto; background-color: white;
                                padding: 30px; border-radius: 8px;
                                border-left: 6px solid #e74c3c;
                                box-shadow: 0 2px 4px rgba(0,0,0,0.1);">

                        <h2 style="color: #e74c3c; margin-top: 0;">⚠️ SEIZURE DETECTED — {patient_name}</h2>

                        <p style="color: #333; font-size: 16px; line-height: 1.6;">
                            EpiGuard has detected a <strong>seizure event</strong> for your patient
                            <strong>{patient_name}</strong>.
                        </p>

                        <div style="background-color: #fef0f0; padding: 16px; border-radius: 6px; margin: 20px 0;">
                            <p style="margin: 8px 0;">
                                <strong>Confidence:</strong> {round(probability * 100, 1)}%
                            </p>
                            {location_text}
                            <p style="margin: 8px 0;">
                                <strong>Event ID:</strong> #{event_id}
                            </p>
                        </div>

                        <p style="color: #e74c3c; font-weight: bold; font-size: 15px;">
                            Please respond immediately and check on {patient_name}.
                        </p>

                        <hr style="border: none; border-top: 1px solid #ddd; margin: 24px 0;">
                        <p style="color: #999; font-size: 12px; text-align: center;">
                            EpiGuard — Seizure Detection System<br>
                            This is an automated alert. Do not reply.
                        </p>
                    </div>
                </body>
            </html>
            """

            for caregiver in caregivers:
                caregiver_id = caregiver['caregiver_id']
                email        = caregiver['caregiver_email']
                name         = caregiver['caregiver_name']

                # 1. FCM Push (triggers alarm on caregiver's phone)
                fcm_token = User.get_fcm_token(caregiver_id)
                if fcm_token:
                    _send_fcm_push(
                        fcm_token=fcm_token,
                        patient_name=patient_name,
                        probability=probability,
                        latitude=latitude,
                        longitude=longitude,
                    )
                else:
                    logger.warning(f"No FCM token for caregiver {caregiver_id} ({name})")

                # 2. Email fallback
                success, msg = EmailService._send_email(
                    recipient_email=email,
                    subject=f'🚨 SEIZURE ALERT — {patient_name} needs attention',
                    html_body=html_body,
                )
                if success:
                    logger.info(f"Alert email sent to caregiver {name} ({email})")
                    SeizureEvent.mark_alert_sent(event_id)
                else:
                    logger.error(f"Failed to send alert email to {email}: {msg}")

        except Exception as e:
            logger.error(f"Alert service error: {str(e)}")

    thread = threading.Thread(target=_run, daemon=True)
    thread.start()
