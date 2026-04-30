from app.database import db
import datetime
import logging

logger = logging.getLogger(__name__)


class SeizureEvent:
    """Model for seizure detection events"""

    @staticmethod
    def save(user_id, probability, latitude=None, longitude=None):
        """
        Save a detected seizure event to the database.

        Args:
            user_id:     ID of the patient
            probability: Model confidence score (0.0 – 1.0)
            latitude:    GPS latitude (optional)
            longitude:   GPS longitude (optional)

        Returns:
            (event_id, message)
        """
        try:
            cursor = db.get_cursor()
            connection = db.get_connection()

            cursor.execute("""
                INSERT INTO seizure_events (user_id, detected_at, probability, alert_sent, latitude, longitude)
                VALUES (%s, %s, %s, %s, %s, %s)
            """, (user_id, datetime.datetime.now(), probability, False, latitude, longitude))

            connection.commit()

            cursor.execute("SELECT LAST_INSERT_ID() as id")
            result = cursor.fetchone()
            event_id = result['id'] if result else None

            logger.info(f"Seizure event saved: id={event_id}, user={user_id}, prob={probability:.3f}")
            return event_id, "Seizure event saved"

        except Exception as e:
            db.get_connection().rollback()
            logger.error(f"Error saving seizure event: {str(e)}")
            return None, f"Error saving seizure event: {str(e)}"

    @staticmethod
    def get_recent(user_id, limit=50):
        """
        Retrieve the most recent seizure events for a patient.

        Returns:
            list of dicts or []
        """
        try:
            cursor = db.get_cursor()
            cursor.execute("""
                SELECT id, user_id, detected_at, probability, alert_sent
                FROM seizure_events
                WHERE user_id = %s
                ORDER BY detected_at DESC
                LIMIT %s
            """, (user_id, limit))
            return cursor.fetchall()
        except Exception as e:
            logger.error(f"Error fetching seizure events: {str(e)}")
            return []

    @staticmethod
    def mark_alert_sent(event_id):
        """Mark a seizure event's alert as sent."""
        try:
            cursor = db.get_cursor()
            connection = db.get_connection()
            cursor.execute("""
                UPDATE seizure_events SET alert_sent = TRUE WHERE id = %s
            """, (event_id,))
            connection.commit()
            return True
        except Exception as e:
            logger.error(f"Error marking alert sent: {str(e)}")
            return False
