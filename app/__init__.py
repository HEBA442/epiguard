from flask import Flask, render_template, request, jsonify, redirect, url_for, make_response
from flask_cors import CORS
import logging
from app.config import Config

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

def create_app():
    """
    Application factory pattern for Flask app
    
    Returns:
        Flask application instance
    """
    
    # Create Flask app
    app = Flask(__name__)
    
    # Load configuration
    app.config.from_object(Config)
    
    # Enable CORS for web frontend
    CORS(app, resources={r"/api/*": {"origins": "*"}})

    
    # Register blueprints (routes)
    from app.routes.auth import auth_bp
    from app.routes.user import user_bp
    from app.routes.seizure import seizure_bp


    
    
    
    app.register_blueprint(auth_bp)
    app.register_blueprint(user_bp)
    app.register_blueprint(seizure_bp)


    
    
    # Health check endpoint
    @app.route('/api/health', methods=['GET'])
    def health_check():
        return {
            'status': 'healthy',
            'message': 'EPIGUARD is running'
        }, 200
        
    @app.route('/set-lang/<lang>')
    def set_language(lang):
        if lang not in ['ar', 'en']:
            lang = 'ar'  
        
        response = make_response(redirect(request.referrer or url_for('register_page')))
        
        #cookie for one year
        
        response.set_cookie('lang', lang, max_age=31536000, httponly=True, samesite='Lax')
        
        return response


    

    logger.info("Flask app created successfully")
    
    return app