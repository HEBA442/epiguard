from flask import Blueprint, request, jsonify
from app.services.auth_service import AuthService
from app.services.password_reset_service import PasswordResetService
from app.utils.jwt_handler import JWTHandler
import logging

auth_bp = Blueprint('auth', __name__, url_prefix='/api/auth')
logger = logging.getLogger(__name__)

# ============================================================
# ENDPOINT 1: REQUEST SIGNUP OTP
# ============================================================

@auth_bp.route('/request-signup-otp', methods=['POST'])
def request_signup_otp():
    """
    Request OTP for signup
    Patient enters their email, get OTP sent to email
    
    Expected JSON: {
        "email": "patient@example.com"
    }
    
    Response: {
        "success": true,
        "message": "OTP sent successfully to your email",
        "email": "patient@example.com"
    }
    """
    try:
        data = request.get_json()
        
        if not data:
            return jsonify({
                'success': False,
                'message': 'No data provided'
            }), 400
        
        email = data.get('email', '').strip().lower()
        
        # Call service
        result = AuthService.request_signup_otp(email)
        
        if result['success']:
            return jsonify(result), 200
        else:
            return jsonify(result), 400
    
    except Exception as e:
        logger.error(f"Request signup OTP error: {str(e)}")
        return jsonify({
            'success': False,
            'message': f'Error requesting OTP: {str(e)}'
        }), 500


# ============================================================
# ENDPOINT 2: COMPLETE SIGNUP (With OTP Verification)
# ============================================================

@auth_bp.route('/complete-signup', methods=['POST'])
def complete_signup():
    """
    Complete signup after OTP verification
    Creates both patient and caregiver accounts
    
    Expected JSON: {
        "patient_name": "Ahmed Ali",
        "patient_email": "patient@example.com",
        "patient_password": "password123",
        "patient_age": 12,
        "patient_epilepsy_duration": "3 years",
        "caregiver_name": "Fatima Ali",
        "caregiver_email": "caregiver@example.com",
        "caregiver_relation": "Mother",
        "otp_code": "123456"
    }
    
    Response: {
        "success": true,
        "message": "Signup completed successfully! Please check your email for confirmation.",
        "patient_id": 1,
        "caregiver_id": 2,
        "patient_email": "patient@example.com",
        "caregiver_email": "caregiver@example.com"
    }
    """
    try:
        data = request.get_json()
        
        if not data:
            return jsonify({
                'success': False,
                'message': 'No data provided'
            }), 400
        
        # Extract and validate all fields
        patient_name = data.get('patient_name', '').strip()
        patient_email = data.get('patient_email', '').strip().lower()
        patient_password = data.get('patient_password', '')
        patient_age = data.get('patient_age')
        patient_epilepsy_duration = data.get('patient_epilepsy_duration', '').strip()
        caregiver_name = data.get('caregiver_name', '').strip()
        caregiver_email = data.get('caregiver_email', '').strip().lower()
        caregiver_relation = data.get('caregiver_relation', '').strip()
        otp_code = data.get('otp_code', '').strip()
        
        # Convert age to int if provided
        if patient_age:
            try:
                patient_age = int(patient_age)
            except (ValueError, TypeError):
                return jsonify({
                    'success': False,
                    'message': 'Patient age must be a valid number'
                }), 400
        
        # Call service
        result = AuthService.complete_signup(
            patient_name=patient_name,
            patient_email=patient_email,
            patient_password=patient_password,
            patient_age=patient_age,
            patient_epilepsy_duration=patient_epilepsy_duration,
            caregiver_name=caregiver_name,
            caregiver_email=caregiver_email,
            caregiver_relation=caregiver_relation,
            otp_code=otp_code
        )
        
        if result['success']:
            return jsonify(result), 201
        else:
            return jsonify(result), 400
    
    except Exception as e:
        logger.error(f"Complete signup error: {str(e)}")
        return jsonify({
            'success': False,
            'message': f'Error during signup: {str(e)}'
        }), 500


# ============================================================
# ENDPOINT 3: LOGIN
# ============================================================

@auth_bp.route('/login', methods=['POST'])
def login():
    """
    Login user (patient or caregiver)
    
    Expected JSON: {
        "email": "user@example.com",
        "password": "password123"
    }
    
    Response: {
        "success": true,
        "message": "Login successful",
        "user_id": 1,
        "user_name": "Ahmed Ali",
        "user_type": "patient",
        "token": "eyJhbGc..."
    }
    """
    try:
        data = request.get_json()
        
        if not data:
            return jsonify({
                'success': False,
                'message': 'No data provided'
            }), 400
        
        email = data.get('email', '').strip().lower()
        password = data.get('password', '')
        
        # Call service
        result = AuthService.login(email, password)
        
        if result['success']:
            return jsonify(result), 200
        else:
            return jsonify(result), 401
    
    except Exception as e:
        logger.error(f"Login error: {str(e)}")
        return jsonify({
            'success': False,
            'message': f'Error during login: {str(e)}'
        }), 500


# ============================================================
# ENDPOINT 4: VERIFY TOKEN
# ============================================================

