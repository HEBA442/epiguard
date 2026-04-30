from app.database import db
from werkzeug.security import generate_password_hash, check_password_hash
import datetime
import logging

logger = logging.getLogger(__name__)

class User:
    """User model for both patient and caregiver users"""
    
    @staticmethod
    def create_user(name, email, password, user_type='patient', phone_number=None):
        """
        Create a new user (patient or caregiver)
        
        Args:
            name: User's full name (required)
            email: User's email address (required)
            password: User's password (required)
            user_type: 'patient' or 'caregiver' (default: 'patient')
            phone_number: User's phone number (optional)
        
        Returns: 
            (user_id, message) - user_id if success, None if failed
        """
        try:
            cursor = db.get_cursor()
            connection = db.get_connection()
            
            # Check if email already exists
            cursor.execute("SELECT id FROM users WHERE email = %s", (email,))
            existing_email = cursor.fetchone()
            
            if existing_email:
                return None, "Email already exists"
            
            # Validate user_type
            if user_type not in ['patient', 'caregiver']:
                return None, "Invalid user type. Must be 'patient' or 'caregiver'"
            
            # Validate phone_number if provided
            if phone_number and len(phone_number) < 7:
                return None, "Phone number must be at least 7 characters"
            
            # Hash password
            hashed_password = generate_password_hash(password, method='pbkdf2:sha256')
            
            # Insert user
            cursor.execute("""
                INSERT INTO users (name, email, password, user_type, email_verified, created_at)
                VALUES (%s, %s, %s, %s, %s, %s)
            """, (name, email, hashed_password, user_type, False, datetime.datetime.now()))
            
            connection.commit()
            
            # Get the newly created user ID
            cursor.execute("SELECT LAST_INSERT_ID() as id")
            result = cursor.fetchone()
            user_id = result['id'] if result else None
            
            logger.info(f"User created successfully: {user_id} (type: {user_type})")
            return user_id, "User created successfully"
        
        except Exception as e:
            connection.rollback()
            logger.error(f"Error creating user: {str(e)}")
            return None, f"Error creating user: {str(e)}"
    
    @staticmethod
    def get_user_by_email(email):
        """
        Get user by email
        Returns: user dict or None
        """
        try:
            cursor = db.get_cursor()
            cursor.execute("""
                SELECT id, name, email, password, user_type, email_verified 
                FROM users 
                WHERE email = %s
            """, (email,))
            user = cursor.fetchone()
            return user
        except Exception as e:
            logger.error(f"Error getting user by email: {str(e)}")
            return None
    
    @staticmethod
    def get_user_by_id(user_id):
        """
        Get user by ID
        Returns: user dict or None
        """
        try:
            cursor = db.get_cursor()
            cursor.execute("""
                SELECT id, name, email, user_type, email_verified, created_at, updated_at 
                FROM users 
                WHERE id = %s
            """, (user_id,))
            user = cursor.fetchone()
            return user
        except Exception as e:
            logger.error(f"Error getting user by ID: {str(e)}")
            return None
    
    @staticmethod
    def verify_password(stored_password_hash, provided_password):
        """
        Verify password
        Returns: True if password matches, False otherwise
        """
        try:
            return check_password_hash(stored_password_hash, provided_password)
        except Exception as e:
            logger.error(f"Error verifying password: {str(e)}")
            return False
    
    @staticmethod
    def update_password(user_id, new_password):
        """
        Update user's password
        
        Args:
            user_id: User ID
            new_password: New password (plain text)
        
        Returns:
            tuple: (success: bool, message: str)
        """
        try:
            # Validate password
            if not new_password or len(new_password) < 6:
                return False, "Password must be at least 6 characters"
            
            # Hash the new password
            hashed_password = generate_password_hash(new_password, method='pbkdf2:sha256')
            
            # Update password in database
            cursor = db.get_cursor()
            connection = db.get_connection()
            
            cursor.execute("""
                UPDATE users 
                SET password = %s, updated_at = NOW()
                WHERE id = %s
            """, (hashed_password, user_id))
            
            connection.commit()
            
            logger.info(f"Password updated successfully for user: {user_id}")
            return True, "Password updated successfully"
        
        except Exception as e:
            connection.rollback()
            logger.error(f"Error updating password: {str(e)}")
            return False, f"Error updating password: {str(e)}"
    
    @staticmethod
    def mark_email_verified(user_id):
        """
        Mark user's email as verified after OTP verification
        
        Args:
            user_id: User ID
        
        Returns:
            tuple: (success: bool, message: str)
        """
        try:
            cursor = db.get_cursor()
            connection = db.get_connection()
            
            cursor.execute("""
                UPDATE users 
                SET email_verified = TRUE, updated_at = NOW()
                WHERE id = %s
            """, (user_id,))
            
            connection.commit()
            
            logger.info(f"Email marked as verified for user: {user_id}")
            return True, "Email verified successfully"
        
        except Exception as e:
            connection.rollback()
            logger.error(f"Error marking email as verified: {str(e)}")
            return False, f"Error marking email as verified: {str(e)}"
    
    @staticmethod
    def is_email_verified(user_id):
        """
        Check if user's email is verified
        
        Args:
            user_id: User ID
        
        Returns:
            bool: True if verified, False otherwise
        """
        try:
            cursor = db.get_cursor()
            cursor.execute("""
                SELECT email_verified FROM users WHERE id = %s
            """, (user_id,))
            
            result = cursor.fetchone()
            return result['email_verified'] if result else False
        
        except Exception as e:
            logger.error(f"Error checking email verification: {str(e)}")
            return False
    
    @staticmethod
    def get_user_type(user_id):
        """
        Get user's type (patient or caregiver)
        
        Args:
            user_id: User ID
        
        Returns:
            str: 'patient', 'caregiver', or None
        """
        try:
            cursor = db.get_cursor()
            cursor.execute("""
                SELECT user_type FROM users WHERE id = %s
            """, (user_id,))
            
            result = cursor.fetchone()
            return result['user_type'] if result else None
        
        except Exception as e:
            logger.error(f"Error getting user type: {str(e)}")
            return None

    @staticmethod
    def update_fcm_token(user_id, fcm_token):
        """
        Save or update a user's FCM device token.
        Called when the caregiver logs in or the token refreshes.

        Args:
            user_id:   User ID
            fcm_token: Firebase Cloud Messaging device token

        Returns:
            bool: True if successful
        """
        try:
            cursor = db.get_cursor()
            connection = db.get_connection()

            cursor.execute("""
                UPDATE users SET fcm_token = %s WHERE id = %s
            """, (fcm_token, user_id))

            connection.commit()
            logger.info(f"FCM token updated for user {user_id}")
            return True

        except Exception as e:
            db.rollback()
            logger.error(f"Error updating FCM token: {str(e)}")
            return False

    @staticmethod
    def get_fcm_token(user_id):
        """
        Retrieve a user's FCM device token.

        Args:
            user_id: User ID

        Returns:
            str: FCM token or None
        """
        try:
            cursor = db.get_cursor()
            cursor.execute("""
                SELECT fcm_token FROM users WHERE id = %s
            """, (user_id,))

            result = cursor.fetchone()
            return result['fcm_token'] if result else None

        except Exception as e:
            logger.error(f"Error getting FCM token: {str(e)}")
            return None