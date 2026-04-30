import smtplib
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart
from app.config import Config
import logging

logger = logging.getLogger(__name__)


class EmailService:
    """Email service for sending OTP and credentials"""
    
    @staticmethod
    def send_otp_email(recipient_email, otp_code):
        """
        Send OTP code via email
        
        Args:
            recipient_email: Recipient's email address
            otp_code: 6-digit OTP code
        
        Returns:
            tuple: (success, message)
        """
        try:
            # Validate email
            if not recipient_email or '@' not in recipient_email:
                return False, "Invalid email address"
            
            # Email subject and body
            subject = "EPIGUARD - Email Verification OTP"
            
            html_body = f"""
            <html>
                <body style="font-family: Arial, sans-serif; background-color: #f5f5f5; padding: 20px;">
                    <div style="max-width: 600px; margin: 0 auto; background-color: white; padding: 30px; border-radius: 8px; box-shadow: 0 2px 4px rgba(0,0,0,0.1);">
                        
                        <h2 style="color: #333; text-align: center;">Email Verification</h2>
                        
                        <p style="color: #666; font-size: 16px; line-height: 1.6;">
                            Welcome to <strong>EPIGUARD</strong>!
                        </p>
                        
                        <p style="color: #666; font-size: 16px; line-height: 1.6;">
                            To complete your registration, please use the following OTP code:
                        </p>
                        
                        <div style="background-color: #f0f0f0; padding: 20px; border-radius: 4px; text-align: center; margin: 30px 0;">
                            <p style="font-size: 36px; font-weight: bold; color: #2196F3; letter-spacing: 5px; margin: 0;">
                                {otp_code}
                            </p>
                        </div>
                        
                        <p style="color: #999; font-size: 14px;">
                            This OTP code will expire in 20 minutes.
                        </p>
                        
                        <p style="color: #666; font-size: 16px; line-height: 1.6;">
                            If you did not request this code, please ignore this email.
                        </p>
                        
                        <hr style="border: none; border-top: 1px solid #ddd; margin: 30px 0;">
                        
                        <p style="color: #999; font-size: 12px; text-align: center;">
                            EPIGUARD - Your Learning Companion<br>
                            This is an automated email. Please do not reply.
                        </p>
                        
                    </div>
                </body>
            </html>
            """
            
            # Send email
            success = EmailService._send_email(recipient_email, subject, html_body)
            
            if success:
                logger.info(f"OTP email sent to: {recipient_email}")
                return True, "OTP sent successfully"
            else:
                return False, "Failed to send OTP email"
        
        except Exception as e:
            logger.error(f"Error sending OTP email: {str(e)}")
            return False, f"Error sending email: {str(e)}"
    
    @staticmethod
    def send_caregiver_credentials_email(recipient_email, caregiver_email, caregiver_password, patient_name):
        """
        Send caregiver login credentials via email
        
        Args:
            recipient_email: Email to send to
            caregiver_email: Caregiver's email (username)
            caregiver_password: Auto-generated password
            patient_name: Name of the patient they're caring for
        
        Returns:
            tuple: (success, message)
        """
        try:
            # Validate email
            if not recipient_email or '@' not in recipient_email:
                return False, "Invalid email address"
            
            # Email subject and body
            subject = "EPIGUARD - Your Caregiver Account Credentials"
            
            html_body = f"""
            <html>
                <body style="font-family: Arial, sans-serif; background-color: #f5f5f5; padding: 20px;">
                    <div style="max-width: 600px; margin: 0 auto; background-color: white; padding: 30px; border-radius: 8px; box-shadow: 0 2px 4px rgba(0,0,0,0.1);">
                        
                        <h2 style="color: #333; text-align: center;">Welcome to EPIGUARD</h2>
                        
                        <p style="color: #666; font-size: 16px; line-height: 1.6;">
                            Hello,
                        </p>
                        
                        <p style="color: #666; font-size: 16px; line-height: 1.6;">
                            A caregiver account has been created for you as a caregiver of <strong>{patient_name}</strong>.
                        </p>
                        
                        <p style="color: #666; font-size: 16px; line-height: 1.6;">
                            Your login credentials are:
                        </p>
                        
                        <div style="background-color: #f0f0f0; padding: 20px; border-radius: 4px; margin: 30px 0;">
                            <p style="color: #333; margin: 10px 0;">
                                <strong>Email (Username):</strong> {caregiver_email}
                            </p>
                            <p style="color: #333; margin: 10px 0;">
                                <strong>Password:</strong> {caregiver_password}
                            </p>
                        </div>
                        
                        <p style="color: #e74c3c; font-size: 14px; font-weight: bold;">
                            ⚠️ Important: Please change your password after your first login. You will not be able to change your email address.
                        </p>
                        
                        <p style="color: #666; font-size: 16px; line-height: 1.6; margin-top: 20px;">
                            You can now login to EPIGUARD and start supporting {patient_name}'s learning journey.
                        </p>
                        
                        <hr style="border: none; border-top: 1px solid #ddd; margin: 30px 0;">
                        
                        <p style="color: #999; font-size: 12px; text-align: center;">
                            EPIGUARD - Your Learning Companion<br>
                            This is an automated email. Please do not reply.
                        </p>
                        
                    </div>
                </body>
            </html>
            """
            
            # Send email
            success = EmailService._send_email(recipient_email, subject, html_body)
            
            if success:
                logger.info(f"Caregiver credentials email sent to: {recipient_email}")
                return True, "Credentials sent successfully"
            else:
                return False, "Failed to send credentials email"
        
        except Exception as e:
            logger.error(f"Error sending caregiver credentials email: {str(e)}")
            return False, f"Error sending email: {str(e)}"
    
    @staticmethod
    def send_patient_signup_confirmation_email(recipient_email, patient_name):
        """
        Send signup confirmation email to patient
        
        Args:
            recipient_email: Patient's email
            patient_name: Patient's name
        
        Returns:
            tuple: (success, message)
        """
        try:
            # Validate email
            if not recipient_email or '@' not in recipient_email:
                return False, "Invalid email address"
            
            # Email subject and body
            subject = "EPIGUARD - Welcome! Your Account is Ready"
            
            html_body = f"""
            <html>
                <body style="font-family: Arial, sans-serif; background-color: #f5f5f5; padding: 20px;">
                    <div style="max-width: 600px; margin: 0 auto; background-color: white; padding: 30px; border-radius: 8px; box-shadow: 0 2px 4px rgba(0,0,0,0.1);">
                        
                        <h2 style="color: #333; text-align: center;">Welcome to EPIGUARD!</h2>
                        
                        <p style="color: #666; font-size: 16px; line-height: 1.6;">
                            Hello {patient_name},
                        </p>
                        
                        <p style="color: #666; font-size: 16px; line-height: 1.6;">
                            Your account has been successfully created! You are now ready to use EPIGUARD.
                        </p>
                        
                        <p style="color: #666; font-size: 16px; line-height: 1.6;">
                            Your caregiver will receive their login credentials separately and can start supporting your learning journey right away.
                        </p>
                        
                        <p style="color: #666; font-size: 16px; line-height: 1.6;">
                            You can now login with:
                        </p>
                        
                        <div style="background-color: #f0f0f0; padding: 20px; border-radius: 4px; margin: 30px 0;">
                            <p style="color: #333; margin: 10px 0;">
                                <strong>Email:</strong> {recipient_email}
                            </p>
                            <p style="color: #333; margin: 10px 0;">
                                <strong>Password:</strong> The password you set during signup
                            </p>
                        </div>
                        
                        <p style="color: #666; font-size: 16px; line-height: 1.6;">
                            Get started with EPIGUARD and begin your personalized learning experience!
                        </p>
                        
                        <hr style="border: none; border-top: 1px solid #ddd; margin: 30px 0;">
                        
                        <p style="color: #999; font-size: 12px; text-align: center;">
                            EPIGUARD - Your Learning Companion<br>
                            This is an automated email. Please do not reply.
                        </p>
                        
                    </div>
                </body>
            </html>
            """
            
            # Send email
            success = EmailService._send_email(recipient_email, subject, html_body)
            
            if success:
                logger.info(f"Signup confirmation email sent to: {recipient_email}")
                return True, "Confirmation email sent successfully"
            else:
                return False, "Failed to send confirmation email"
        
        except Exception as e:
            logger.error(f"Error sending signup confirmation email: {str(e)}")
            return False, f"Error sending email: {str(e)}"
    
    @staticmethod
    def _send_email(recipient_email, subject, html_body):
        """
        Internal method to send email via Gmail SMTP
        
        Args:
            recipient_email: Recipient's email address
            subject: Email subject
            html_body: Email body in HTML format
        
        Returns:
            bool: True if successful, False otherwise
        """
        try:
            # Create message
            message = MIMEMultipart('alternative')
            message['From'] = Config.MAIL_FROM
            message['To'] = recipient_email
            message['Subject'] = subject
            
            # Attach HTML body
            part = MIMEText(html_body, 'html')
            message.attach(part)
            
            # Create SMTP session
            server = smtplib.SMTP(Config.MAIL_SERVER, Config.MAIL_PORT)
            server.starttls()  # Enable TLS encryption
            
            # Login to Gmail
            server.login(Config.MAIL_USERNAME, Config.MAIL_PASSWORD)
            
            # Send email
            server.sendmail(Config.MAIL_USERNAME, recipient_email, message.as_string())
            
            # Close connection
            server.quit()
            
            logger.info(f"Email sent successfully to: {recipient_email}")
            return True
        
        except smtplib.SMTPAuthenticationError:
            logger.error("Gmail SMTP authentication failed. Check your email and app password.")
            return False
        except smtplib.SMTPException as e:
            logger.error(f"SMTP error while sending email: {str(e)}")
            return False
        except Exception as e:
            logger.error(f"Error sending email: {str(e)}")
            return False