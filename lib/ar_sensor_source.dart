import 'ar_sensor.dart';

/// Source of fused sensor + location samples consumed by [ArView].
///
/// [ArSensorManager] is the default, device-backed implementation. Provide
/// your own implementation (e.g. a fake/test double) via [ArView.sensorSource]
/// to avoid depending on real hardware.
abstract class ArSensorSource {
  /// Starts listening to the underlying sensors and location updates.
  void init();

  /// Stream of fused sensor samples.
  Stream<ArSensor> get arSensor;

  /// Stops listening and releases resources.
  void dispose();
}
