import random
import string
from app.models.otp import OTP
from app.services.email_service import EmailService
from app.config import Config
import logging

logger = logging.getLogger(__name__)


class OTPService:
    """OTP service - business logic for OTP operations"""
    
    @staticmethod
    def generate_otp_code(length=6):
        """
        Generate random OTP code
        
        Args:
            length: Length of OTP (default: 6 digits)
        
        Returns:
            str: OTP code (digits only)
        """
        return ''.join(random.choices(string.digits, k=length))
    
    @staticmethod
    def request_otp(email):
        """
        Generate OTP and send to email
        
        Args:
            email: User's email address
        
        Returns:
            dict: success status and message
        """
        try:
            # Validate email
            if not email or '@' not in email:
                return {
                    'success': False,
                    'message': 'Valid email is required'
                }
            
            # Generate OTP code (6 digits)
            otp_code = OTPService.generate_otp_code(Config.OTP_LENGTH)
            
            # Save OTP to database
            success, db_message = OTP.create_otp(email, otp_code)
            
            if not success:
                return {
                    'success': False,
                    'message': db_message
                }
            
            # Send OTP via email
            email_success, email_message = EmailService.send_otp_email(email, otp_code)
            
            if not email_success:
                logger.warning(f"OTP created but email failed for: {email}. Message: {email_message}")
                return {
                    'success': False,
                    'message': 'Failed to send OTP email. Please try again.'
                }
            
            return {
                'success': True,
                'message': 'OTP sent successfully to your email',
                'email': email
            }
        
        except Exception as e:
            logger.error(f"Error requesting OTP: {str(e)}")
            return {
                'success': False,
                'message': f'Error requesting OTP: {str(e)}'
            }
    
    @staticmethod
    def verify_otp(email, otp_code):
        """
        Verify OTP code
        
        Args:
            email: User's email
            otp_code: OTP code to verify
        
        Returns:
            dict: success status and message
        """
        try:
            # Validate inputs
            if not email or not otp_code:
                return {
                    'success': False,
                    'message': 'Email and OTP code are required'
                }
            
            # Verify OTP
            success, message = OTP.verify_otp(email, otp_code)
            
            if success:
                return {
                    'success': True,
                    'message': 'OTP verified successfully',
                    'email': email
                }
            else:
                return {
                    'success': False,
                    'message': message
                }
        
        except Exception as e:
            logger.error(f"Error verifying OTP: {str(e)}")
            return {
                'success': False,
                'message': f'Error verifying OTP: {str(e)}'
            }
    
    @staticmethod
    def check_otp_verified(email):
        """
        Check if OTP is verified for email
        
        Args:
            email: User's email
        
        Returns:
            bool: True if verified, False otherwise
        """
        try:
            return OTP.is_otp_verified(email)
        except Exception as e:
            logger.error(f"Error checking OTP verification: {str(e)}")
            return False
    
    @staticmethod
    def clean_otp(email):
        """
        Delete OTP after successful signup
        
        Args:
            email: User's email
        
        Returns:
            tuple: (success, message)
        """
        try:
            return OTP.delete_otp(email)
        except Exception as e:
            logger.error(f"Error cleaning OTP: {str(e)}")
            return False, f"Error cleaning OTP: {str(e)}"