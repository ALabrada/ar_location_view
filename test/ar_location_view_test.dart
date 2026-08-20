import 'dart:async';

import 'package:ar_location_view/ar_location_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:native_device_orientation/native_device_orientation.dart';

class _FakeSensorSource implements ArSensorSource {
  final StreamController<ArSensor> controller = StreamController<ArSensor>();

  @override
  void init() {}

  @override
  Stream<ArSensor> get arSensor => controller.stream;

  @override
  void dispose() {
    controller.close();
  }

  void emit(ArSensor sensor) => controller.add(sensor);
}

ArSensor _sensor({ArLocationError? locationError, Position? location}) =>
    ArSensor(
      heading: 0,
      pitch: 0,
      orientation: NativeDeviceOrientation.portraitUp,
      compassAccuracy: 1,
      location: location,
      locationError: locationError,
    );

Position _position() => Position(
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
    );

void main() {
  late _FakeSensorSource source;

  setUp(() {
    source = _FakeSensorSource();
  });

  tearDown(() {
    source.dispose();
  });

  Widget buildView({ArLocationErrorBuilder? locationErrorBuilder}) =>
      MaterialApp(
        home: Scaffold(
          body: ArView(
            annotations: const [],
            annotationViewBuilder: (context, annotation) => const SizedBox(),
            frame: const Size(100, 75),
            onLocationChange: (_) {},
            minDistanceReload: 50,
            showRadar: false,
            showDebugInfoSensor: false,
            sensorSource: source,
            locationErrorBuilder: locationErrorBuilder,
          ),
        ),
      );

  testWidgets('shows error instead of loading when permission is disallowed',
      (tester) async {
    await tester.pumpWidget(buildView());
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    source.emit(_sensor(locationError: ArLocationError.permissionDisallowed));
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text('Location permission is disallowed'), findsOneWidget);
  });

  testWidgets('shows error instead of loading when services are disabled',
      (tester) async {
    await tester.pumpWidget(buildView());
    source.emit(_sensor(locationError: ArLocationError.serviceDisabled));
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text('Location services are disabled'), findsOneWidget);
  });

  testWidgets('prefers a custom locationErrorBuilder', (tester) async {
    await tester.pumpWidget(buildView(
      locationErrorBuilder: (context, error) => const Text('custom error'),
    ));
    source.emit(_sensor(locationError: ArLocationError.permissionDisallowed));
    await tester.pump();

    expect(find.text('custom error'), findsOneWidget);
    expect(find.text('Location permission is disallowed'), findsNothing);
  });

  testWidgets('keeps loading while location is pending without an error',
      (tester) async {
    await tester.pumpWidget(buildView());
    source.emit(_sensor());
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('renders normally once a location is available', (tester) async {
    await tester.pumpWidget(buildView());
    source.emit(_sensor(location: _position()));
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text('Location permission is disallowed'), findsNothing);
    expect(find.text('Location services are disabled'), findsNothing);
  });
}