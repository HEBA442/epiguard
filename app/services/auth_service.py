from app.models.user import User
from app.models.user_profile import UserProfile
from app.models.caregiver_patient import CaregiverPatientLink
from app.services.otp_service import OTPService
from app.services.email_service import EmailService
from app.utils.jwt_handler import JWTHandler
import string
import random
import logging

logger = logging.getLogger(__name__)


class AuthService:
    """Authentication service - business logic"""
    
    # ============================================================
    # NEW SIGNUP FLOW - Step 1: Request OTP
    # ============================================================
    
    @staticmethod
    def request_signup_otp(email):
        """
        Step 1: Request OTP for signup
        This is called when patient enters their email
        
        Args:
            email: Patient's email address
        
        Returns:
            dict with success status and message
        """
        try:
            # Validate email
            if not email or '@' not in email:
                return {
                    'success': False,
                    'message': 'Valid email is required'
                }
            
            # Normalize email
            email = email.strip().lower()
            
            # Check if email already exists as user
            existing_user = User.get_user_by_email(email)
            if existing_user:
                return {
                    'success': False,
                    'message': 'This email is already registered'
                }
            
            # Request OTP via OTPService
            result = OTPService.request_otp(email)
            
            return result
        
        except Exception as e:
            logger.error(f"Error requesting signup OTP: {str(e)}")
            return {
                'success': False,
                'message': f'Error requesting OTP: {str(e)}'
            }
    
    # ============================================================
    # NEW SIGNUP FLOW - Step 2: Verify OTP and Create Accounts
    # ============================================================
    
    @staticmethod
    def complete_signup(patient_name, patient_email, patient_password, patient_age, 
                       patient_epilepsy_duration, caregiver_name, caregiver_email, 
                       caregiver_relation, otp_code):
        """
        Step 2: Verify OTP and create both patient and caregiver accounts
        
        Args:
            patient_name: Patient's full name
            patient_email: Patient's email (username)
            patient_password: Patient's password
            patient_age: Patient's age
            patient_epilepsy_duration: How long patient has epilepsy
            caregiver_name: Caregiver's name
            caregiver_email: Caregiver's email
            caregiver_relation: Relation to patient (text input)
            otp_code: OTP code to verify
        
        Returns:
            dict with success status and data
        """
        try:
            # Normalize emails
            patient_email = patient_email.strip().lower()
            caregiver_email = caregiver_email.strip().lower()
            
            # ============================================================
            # VALIDATION
            # ============================================================
            
            # Validate patient fields
            if not patient_name or len(patient_name) < 2:
                return {
                    'success': False,
                    'message': 'Patient name must be at least 2 characters'
                }
            
            if not patient_email or '@' not in patient_email:
                return {
                    'success': False,
                    'message': 'Valid patient email is required'
                }
            
            if not patient_password or len(patient_password) < 6:
                return {
                    'success': False,
                    'message': 'Password must be at least 6 characters'
                }
            
            if patient_age and (not isinstance(patient_age, int) or patient_age < 0 or patient_age > 120):
                return {
                    'success': False,
                    'message': 'Please enter a valid age'
                }
            
            # Validate caregiver fields
            if not caregiver_name or len(caregiver_name) < 2:
                return {
                    'success': False,
                    'message': 'Caregiver name must be at least 2 characters'
                }
            
            if not caregiver_email or '@' not in caregiver_email:
                return {
                    'success': False,
                    'message': 'Valid caregiver email is required'
                }
            
            if not caregiver_relation or len(caregiver_relation.strip()) == 0:
                return {
                    'success': False,
                    'message': 'Relation to patient is required'
                }
            
            # ============================================================
            # VERIFY OTP
            # ============================================================
            
            otp_result = OTPService.verify_otp(patient_email, otp_code)
            
            if not otp_result['success']:
                return {
                    'success': False,
                    'message': otp_result['message']
                }
            
            # ============================================================
            # CREATE PATIENT USER
            # ============================================================
            
            patient_user_id, patient_message = User.create_user(
                name=patient_name,
                email=patient_email,
                password=patient_password,
                user_type='patient'
            )
            
            if patient_user_id is None:
                return {
                    'success': False,
                    'message': patient_message
                }
            
            # ============================================================
            # CREATE PATIENT PROFILE
            # ============================================================
            
            patient_profile_id, profile_message = UserProfile.create_profile(
                user_id=patient_user_id,
                age=patient_age,
                epilepsy_duration=patient_epilepsy_duration
            )
            
            if patient_profile_id is None:
                # Rollback - delete patient user
                logger.error(f"Failed to create patient profile. Rolling back user creation.")
                return {
                    'success': False,
                    'message': profile_message
                }
            
            # ============================================================
            # CREATE CAREGIVER USER WITH AUTO-GENERATED PASSWORD
            # ============================================================
            
            # Check if caregiver email already exists
            existing_caregiver = User.get_user_by_email(caregiver_email)
            if existing_caregiver:
                return {
                    'success': False,
                    'message': 'Caregiver email already registered'
                }
            
            # Generate random password for caregiver
            caregiver_password = AuthService._generate_random_password()
            
            caregiver_user_id, caregiver_message = User.create_user(
                name=caregiver_name,
                email=caregiver_email,
                password=caregiver_password,
                user_type='caregiver'
            )
            
            if caregiver_user_id is None:
                return {
                    'success': False,
                    'message': caregiver_message
                }
            
            # ============================================================
            # CREATE CAREGIVER PROFILE
            # ============================================================
            
            caregiver_profile_id, caregiver_profile_message = UserProfile.create_profile(
                user_id=caregiver_user_id
            )
            
            # ============================================================
            # LINK CAREGIVER TO PATIENT
            # ============================================================
            
            link_id, link_message = CaregiverPatientLink.create_link(
                caregiver_id=caregiver_user_id,
                patient_id=patient_user_id,
                relation=caregiver_relation.strip()
            )
            
            if link_id is None:
                logger.error(f"Failed to link caregiver to patient: {link_message}")
                return {
                    'success': False,
                    'message': 'Error linking caregiver to patient'
                }
            
            # ============================================================
            # SEND EMAILS
            # ============================================================
            
            # Send OTP confirmation + Patient signup confirmation
            patient_email_success, patient_email_msg = EmailService.send_patient_signup_confirmation_email(
                recipient_email=patient_email,
                patient_name=patient_name
            )
            
            # Send caregiver credentials email
            caregiver_email_success, caregiver_email_msg = EmailService.send_caregiver_credentials_email(
                recipient_email=caregiver_email,
                caregiver_email=caregiver_email,
                caregiver_password=caregiver_password,
                patient_name=patient_name
            )
            
            if not caregiver_email_success:
                logger.warning(f"Caregiver email failed: {caregiver_email_msg}")
            
            # ============================================================
            # DELETE OTP AFTER SUCCESSFUL SIGNUP
            # ============================================================
            
            OTPService.clean_otp(patient_email)
            
            # ============================================================
            # RETURN SUCCESS
            # ============================================================
            
            logger.info(f"Signup completed successfully. Patient ID: {patient_user_id}, Caregiver ID: {caregiver_user_id}")
            
            return {
                'success': True,
                'message': 'Signup completed successfully! Please check your email for confirmation.',
                'patient_id': patient_user_id,
                'caregiver_id': caregiver_user_id,
                'patient_email': patient_email,
                'caregiver_email': caregiver_email
            }
        
        except Exception as e:
            logger.error(f"Signup error: {str(e)}")
            return {
                'success': False,
                'message': f'Error during signup: {str(e)}'
            }
    
    # ============================================================
    # LOGIN (UNCHANGED FOR BOTH PATIENT AND CAREGIVER)
    # ============================================================
    
    @staticmethod
    def login(email, password):
        """
        Login user (patient or caregiver)
        
        Args:
            email: User's email
            password: User's password
        
        Returns:
            dict with success status and data
        """
        try:
            # Validate inputs
            if not email or not password:
                return {
                    'success': False,
                    'message': 'Email and password are required'
                }
            
            # Normalize email
            email = email.strip().lower()
            
            # Get user
            user = User.get_user_by_email(email)
            
            if not user:
                return {
                    'success': False,
                    'message': 'Invalid email or password'
                }
            
            # Verify password
            if not User.verify_password(user['password'], password):
                return {
                    'success': False,
                    'message': 'Invalid email or password'
                }
            
            # Generate token
            token = JWTHandler.generate_token(user['id'])
            
            if token is None:
                logger.error(f"Failed to generate token for user {user['id']}")
                return {
                    'success': False,
                    'message': 'Failed to generate authentication token'
                }
            
            logger.info(f"Login successful for user: {user['id']} (type: {user['user_type']})")
            
            return {
                'success': True,
                'message': 'Login successful',
                'user_id': user['id'],
                'user_name': user['name'],
                'user_type': user['user_type'],
                'token': token
            }
        
        except Exception as e:
            logger.error(f"Login error: {str(e)}")
            return {
                'success': False,
                'message': f'Error during login: {str(e)}'
            }
    
    # ============================================================
    # VERIFY TOKEN (UNCHANGED)
    # ============================================================
    
    @staticmethod
    def verify_token(token):
        """
        Verify JWT token
        
        Returns:
            dict with user info or error
        """
        try:
            if not token:
                return {
                    'success': False,
                    'message': 'No token provided'
                }
            
            # Verify token
            user_id = JWTHandler.verify_token(token)
            
            if user_id is None:
                return {
                    'success': False,
                    'message': 'Invalid or expired token'
                }
            
            # Get user info
            user = User.get_user_by_id(user_id)
            
            if not user:
                return {
                    'success': False,
                    'message': 'User not found'
                }
            
            logger.info(f"Token verified for user: {user_id}")
            
            return {
                'success': True,
                'message': 'Token is valid',
                'user_id': user_id,
                'user_name': user['name'],
                'user_type': user['user_type']
            }
        
        except Exception as e:
            logger.error(f"Token verification error: {str(e)}")
            return {
                'success': False,
                'message': f'Error verifying token: {str(e)}'
            }
    
    # ============================================================
    # HELPER METHODS
    # ============================================================
    
    @staticmethod
    def _generate_random_password(length=12):
        """
        Generate random password for caregiver
        
        Args:
            length: Password length (default: 12)
        
        Returns:
            str: Random password
        """
        # Mix of uppercase, lowercase, digits, and special characters
        characters = string.ascii_letters + string.digits + '!@#$%^&*'
        password = ''.join(random.choice(characters) for _ in range(length))
        return password