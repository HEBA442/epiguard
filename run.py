import socket
import threading
import logging
from app import create_app

logger = logging.getLogger(__name__)


def get_local_ip():
    """Get the machine's LAN IP address."""
    try:
        with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as s:
            s.connect(('8.8.8.8', 80))
            return s.getsockname()[0]
    except Exception:
        return '127.0.0.1'


def start_mdns(port=5000):
    """
    Broadcast this Flask server on the local network as:
        _epiguard._tcp.local.
    The Flutter app will discover it automatically via mDNS.
    """
    try:
        from zeroconf import ServiceInfo, Zeroconf

        local_ip = get_local_ip()
        zeroconf = Zeroconf()

        info = ServiceInfo(
            '_epiguard._tcp.local.',
            'EpiGuard._epiguard._tcp.local.',
            addresses=[socket.inet_aton(local_ip)],
            port=port,
            properties={'version': '1.0'},
        )

        zeroconf.register_service(info)
        logger.info(f'[mDNS] EpiGuard server announced at {local_ip}:{port}')
        print(f'\n  [mDNS] Broadcasting as EpiGuard._epiguard._tcp.local.')
        print(f'  [mDNS] Phone will auto-discover at http://{local_ip}:{port}\n')
        return zeroconf, info

    except ImportError:
        print('\n  [mDNS] zeroconf not installed — run: pip install zeroconf')
        print('  [mDNS] Falling back to hardcoded IP mode.\n')
        return None, None
    except Exception as e:
        print(f'\n  [mDNS] Failed to start: {e}\n')
        return None, None


if __name__ == '__main__':
    PORT = 5000

    # Start mDNS in a background thread so Flask isn't blocked
    zeroconf, mdns_info = start_mdns(PORT)

    app = create_app()

    try:
        app.run(debug=True, host='0.0.0.0', port=PORT, use_reloader=False)
    finally:
        # Clean up mDNS on exit
        if zeroconf and mdns_info:
            zeroconf.unregister_service(mdns_info)
            zeroconf.close()