@auth_bp.route('/verify-token', methods=['GET'])
def verify_token():
    """
    Verify if token is valid
    
    Expected header: Authorization: Bearer <token>
    
    Response: {
        "success": true,
        "message": "Token is valid",
        "user_id": 1,
        "user_name": "Ahmed Ali",
        "user_type": "patient"
    }
    """
    try:
        # Extract token
        token = JWTHandler.extract_token_from_header(request)
        
        # Call service
        result = AuthService.verify_token(token)
        
        if result['success']:
            return jsonify(result), 200
        else:
            return jsonify(result), 401
    
    except Exception as e:
        logger.error(f"Token verification error: {str(e)}")
        return jsonify({
            'success': False,
            'message': f'Error verifying token: {str(e)}'
        }), 500


# ============================================================
# ENDPOINT 5: REQUEST PASSWORD RESET OTP
# ============================================================

@auth_bp.route('/request-password-reset', methods=['POST'])
def request_password_reset():
    """
    Request password reset - send OTP to user's email
    
    Expected JSON: {
        "email": "user@example.com"
    }
    
    Response: {
        "success": true,
        "message": "Password reset OTP sent to your email",
        "email": "user@example.com",
        "user_id": 1
    }
    """
    try:
        data = request.get_json()
        
        if not data:
            return jsonify({
                'success': False,
                'message': 'No data provided'
            }), 400
        
        email = data.get('email', '').strip().lower()
        
        if not email:
            return jsonify({
                'success': False,
                'message': 'Email is required'
            }), 400
        
        # Call service
        result = PasswordResetService.request_password_reset(email)
        
        if result['success']:
            return jsonify(result), 200
        else:
            return jsonify(result), 400
    
    except Exception as e:
        logger.error(f"Request password reset error: {str(e)}")
        return jsonify({
            'success': False,
            'message': f'Error requesting password reset: {str(e)}'
        }), 500


# ============================================================
# ENDPOINT 6: RESET PASSWORD (With OTP Verification)
# ============================================================

@auth_bp.route('/reset-password', methods=['POST'])
def reset_password():
    """
    Reset password after OTP verification
    
    Expected JSON: {
        "email": "user@example.com",
        "otp_code": "123456",
        "new_password": "newpassword123"
    }
    
    Response: {
        "success": true,
        "message": "Password reset successfully. You can now login with your new password.",
        "user_id": 1,
        "email": "user@example.com"
    }
    """
    try:
        data = request.get_json()
        
        if not data:
            return jsonify({
                'success': False,
                'message': 'No data provided'
            }), 400
        
        email = data.get('email', '').strip().lower()
        otp_code = data.get('otp_code', '').strip()
        new_password = data.get('new_password', '')
        
        if not email:
            return jsonify({
                'success': False,
                'message': 'Email is required'
            }), 400
        
        if not otp_code:
            return jsonify({
                'success': False,
                'message': 'OTP code is required'
            }), 400
        
        if not new_password:
            return jsonify({
                'success': False,
                'message': 'New password is required'
            }), 400
        
        if len(new_password) < 6:
            return jsonify({
                'success': False,
                'message': 'Password must be at least 6 characters'
            }), 400
        
        # Call service
        result = PasswordResetService.reset_password(email, otp_code, new_password)
        
        if result['success']:
            return jsonify(result), 200
        else:
            return jsonify(result), 400
    
    except Exception as e:
        logger.error(f"Reset password error: {str(e)}")
        return jsonify({
            'success': False,
            'message': f'Error resetting password: {str(e)}'
        }), 500


# ============================================================
# ENDPOINT 7: REGISTER FCM TOKEN
# ============================================================

@auth_bp.route('/register-fcm-token', methods=['POST'])
def register_fcm_token():
    """
    Save or refresh the device's FCM push notification token.
    Called by Flutter after login and whenever the token refreshes.

    Expected header: Authorization: Bearer <token>
    Expected JSON:   { "fcm_token": "<device_token>" }

    Response: { "success": true, "message": "FCM token registered" }
    """
    try:
        # Verify JWT
        token = JWTHandler.extract_token_from_header(request)
        if not token:
            return jsonify({'success': False, 'message': 'No token provided'}), 401

        user_id = JWTHandler.verify_token(token)
        if user_id is None:
            return jsonify({'success': False, 'message': 'Invalid or expired token'}), 401

        data = request.get_json(silent=True)
        if not data:
            return jsonify({'success': False, 'message': 'No data provided'}), 400

        fcm_token = data.get('fcm_token', '').strip()
        if not fcm_token:
            return jsonify({'success': False, 'message': 'fcm_token is required'}), 400

        from app.models.user import User
        success = User.update_fcm_token(user_id, fcm_token)

        if success:
            logger.info(f"FCM token registered for user {user_id}")
            return jsonify({'success': True, 'message': 'FCM token registered'}), 200
        else:
            return jsonify({'success': False, 'message': 'Failed to save FCM token'}), 500

    except Exception as e:
        logger.error(f"FCM token registration error: {str(e)}")
        return jsonify({'success': False, 'message': f'Error: {str(e)}'}), 500