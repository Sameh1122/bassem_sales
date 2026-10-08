import 'dart:async';
import 'dart:html' as html;

class AppLocation {
  final double latitude;
  final double longitude;
  final double accuracy;

  AppLocation({
    required this.latitude,
    required this.longitude,
    required this.accuracy,
  });
}

Future<AppLocation> getCurrentUserLocation() async {
  final geolocation = html.window.navigator.geolocation;
  final geoPosition = await geolocation.getCurrentPosition(
    enableHighAccuracy: true,
    timeout: const Duration(seconds: 15),
  );

  final coords = geoPosition.coords;
  if (coords == null || coords.latitude == null || coords.longitude == null) {
    throw Exception('Browser did not return valid GPS coordinates.');
  }

  return AppLocation(
    latitude: coords.latitude!.toDouble(),
    longitude: coords.longitude!.toDouble(),
    accuracy: coords.accuracy?.toDouble() ?? 0.0,
  );
}
