from app.database import db
from datetime import datetime, timedelta
from app.config import Config
import logging

logger = logging.getLogger(__name__)


class OTP:
    """OTP model for email verification"""
    
    @staticmethod
    def create_otp(email, otp_code):
        """
        Create new OTP record in database
        
        Args:
            email: User's email
            otp_code: 6-digit OTP code
        
        Returns:
            tuple: (success, message)
        """
        try:
            cursor = db.get_cursor()
            connection = db.get_connection()
            
            # Calculate expiry time (20 minutes from now)
            expires_at = datetime.now() + timedelta(minutes=Config.OTP_EXPIRY_MINUTES)
            
            # Delete old OTP for this email if exists
            cursor.execute("DELETE FROM otp_verifications WHERE email = %s", (email,))
            
            # Insert new OTP
            cursor.execute("""
                INSERT INTO otp_verifications 
                (email, otp_code, attempts, expires_at, verified)
                VALUES (%s, %s, %s, %s, %s)
            """, (email, otp_code, 0, expires_at, False))
            
            connection.commit()
            
            logger.info(f"OTP created for email: {email}")
            return True, "OTP created successfully"
        
        except Exception as e:
            db.rollback()
            logger.error(f"Error creating OTP: {str(e)}")
            return False, f"Error creating OTP: {str(e)}"
    
    @staticmethod
    def verify_otp(email, otp_code):
        """
        Verify OTP code for given email
        
        Args:
            email: User's email
            otp_code: OTP code to verify
        
        Returns:
            tuple: (success, message)
        """
        try:
            cursor = db.get_cursor()
            connection = db.get_connection()
            
            # Get OTP record
            cursor.execute("""
                SELECT id, otp_code, attempts, expires_at, verified
                FROM otp_verifications 
                WHERE email = %s
            """, (email,))
            
            otp_record = cursor.fetchone()
            
            # Check if OTP exists
            if not otp_record:
                return False, "OTP not found or expired"
            
            # Check if already verified
            if otp_record['verified']:
                return False, "OTP already verified"
            
            # Check if expired
            if datetime.now() > otp_record['expires_at']:
                return False, "OTP has expired"
            
            # Check max attempts
            if otp_record['attempts'] >= Config.OTP_MAX_ATTEMPTS:
                return False, f"Maximum attempts exceeded. Please request a new OTP"
            
            # Check if OTP code matches
            if otp_record['otp_code'] != otp_code:
                # Increment attempts
                new_attempts = otp_record['attempts'] + 1
                cursor.execute("""
                    UPDATE otp_verifications 
                    SET attempts = %s 
                    WHERE email = %s
                """, (new_attempts, email))
                connection.commit()
                
                remaining = Config.OTP_MAX_ATTEMPTS - new_attempts
                return False, f"Invalid OTP. {remaining} attempts remaining"
            
            # OTP is correct - mark as verified
            cursor.execute("""
                UPDATE otp_verifications 
                SET verified = TRUE, attempts = 0
                WHERE email = %s
            """, (email,))
            
            connection.commit()
            
            logger.info(f"OTP verified successfully for email: {email}")
            return True, "OTP verified successfully"
        
        except Exception as e:
            db.rollback()
            logger.error(f"Error verifying OTP: {str(e)}")
            return False, f"Error verifying OTP: {str(e)}"
    
    @staticmethod
    def is_otp_verified(email):
        """
        Check if OTP is verified for given email
        
        Args:
            email: User's email
        
        Returns:
            bool: True if verified, False otherwise
        """
        try:
            cursor = db.get_cursor()
            cursor.execute("""
                SELECT verified FROM otp_verifications 
                WHERE email = %s AND verified = TRUE
            """, (email,))
            
            result = cursor.fetchone()
            return bool(result)
        
        except Exception as e:
            logger.error(f"Error checking OTP verification: {str(e)}")
            return False
    
    @staticmethod
    def delete_otp(email):
        """
        Delete OTP record after successful signup
        
        Args:
            email: User's email
        
        Returns:
            tuple: (success, message)
        """
        try:
            cursor = db.get_cursor()
            connection = db.get_connection()
            
            cursor.execute("DELETE FROM otp_verifications WHERE email = %s", (email,))
            connection.commit()
            
            logger.info(f"OTP deleted for email: {email}")
            return True, "OTP deleted successfully"
        
        except Exception as e:
            db.rollback()
            logger.error(f"Error deleting OTP: {str(e)}")
            return False, f"Error deleting OTP: {str(e)}"
    
    @staticmethod
    def get_otp_info(email):
        """
        Get OTP info for debugging/testing
        
        Args:
            email: User's email
        
        Returns:
            dict: OTP record or None
        """
        try:
            cursor = db.get_cursor()
            cursor.execute("""
                SELECT id, email, otp_code, attempts, expires_at, verified, created_at
                FROM otp_verifications 
                WHERE email = %s
            """, (email,))
            
            return cursor.fetchone()
        
        except Exception as e:
            logger.error(f"Error getting OTP info: {str(e)}")
            return None