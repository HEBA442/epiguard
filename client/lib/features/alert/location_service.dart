import 'package:geolocator/geolocator.dart';

class LocationService {
  /// Fetches the current GPS position.
  /// Returns null if permission is denied or location is unavailable.
  static Future<Position?> getCurrentLocation() async {
    try {
      // Check if location services are enabled
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return null;

      // Check & request permission
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return null;
      }
      if (permission == LocationPermission.deniedForever) return null;

      // Get position with high accuracy, timeout after 10 seconds
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );
    } catch (_) {
      return null;
    }
  }

  /// Converts a Position into a Google Maps link for sharing.
  static String toGoogleMapsLink(Position position) {
    return 'https://maps.google.com/?q=${position.latitude},${position.longitude}';
  }
}
