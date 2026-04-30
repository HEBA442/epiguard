from flask import Blueprint, request, jsonify
import logging
from app.services import seizure_service
from app.services import alert_service
from app.utils.jwt_handler import JWTHandler

logger = logging.getLogger(__name__)

seizure_bp = Blueprint('seizure', __name__, url_prefix='/api/seizure')


@seizure_bp.route('/predict', methods=['POST'])
def predict():
    """
    Receive 24 EEG features + optional GPS from Flutter. Returns prediction.

    Expected JSON body:
    {
        "features": { "T7-P7_delta": 1.23, ... },   // 24 keys
        "latitude":  24.7136,                        // optional
        "longitude": 46.6753                         // optional
    }

    Returns:
    {
        "prediction": 0 | 1,
        "probability": 0.94,
        "event_id": 12,        // null if no seizure or unauthenticated
        "skip": false
    }
    """
    try:
        # 1. Verify token and get user_id
        token = JWTHandler.extract_token_from_header(request)
        if not token:
            return jsonify({'error': 'No token provided'}), 401

        user_id = JWTHandler.verify_token(token)
        if user_id is None:
            return jsonify({'error': 'Invalid or expired token'}), 401

        data = request.get_json(silent=True)
        if not data:
            return jsonify({'error': 'Invalid or empty JSON body'}), 400

        features = data.get('features')
        if not features or not isinstance(features, dict):
            return jsonify({'error': "'features' key missing or not a dict"}), 400

        # Optional GPS coordinates
        latitude  = data.get('latitude')
        longitude = data.get('longitude')

        # Run prediction — saves event to DB on seizure
        result = seizure_service.predict(
            features=features,
            user_id=user_id,
            latitude=latitude,
            longitude=longitude,
        )

        # If seizure detected, trigger caregiver alert (background thread)
        if result.get('prediction') == 1 and result.get('event_id'):
            alert_service.notify_caregivers(
                patient_id=user_id,
                event_id=result['event_id'],
                probability=result['probability'],
                latitude=latitude,
                longitude=longitude,
            )

        return jsonify(result), 200

    except ValueError as e:
        logger.warning(f"Predict validation error: {str(e)}")
        return jsonify({'error': str(e)}), 422

    except RuntimeError as e:
        logger.error(f"Model error: {str(e)}")
        return jsonify({'error': str(e)}), 503

    except Exception as e:
        logger.error(f"Unexpected prediction error: {str(e)}")
        return jsonify({'error': 'Internal server error'}), 500


@seizure_bp.route('/history/<int:user_id>', methods=['GET'])
def history(user_id):
    """
    Get the last 50 seizure events for a patient.

    Returns:
    {
        "events": [ { "id", "detected_at", "probability", "alert_sent", "latitude", "longitude" }, ... ]
    }
    """
    try:
        # 1. Verify token
        token = JWTHandler.extract_token_from_header(request)
        if not token:
            return jsonify({'error': 'No token provided'}), 401

        auth_user_id = JWTHandler.verify_token(token)
        if auth_user_id is None:
            return jsonify({'error': 'Invalid or expired token'}), 401

        from app.models.seizure_event import SeizureEvent
        events = SeizureEvent.get_recent(user_id=user_id)

        serialised = []
        for e in events:
            serialised.append({
                'id':          e['id'],
                'detected_at': e['detected_at'].isoformat() if e['detected_at'] else None,
                'probability': float(e['probability']),
                'alert_sent':  bool(e['alert_sent']),
                'latitude':    float(e['latitude'])  if e.get('latitude')  else None,
                'longitude':   float(e['longitude']) if e.get('longitude') else None,
            })

        return jsonify({'events': serialised}), 200

    except Exception as e:
        logger.error(f"Error fetching seizure history: {str(e)}")
        return jsonify({'error': 'Internal server error'}), 500
