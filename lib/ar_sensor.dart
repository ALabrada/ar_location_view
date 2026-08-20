import 'package:geolocator/geolocator.dart';
import 'package:native_device_orientation/native_device_orientation.dart';

/// Reasons why the device location may be unavailable.
enum ArLocationError {
  /// The user denied (or permanently disallowed) location permission.
  permissionDisallowed,

  /// Location services are turned off on the device.
  serviceDisabled,
}

class ArSensor {
  final double heading;
  final double pitch;
  final Position? location;
  final NativeDeviceOrientation orientation;

  final double compassAccuracy;

  /// Set when the device location cannot be obtained, so the view can stop
  /// showing a loading indicator and render an error instead. Null while the
  /// location is simply not available yet.
  final ArLocationError? locationError;

  const ArSensor({
    required this.heading,
    required this.pitch,
    required this.orientation,
    required this.compassAccuracy,
    this.location,
    this.locationError,
  });
}
