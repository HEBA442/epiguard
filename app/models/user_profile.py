from app.database import db
import datetime
import logging

logger = logging.getLogger(__name__)


class UserProfile:
    """User Profile model - simplified without learning style/quiz"""
    
    @staticmethod
    def create_profile(user_id, age=None, epilepsy_duration=None):
        """
        Create a new user profile
        
        Args:
            user_id: User ID (required)
            age: User's age (optional)
            epilepsy_duration: How long user has epilepsy (optional, e.g., "3 years")
        
        Returns: 
            (profile_id, message)
        """
        try:
            cursor = db.get_cursor()
            connection = db.get_connection()
            
            # Insert profile with basic fields
            cursor.execute("""
                INSERT INTO user_profile 
                (user_id, age, epilepsy_duration, created_at)
                VALUES (%s, %s, %s, %s)
            """, (user_id, age, epilepsy_duration, datetime.datetime.now()))
            
            connection.commit()
            
            # Get the newly created profile ID
            cursor.execute("SELECT LAST_INSERT_ID() as id")
            result = cursor.fetchone()
            profile_id = result['id'] if result else None
            
            logger.info(f"Profile created successfully: {profile_id}")
            return profile_id, "Profile created successfully"
        
        except Exception as e:
            connection.rollback()
            logger.error(f"Error creating profile: {str(e)}")
            return None, f"Error creating profile: {str(e)}"
    
    @staticmethod
    def get_profile_by_user(user_id):
        """
        Get user profile by user_id
        
        Args:
            user_id: User ID
        
        Returns: 
            profile dict or None
        """
        try:
            cursor = db.get_cursor()
            cursor.execute("""
                SELECT 
                    id, user_id, age, epilepsy_duration, bio, phone_number,
                    profile_picture, created_at, updated_at
                FROM user_profile 
                WHERE user_id = %s
            """, (user_id,))
            
            profile = cursor.fetchone()
            return profile
        
        except Exception as e:
            logger.error(f"Error getting profile: {str(e)}")
            return None
    
    @staticmethod
    def update_profile(user_id, **kwargs):
        """
        Update user profile fields
        
        Args:
            user_id: User ID
            **kwargs: Fields to update (age, epilepsy_duration, bio, phone_number, profile_picture)
        
        Returns: 
            (success, message)
        """
        try:
            cursor = db.get_cursor()
            connection = db.get_connection()
            
            # Build dynamic update query
            allowed_fields = ['age', 'epilepsy_duration', 'bio', 'phone_number', 'profile_picture']
            updates = {k: v for k, v in kwargs.items() if k in allowed_fields and v is not None}
            
            if not updates:
                return False, "No valid fields to update"
            
            set_clause = ", ".join([f"{k} = %s" for k in updates.keys()])
            values = list(updates.values()) + [user_id]
            
            query = f"UPDATE user_profile SET {set_clause}, updated_at = NOW() WHERE user_id = %s"
            cursor.execute(query, values)
            
            connection.commit()
            
            logger.info(f"Profile updated successfully for user: {user_id}")
            return True, "Profile updated successfully"
        
        except Exception as e:
            connection.rollback()
            logger.error(f"Error updating profile: {str(e)}")
            return False, f"Error updating profile: {str(e)}"
    
    @staticmethod
    def update_age(user_id, age):
        """
        Update user's age
        
        Args:
            user_id: User ID
            age: Age (integer)
        
        Returns:
            tuple: (success, message)
        """
        try:
            cursor = db.get_cursor()
            connection = db.get_connection()
            
            cursor.execute("""
                UPDATE user_profile 
                SET age = %s, updated_at = NOW()
                WHERE user_id = %s
            """, (age, user_id))
            
            connection.commit()
            
            logger.info(f"Age updated for user: {user_id}")
            return True, "Age updated successfully"
        
        except Exception as e:
            connection.rollback()
            logger.error(f"Error updating age: {str(e)}")
            return False, f"Error updating age: {str(e)}"
    
    @staticmethod
    def update_epilepsy_duration(user_id, epilepsy_duration):
        """
        Update user's epilepsy duration
        
        Args:
            user_id: User ID
            epilepsy_duration: Duration description (e.g., "3 years", "6 months")
        
        Returns:
            tuple: (success, message)
        """
        try:
            cursor = db.get_cursor()
            connection = db.get_connection()
            
            cursor.execute("""
                UPDATE user_profile 
                SET epilepsy_duration = %s, updated_at = NOW()
                WHERE user_id = %s
            """, (epilepsy_duration, user_id))
            
            connection.commit()
            
            logger.info(f"Epilepsy duration updated for user: {user_id}")
            return True, "Epilepsy duration updated successfully"
        
        except Exception as e:
            connection.rollback()
            logger.error(f"Error updating epilepsy duration: {str(e)}")
            return False, f"Error updating epilepsy duration: {str(e)}"
    
    @staticmethod
    def get_age(user_id):
        """
        Get user's age
        
        Args:
            user_id: User ID
        
        Returns:
            int: Age or None
        """
        try:
            cursor = db.get_cursor()
            cursor.execute("""
                SELECT age FROM user_profile WHERE user_id = %s
            """, (user_id,))
            
            result = cursor.fetchone()
            return result['age'] if result else None
        
        except Exception as e:
            logger.error(f"Error getting age: {str(e)}")
            return None
    
    @staticmethod
    def get_epilepsy_duration(user_id):
        """
        Get user's epilepsy duration
        
        Args:
            user_id: User ID
        
        Returns:
            str: Epilepsy duration or None
        """
        try:
            cursor = db.get_cursor()
            cursor.execute("""
                SELECT epilepsy_duration FROM user_profile WHERE user_id = %s
            """, (user_id,))
            
            result = cursor.fetchone()
            return result['epilepsy_duration'] if result else None
        
        except Exception as e:
            logger.error(f"Error getting epilepsy duration: {str(e)}")
            return None