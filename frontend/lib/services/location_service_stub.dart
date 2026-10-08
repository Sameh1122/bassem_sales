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
  throw UnimplementedError('Location is not supported on this platform.');
}
