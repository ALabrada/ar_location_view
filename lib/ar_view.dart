import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import 'ar_location_view.dart';

/// Signature for a function that creates a widget for a given annotation.
///
/// [ArView] re-sorts and re-filters annotations on every sensor update, so
/// their position in the rendered list is not stable across frames. To keep
/// Flutter's element reconciliation correct despite that reordering, [ArView]
/// already wraps the returned widget in a [Positioned] keyed with
/// `ValueKey(annotation.uid)` — you do not need to (but may) key the widget
/// you return here yourself.
typedef AnnotationViewBuilder = Widget Function(
    BuildContext context, ArAnnotation annotation);

typedef ChangeLocationCallback = void Function(Position position);

class ArView extends StatefulWidget {
  const ArView({
    super.key,
    required this.annotations,
    required this.annotationViewBuilder,
    required this.frame,
    required this.onLocationChange,
    this.annotationWidth = 200,
    this.annotationHeight = 75,
    this.maxVisibleDistance = 1500,
    this.showDebugInfoSensor = true,
    this.paddingOverlap = 5,
    this.yOffsetOverlap,
    required this.minDistanceReload,
    this.scaleWithDistance = true,
    this.markerColor,
    this.backgroundRadar,
    this.radarPosition,
    this.showRadar = true,
    this.radarWidth,
    this.sensorSource,
  });

  final List<ArAnnotation> annotations;
  final AnnotationViewBuilder annotationViewBuilder;
  final double annotationWidth;
  final double annotationHeight;

  final double maxVisibleDistance;

  final Size frame;

  final ChangeLocationCallback onLocationChange;

  final bool showDebugInfoSensor;

  final double paddingOverlap;
  final double? yOffsetOverlap;
  final double minDistanceReload;

  ///Scale annotation view with distance from user
  final bool scaleWithDistance;

  ///Radar

  /// marker color in radar
  final Color? markerColor;

  ///background radar color
  final Color? backgroundRadar;

  ///radar position in view
  final RadarPosition? radarPosition;

  ///Show radar in view
  final bool showRadar;

  ///Radar width
  final double? radarWidth;

  ///Source of fused sensor/location samples. Defaults to a device-backed
  ///[ArSensorManager] instantiated per [ArView]. Provide your own
  ///implementation (e.g. a fake source) to test without real hardware or
  ///to share a single sensor pipeline across multiple views.
  final ArSensorSource? sensorSource;

  @override
  State<ArView> createState() => _ArViewState();
}

class _ArViewState extends State<ArView> {
  late final ArSensorSource _sensorSource =
      widget.sensorSource ?? ArSensorManager();

  final AnnotationLayoutEngine _layoutEngine = const AnnotationLayoutEngine();

  StreamSubscription<ArSensor>? _sensorSubscription;

  /// Latest sensor sample received. Updated only from [_onArSensor], never
  /// from [build], so effects (updating [position], notifying
  /// [ArView.onLocationChange]) never run as a side effect of building.
  ArSensor? _latestSensor;

  Position? position;

  @override
  void initState() {
    super.initState();
    _sensorSource.init();
    _sensorSubscription = _sensorSource.arSensor.listen(_onArSensor);
  }

  @override
  void dispose() {
    _sensorSubscription?.cancel();
    _sensorSource.dispose();
    super.dispose();
  }

