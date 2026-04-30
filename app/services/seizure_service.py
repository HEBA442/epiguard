import os
import logging
import joblib
import numpy as np
from app.models.seizure_event import SeizureEvent

logger = logging.getLogger(__name__)

# ── Model loading (once at startup) ──────────────────────────────────────────
_MODEL_PATH = os.path.join(os.path.dirname(__file__), '..', '..', 'models', 'epiguard_model.pkl')
_model = None

def _get_model():
    """Lazy-load the model once and cache it."""
    global _model
    if _model is None:
        try:
            _model = joblib.load(_MODEL_PATH)
            logger.info("epiguard_model.pkl loaded successfully")
        except FileNotFoundError:
            logger.error(f"Model file not found at: {_MODEL_PATH}")
            raise RuntimeError("Seizure detection model not found. Check ml_models/ folder.")
    return _model


# ── Expected feature column order (must match X_train.columns from Colab) ────
FEATURE_COLUMNS = [
    'T7-P7_delta',  'T7-P7_theta',  'T7-P7_alpha',  'T7-P7_beta',
    'T7-P7_delta_alpha_ratio',  'T7-P7_delta_beta_ratio',
    'FP1-F7_delta', 'FP1-F7_theta', 'FP1-F7_alpha', 'FP1-F7_beta',
    'FP1-F7_delta_alpha_ratio', 'FP1-F7_delta_beta_ratio',
    'FP2-F8_delta', 'FP2-F8_theta', 'FP2-F8_alpha', 'FP2-F8_beta',
    'FP2-F8_delta_alpha_ratio', 'FP2-F8_delta_beta_ratio',
    'T8-P8_delta',  'T8-P8_theta',  'T8-P8_alpha',  'T8-P8_beta',
    'T8-P8_delta_alpha_ratio',  'T8-P8_delta_beta_ratio',
]

SEIZURE_THRESHOLD = 0.6   # confidence required to count as seizure


def predict(features: dict, user_id: int = None, latitude: float = None, longitude: float = None):
    """
    Run seizure prediction from the 24 pre-extracted features.

    Args:
        features:  dict of { feature_name: value } — 24 keys
        user_id:   optional patient ID; seizure events saved to DB if provided
        latitude:  GPS latitude at time of prediction (optional)
        longitude: GPS longitude at time of prediction (optional)

    Returns:
        dict: {
            'prediction': 0 | 1,
            'probability': float,
            'event_id': int | None,
            'skip': bool
        }
    """
    try:
        model = _get_model()

        # Validate all 24 features are present
        missing = [col for col in FEATURE_COLUMNS if col not in features]
        if missing:
            raise ValueError(f"Missing features: {missing}")

        # Build ordered input row — must match training column order exactly
        X = np.array([[features[col] for col in FEATURE_COLUMNS]])

        # Predict — pipeline handles scaling internally, never scale manually
        proba = model.predict_proba(X)[0][1]      # probability of class 1 (seizure)
        prediction = 1 if proba >= SEIZURE_THRESHOLD else 0

        logger.info(f"Prediction: {prediction}, probability: {proba:.4f}, user: {user_id}")

        # Persist seizure event to DB if confirmed and user_id is available
        event_id = None
        if prediction == 1 and user_id is not None:
            event_id, _ = SeizureEvent.save(
                user_id=user_id,
                probability=float(proba),
                latitude=latitude,
                longitude=longitude,
            )

        return {
            'prediction': prediction,
            'probability': round(float(proba), 4),
            'event_id': event_id,
            'skip': False,
        }

    except Exception as e:
        logger.error(f"Prediction error: {str(e)}")
        raise
