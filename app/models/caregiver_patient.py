from app.database import db
import logging

logger = logging.getLogger(__name__)


class CaregiverPatientLink:
    """Model for managing caregiver-patient relationships"""
    
    @staticmethod
    def create_link(caregiver_id, patient_id, relation):
        """
        Create link between caregiver and patient
        
        Args:
            caregiver_id: Caregiver user ID
            patient_id: Patient user ID
            relation: Relation description (text input from form)
        
        Returns:
            tuple: (link_id, message)
        """
        try:
            cursor = db.get_cursor()
            connection = db.get_connection()
            
            # Check if link already exists
            cursor.execute("""
                SELECT id FROM caregiver_patient_links 
                WHERE caregiver_id = %s AND patient_id = %s
            """, (caregiver_id, patient_id))
            
            existing_link = cursor.fetchone()
            if existing_link:
                return None, "Link already exists between this caregiver and patient"
            
            # Create new link
            cursor.execute("""
                INSERT INTO caregiver_patient_links 
                (caregiver_id, patient_id, relation)
                VALUES (%s, %s, %s)
            """, (caregiver_id, patient_id, relation))
            
            connection.commit()
            
            # Get the newly created link ID
            cursor.execute("SELECT LAST_INSERT_ID() as id")
            result = cursor.fetchone()
            link_id = result['id'] if result else None
            
            logger.info(f"Caregiver-Patient link created: caregiver_id={caregiver_id}, patient_id={patient_id}")
            return link_id, "Link created successfully"
        
        except Exception as e:
            db.rollback()
            logger.error(f"Error creating caregiver-patient link: {str(e)}")
            return None, f"Error creating link: {str(e)}"
    
    @staticmethod
    def get_link_by_ids(caregiver_id, patient_id):
        """
        Get link between specific caregiver and patient
        
        Args:
            caregiver_id: Caregiver user ID
            patient_id: Patient user ID
        
        Returns:
            dict: Link record or None
        """
        try:
            cursor = db.get_cursor()
            cursor.execute("""
                SELECT id, caregiver_id, patient_id, relation, created_at
                FROM caregiver_patient_links 
                WHERE caregiver_id = %s AND patient_id = %s
            """, (caregiver_id, patient_id))
            
            return cursor.fetchone()
        
        except Exception as e:
            logger.error(f"Error getting caregiver-patient link: {str(e)}")
            return None
    
    @staticmethod
    def get_patients_for_caregiver(caregiver_id):
        """
        Get all patients for a specific caregiver
        
        Args:
            caregiver_id: Caregiver user ID
        
        Returns:
            list: List of patient records with relation
        """
        try:
            cursor = db.get_cursor()
            cursor.execute("""
                SELECT 
                    cpl.id as link_id,
                    cpl.relation,
                    u.id as patient_id,
                    u.name as patient_name,
                    u.email as patient_email,
                    up.age,
                    up.epilepsy_duration
                FROM caregiver_patient_links cpl
                JOIN users u ON cpl.patient_id = u.id
                LEFT JOIN user_profile up ON u.id = up.user_id
                WHERE cpl.caregiver_id = %s
                ORDER BY cpl.created_at DESC
            """, (caregiver_id,))
            
            return cursor.fetchall()
        
        except Exception as e:
            logger.error(f"Error getting patients for caregiver: {str(e)}")
            return []
    
    @staticmethod
    def get_caregivers_for_patient(patient_id):
        """
        Get all caregivers for a specific patient
        
        Args:
            patient_id: Patient user ID
        
        Returns:
            list: List of caregiver records with relation
        """
        try:
            cursor = db.get_cursor()
            cursor.execute("""
                SELECT 
                    cpl.id as link_id,
                    cpl.relation,
                    u.id as caregiver_id,
                    u.name as caregiver_name,
                    u.email as caregiver_email
                FROM caregiver_patient_links cpl
                JOIN users u ON cpl.caregiver_id = u.id
                WHERE cpl.patient_id = %s
                ORDER BY cpl.created_at DESC
            """, (patient_id,))
            
            return cursor.fetchall()
        
        except Exception as e:
            logger.error(f"Error getting caregivers for patient: {str(e)}")
            return []
    
    @staticmethod
    def update_relation(caregiver_id, patient_id, relation):
        """
        Update relation description between caregiver and patient
        
        Args:
            caregiver_id: Caregiver user ID
            patient_id: Patient user ID
            relation: New relation description
        
        Returns:
            tuple: (success, message)
        """
        try:
            cursor = db.get_cursor()
            connection = db.get_connection()
            
            cursor.execute("""
                UPDATE caregiver_patient_links 
                SET relation = %s
                WHERE caregiver_id = %s AND patient_id = %s
            """, (relation, caregiver_id, patient_id))
            
            connection.commit()
            
            logger.info(f"Relation updated for caregiver_id={caregiver_id}, patient_id={patient_id}")
            return True, "Relation updated successfully"
        
        except Exception as e:
            db.rollback()
            logger.error(f"Error updating relation: {str(e)}")
            return False, f"Error updating relation: {str(e)}"
    
    @staticmethod
    def delete_link(caregiver_id, patient_id):
        """
        Delete link between caregiver and patient
        
        Args:
            caregiver_id: Caregiver user ID
            patient_id: Patient user ID
        
        Returns:
            tuple: (success, message)
        """
        try:
            cursor = db.get_cursor()
            connection = db.get_connection()
            
            cursor.execute("""
                DELETE FROM caregiver_patient_links 
                WHERE caregiver_id = %s AND patient_id = %s
            """, (caregiver_id, patient_id))
            
            connection.commit()
            
            logger.info(f"Link deleted: caregiver_id={caregiver_id}, patient_id={patient_id}")
            return True, "Link deleted successfully"
        
        except Exception as e:
            db.rollback()
            logger.error(f"Error deleting link: {str(e)}")
            return False, f"Error deleting link: {str(e)}"
    
    @staticmethod
    def link_exists(caregiver_id, patient_id):
        """
        Check if link exists between caregiver and patient
        
        Args:
            caregiver_id: Caregiver user ID
            patient_id: Patient user ID
        
        Returns:
            bool: True if link exists, False otherwise
        """
        try:
            cursor = db.get_cursor()
            cursor.execute("""
                SELECT id FROM caregiver_patient_links 
                WHERE caregiver_id = %s AND patient_id = %s
            """, (caregiver_id, patient_id))
            
            result = cursor.fetchone()
            return bool(result)
        
        except Exception as e:
            logger.error(f"Error checking link existence: {str(e)}")
            return False