  void _onArSensor(ArSensor arSensor) {
    if (arSensor.location != null) {
      _updatePosition(arSensor.location!);
    }
    if (!mounted) return;
    setState(() {
      _latestSensor = arSensor;
    });
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final height = MediaQuery.of(context).size.height;

    final arSensor = _latestSensor;
    if (arSensor == null || arSensor.location == null) {
      return loading();
    }

    final deviceLocation = arSensor.location!;
    final layout = _layoutEngine.layout(
      annotations: widget.annotations,
      arSensor: arSensor,
      deviceLocation: deviceLocation,
      width: width,
      height: height,
      config: AnnotationLayoutConfig(
        annotationWidth: widget.annotationWidth,
        annotationHeight: widget.annotationHeight,
        maxVisibleDistance: widget.maxVisibleDistance,
        paddingOverlap: widget.paddingOverlap,
        yOffsetOverlap: widget.yOffsetOverlap,
      ),
    );
    final annotations = layout.annotations;
    return Stack(
      children: [
        if (kDebugMode && widget.showDebugInfoSensor)
          Positioned(
            bottom: 0,
            child: _debugInfo(context, arSensor),
          ),
        Stack(
          children: annotations
              .map(
                (e) {
                  return Positioned(
                    key: ValueKey(e.uid),
                    left: e.arPosition.dx,
                    top: e.arPosition.dy + height * 0.5,
                    child: Transform.translate(
                      offset: Offset(0, e.arPositionOffset.dy),
                      child: Transform.scale(
                        scale: widget.scaleWithDistance
                            ? 1 -
                                (e.distanceFromUser /
                                    (widget.maxVisibleDistance + 280))
                            : 1,
                        child: SizedBox(
                          width: widget.annotationWidth,
                          height: widget.annotationHeight,
                          child: widget.annotationViewBuilder(context, e),
                        ),
                      ),
                    ),
                  );
                },
              )
              .toList()
              .reversed
              .toList(),
        ),
        if (widget.showRadar)
          _radarPosition(
              context,
              widget.radarPosition ?? RadarPosition.topLeft,
              arSensor.heading,
              widget.radarWidth != null ? (widget.radarWidth! * 2) : width)
      ],
    );
  }

  Widget _radarPosition(BuildContext context, RadarPosition position,
      double heading, double width) {
    final radar = Padding(
      padding: const EdgeInsets.all(8.0),
      child: CustomPaint(
        size: Size(width / 2, width / 2),
        painter: RadarPainter(
          maxDistance: widget.maxVisibleDistance,
          arAnnotations: widget.annotations,
          heading: heading,
          background: widget.backgroundRadar ?? Colors.grey,
          markerColor: widget.markerColor ?? Colors.red,
        ),
      ),
    );
    final screenWidth = MediaQuery.of(context).size.width;
    switch (position) {
      case RadarPosition.topCenter:
        return Positioned(
          top: 0,
          left: screenWidth / 2 - width / 4,
          child: radar,
        );
      case RadarPosition.topRight:
        return Positioned(
          top: 0,
          right: 0,
          child: radar,
        );
      case RadarPosition.bottomLeft:
        return Positioned(
          bottom: 0,
          left: 0,
          child: radar,
        );
      case RadarPosition.bottomCenter:
        return Positioned(
          bottom: 0,
          left: screenWidth / 2 - width / 4,
          child: radar,
        );
      case RadarPosition.bottomRight:
        return Positioned(
          bottom: 0,
          right: 0,
          child: radar,
        );
      default:
        return radar;
    }
  }

  Widget _debugInfo(BuildContext context, ArSensor? arSensor) {
    return Container(
      color: Colors.white,
      width: MediaQuery.of(context).size.width,
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Latitude  : ${arSensor?.location?.latitude}'),
            Text('Longitude : ${arSensor?.location?.longitude}'),
            Text('Pitch     : ${arSensor?.pitch}'),
            Text('Heading   : ${arSensor?.heading}'),
          ],
        ),
      ),
    );
  }

  Widget loading() {
    return const Center(
      child: CircularProgressIndicator(),
    );
  }

  void _updatePosition(Position newPosition) {
    if (position == null) {
      widget.onLocationChange(newPosition);
      position = newPosition;
    } else {
      final distance = Geolocator.distanceBetween(
        position!.latitude,
        position!.longitude,
        newPosition.latitude,
        newPosition.longitude,
      );
      if (distance > widget.minDistanceReload) {
        widget.onLocationChange(newPosition);
        position = newPosition;
      }
    }
  }
}
