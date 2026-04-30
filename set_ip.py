"""
EpiGuard — Dynamic IP Configurator
===================================
Run this script before starting the Flutter app whenever your
laptop's IP address has changed (e.g. new Wi-Fi network).

Usage:
    python set_ip.py

What it does:
    1. Auto-detects your laptop's current LAN IP address.
    2. Overwrites the baseUrl in client/lib/core/api_endpoints.dart.
    3. Prints a confirmation so you know exactly what the app will connect to.
"""

import socket
import re
import os

API_ENDPOINTS_PATH = os.path.join(
    os.path.dirname(__file__),
    'client', 'lib', 'core', 'api_endpoints.dart'
)
PORT = 5000


def get_lan_ip() -> str:
    """
    Returns the machine's current LAN IP address.
    Falls back to 127.0.0.1 if detection fails.
    """
    try:
        # Connect to an external address (does not send data) to find the correct interface
        with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as s:
            s.connect(('8.8.8.8', 80))
            return s.getsockname()[0]
    except Exception:
        return '127.0.0.1'


def update_api_endpoints(ip: str) -> None:
    """
    Replaces the baseUrl line in api_endpoints.dart with the new IP.
    """
    if not os.path.exists(API_ENDPOINTS_PATH):
        print(f"[ERROR] Could not find: {API_ENDPOINTS_PATH}")
        print("        Make sure you're running this script from the project root.")
        return

    with open(API_ENDPOINTS_PATH, 'r', encoding='utf-8') as f:
        content = f.read()

    new_url = f'http://{ip}:{PORT}'

    # Replace the baseUrl line regardless of what IP was there before
    updated = re.sub(
        r"static const String baseUrl\s*=\s*'[^']*';",
        f"static const String baseUrl = '{new_url}';",
        content
    )

    if updated == content:
        print("[WARN] No baseUrl line found to update. Check api_endpoints.dart manually.")
        return

    with open(API_ENDPOINTS_PATH, 'w', encoding='utf-8') as f:
        f.write(updated)

    print(f"[OK] baseUrl updated to: {new_url}")
    print(f"[OK] File updated: {API_ENDPOINTS_PATH}")


if __name__ == '__main__':
    lan_ip = get_lan_ip()
    print(f"\n[INFO] Detected LAN IP: {lan_ip}")
    print(f"[INFO] Flask should be running on: http://{lan_ip}:{PORT}")
    print(f"[INFO] Make sure your phone is on the same Wi-Fi!\n")
    update_api_endpoints(lan_ip)
    print("\nDone! Now restart your Flutter app.\n")
