import os
from dotenv import load_dotenv

load_dotenv()

class Config:
    """Base configuration"""
    FLASK_ENV = os.getenv('FLASK_ENV', 'development')
    FLASK_DEBUG = os.getenv('FLASK_DEBUG', False)
    
    # ============================================================
    # DATABASE CONFIGURATION
    # ============================================================
    DB_HOST = os.getenv('DB_HOST', 'localhost')
    DB_USER = os.getenv('DB_USER', 'root')
    DB_PASSWORD = os.getenv('DB_PASSWORD', '')
    DB_NAME = os.getenv('DB_NAME', 'epiguard')
    DB_PORT = int(os.getenv('DB_PORT', 3306))
    
    # ============================================================
    # JWT CONFIGURATION
    # ============================================================
    JWT_SECRET_KEY = os.getenv('JWT_SECRET_KEY', 'your_super_secret_jwt_key_change_this_in_production_12345')
    
    # ============================================================
    # GROQ CONFIGURATION (Optional)
    # ============================================================
    GROQ_API_KEY = os.getenv('GROQ_API_KEY', '')
    
    # ============================================================
    # SECRET KEY
    # ============================================================
    SECRET_KEY = os.getenv('SECRET_KEY', 'dev-secret-key-change-in-production')
    
    # ============================================================
    # EMAIL CONFIGURATION (Gmail SMTP)
    # ============================================================
    MAIL_SERVER = os.getenv('MAIL_SERVER', 'smtp.gmail.com')
    MAIL_PORT = int(os.getenv('MAIL_PORT', 587))
    MAIL_USE_TLS = os.getenv('MAIL_USE_TLS', True)
    MAIL_USERNAME = os.getenv('MAIL_USERNAME', '')
    MAIL_PASSWORD = os.getenv('MAIL_PASSWORD', '')
    MAIL_FROM = os.getenv('MAIL_FROM', 'noreply@epiguard.com')
    
    # ============================================================
    # OTP CONFIGURATION
    # ============================================================
    OTP_LENGTH = 6  # 6 digits
    OTP_EXPIRY_MINUTES = 20  # Expires in 20 minutes
    OTP_MAX_ATTEMPTS = 3  # Max 3 wrong attempts