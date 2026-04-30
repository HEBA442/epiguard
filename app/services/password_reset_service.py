from app.models.user import User
from app.services.otp_service import OTPService
from app.services.email_service import EmailService
import logging

logger = logging.getLogger(__name__)


class PasswordResetService:
    """Password reset service - business logic for forgot password"""
    
    # ============================================================
    # STEP 1: REQUEST PASSWORD RESET
    # ============================================================
    
    @staticmethod
    def request_password_reset(email):
        """
        Request password reset - send OTP to user's email
        
        Args:
            email: User's email address
        
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
            
            # Check if user exists
            user = User.get_user_by_email(email)
            
            if not user:
                return {
                    'success': False,
                    'message': 'No account found with this email address'
                }
            
            user_id = user['id']
            
            # Request OTP via OTPService (generates + sends OTP)
            otp_result = OTPService.request_otp(email)
            
            if not otp_result['success']:
                return {
                    'success': False,
                    'message': otp_result['message']
                }
            
            logger.info(f"Password reset requested for user: {user_id} (email: {email})")
            
            return {
                'success': True,
                'message': 'Password reset OTP sent to your email',
                'email': email,
                'user_id': user_id
            }
        
        except Exception as e:
            logger.error(f"Request password reset error: {str(e)}")
            return {
                'success': False,
                'message': f'Error requesting password reset: {str(e)}'
            }
    
    # ============================================================
    # STEP 2: RESET PASSWORD (With OTP Verification)
    # ============================================================
    
    @staticmethod
    def reset_password(email, otp_code, new_password):
        """
        Reset user's password using OTP verification
        
        Args:
            email: User's email address
            otp_code: OTP code from email
            new_password: New password (plain text)
        
        Returns:
            dict with success status
        """
        try:
            # Validate inputs
            if not email or '@' not in email:
                return {
                    'success': False,
                    'message': 'Valid email is required'
                }
            
            if not otp_code:
                return {
                    'success': False,
                    'message': 'OTP code is required'
                }
            
            if not new_password:
                return {
                    'success': False,
                    'message': 'New password is required'
                }
            
            if len(new_password) < 6:
                return {
                    'success': False,
                    'message': 'Password must be at least 6 characters'
                }
            
            # Normalize email
            email = email.strip().lower()
            
            # Verify OTP
            otp_result = OTPService.verify_otp(email, otp_code)
            
            if not otp_result['success']:
                return {
                    'success': False,
                    'message': otp_result['message']
                }
            
            # Get user
            user = User.get_user_by_email(email)
            
            if not user:
                return {
                    'success': False,
                    'message': 'User not found'
                }
            
            user_id = user['id']
            
            # Update password
            password_success, password_message = User.update_password(user_id, new_password)
            
            if not password_success:
                return {
                    'success': False,
                    'message': password_message
                }
            
            # Clean up OTP after successful password reset
            OTPService.clean_otp(email)
            
            logger.info(f"Password reset successfully for user: {user_id} (email: {email})")
            
            return {
                'success': True,
                'message': 'Password reset successfully. You can now login with your new password.',
                'user_id': user_id,
                'email': email
            }
        
        except Exception as e:
            logger.error(f"Reset password error: {str(e)}")
            return {
                'success': False,
                'message': f'Error resetting password: {str(e)}'
            }