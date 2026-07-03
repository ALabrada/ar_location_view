import 'package:ar_location_view/ar_location_view.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:native_device_orientation/native_device_orientation.dart';

class _TestAnnotation extends ArAnnotation {
  _TestAnnotation(String uid, Position position)
      : super(uid: uid, position: position);
}

Position _dueNorthOf(Position origin, double latitudeOffset) => Position(
      latitude: origin.latitude + latitudeOffset,
      longitude: origin.longitude,
      timestamp: DateTime(2024),
      accuracy: 1,
      altitude: 0,
      heading: 0,
      speed: 0,
      speedAccuracy: 0,
      altitudeAccuracy: 0,
      headingAccuracy: 0,
    );

void main() {
  const engine = AnnotationLayoutEngine();
  const config = AnnotationLayoutConfig(
    annotationWidth: 200,
    annotationHeight: 75,
    maxVisibleDistance: 1500,
    paddingOverlap: 5,
  );
  final device = _dueNorthOf(
    Position(
      latitude: 0,
      longitude: 0,
      timestamp: DateTime(2024),
      accuracy: 1,
      altitude: 0,
      heading: 0,
      speed: 0,
      speedAccuracy: 0,
      altitudeAccuracy: 0,
      headingAccuracy: 0,
    ),
    0,
  );

  ArSensor sensorFacingNorth() => ArSensor(
        heading: 0,
        pitch: 0,
        orientation: NativeDeviceOrientation.portraitUp,
        compassAccuracy: 1,
        location: device,
      );

  test('stacks annotations that fully overlap onto distinct, ordered rows', () {
    // All three POIs sit due north of the device at the same bearing, so
    // once projected they land at the exact same x - the worst case for
    // horizontal overlap - only distance differs.
    final annotations = [
      _TestAnnotation('near', _dueNorthOf(device, 0.001)),
      _TestAnnotation('mid', _dueNorthOf(device, 0.002)),
      _TestAnnotation('far', _dueNorthOf(device, 0.003)),
    ];

    final result = engine.layout(
      annotations: annotations,
      arSensor: sensorFacingNorth(),
      deviceLocation: device,
      width: 400,
      height: 800,
      config: config,
    );

    expect(
        result.annotations.map((a) => a.uid).toList(), ['near', 'mid', 'far'],
        reason: 'result must stay sorted by distance ascending for '
            "ArView's z-ordering");

    final rowsByUid = {
      for (final a in result.annotations) a.uid: a.arPositionOffset.dy,
    };
    expect(rowsByUid['near'], 0, reason: 'closest POI keeps its natural row');
    expect(rowsByUid.values.toSet().length, 3,
        reason: 'three mutually-overlapping POIs need three distinct rows');
    expect(rowsByUid['mid']! < rowsByUid['near']!, isTrue);
    expect(rowsByUid['far']! < rowsByUid['mid']!, isTrue);
  });

  test('does not shift annotations that do not overlap horizontally', () {
    final annotations = [
      _TestAnnotation('a', _dueNorthOf(device, 0.001)),
    ];

    final result = engine.layout(
      annotations: annotations,
      arSensor: sensorFacingNorth(),
      deviceLocation: device,
      width: 400,
      height: 800,
      config: config,
    );

    expect(result.annotations.single.arPositionOffset, Offset.zero);
  });
}
