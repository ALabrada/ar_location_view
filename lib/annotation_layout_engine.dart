import 'dart:math';
import 'dart:ui';

import 'package:geolocator/geolocator.dart';
import 'package:native_device_orientation/native_device_orientation.dart';

import 'ar_annotation.dart';
import 'ar_extension.dart';
import 'ar_math.dart';
import 'ar_sensor.dart';
import 'ar_status.dart';

/// Configuration for [AnnotationLayoutEngine.layout].
class AnnotationLayoutConfig {
  const AnnotationLayoutConfig({
    required this.annotationWidth,
    required this.annotationHeight,
    required this.maxVisibleDistance,
    required this.paddingOverlap,
    this.yOffsetOverlap,
  });

  final double annotationWidth;
  final double annotationHeight;
  final double maxVisibleDistance;
  final double paddingOverlap;
  final double? yOffsetOverlap;
}

/// Result of [AnnotationLayoutEngine.layout]: the annotations currently
/// visible, positioned on screen and de-collided, together with the
/// field-of-view status used to compute them.
class AnnotationLayoutResult {
  const AnnotationLayoutResult({
    required this.annotations,
    required this.status,
  });

  /// Visible annotations, sorted by distance, with [ArAnnotation.arPosition]
  /// and [ArAnnotation.arPositionOffset] populated.
  final List<ArAnnotation> annotations;

  final ArStatus status;
}

/// Pure Dart geometry engine: turns raw sensor data and a list of
/// [ArAnnotation] into the subset that is visible, positioned and
/// de-collided on screen.
///
/// Has no dependency on Flutter widgets/[BuildContext]/[State], so it can be
/// unit tested directly with `package:test`, without a `WidgetTester`.
class AnnotationLayoutEngine {
  const AnnotationLayoutEngine();

  AnnotationLayoutResult layout({
    required List<ArAnnotation> annotations,
    required ArSensor arSensor,
    required Position deviceLocation,
    required double width,
    required double height,
    required AnnotationLayoutConfig config,
  }) {
    final status = _calculateFOV(arSensor.orientation, width, height);

    var visible = _calculateDistanceAndBearingFromUser(
        annotations, deviceLocation, arSensor, status);
    visible = visible
        .where(
            (element) => element.distanceFromUser < config.maxVisibleDistance)
        .toList();
    visible = _visibleAnnotations(visible, arSensor.heading, status);

    _transformAnnotation(visible, config);

    return AnnotationLayoutResult(annotations: visible, status: status);
  }

  ArStatus _calculateFOV(
      NativeDeviceOrientation orientation, double width, double height) {
    double hFov = 0;
    double vFov = 0;
    const tempFOv = 58.0;

    if (orientation == NativeDeviceOrientation.landscapeLeft ||
        orientation == NativeDeviceOrientation.landscapeRight) {
      hFov = tempFOv;
      vFov = (2 * atan(tan((hFov / 2).toRadians) * (height / width))).toDegrees;
    } else {
      vFov = tempFOv;
      hFov = (2 * atan(tan((vFov / 2).toRadians) * (width / height))).toDegrees;
    }
    return ArStatus()
      ..hFov = hFov
      ..vFov = vFov
      ..hPixelPerDegree = hFov > 0 ? (width / hFov) : 0
      ..vPixelPerDegree = vFov > 0 ? (height / vFov) : 0;
  }

  List<ArAnnotation> _visibleAnnotations(
      List<ArAnnotation> annotations, double heading, ArStatus status) {
    final degreesDeltaH = status.hFov;
    return annotations.where((ArAnnotation annotation) {
      final delta = ArMath.deltaAngle(heading, annotation.azimuth);
      final isVisible = delta.abs() < degreesDeltaH;
      annotation.isVisible = isVisible;
      return annotation.isVisible;
    }).toList();
  }

  List<ArAnnotation> _calculateDistanceAndBearingFromUser(
      List<ArAnnotation> annotations,
      Position deviceLocation,
      ArSensor arSensor,
      ArStatus status) {
    return annotations.map((e) {
      final annotationLocation = e.position;
      e.azimuth = Geolocator.bearingBetween(
        deviceLocation.latitude,
        deviceLocation.longitude,
        annotationLocation.latitude,
        annotationLocation.longitude,
      );
      e.distanceFromUser = Geolocator.distanceBetween(
          deviceLocation.latitude,
          deviceLocation.longitude,
          annotationLocation.latitude,
          annotationLocation.longitude);
      final dy = arSensor.pitch * status.vPixelPerDegree;
      final dx = ArMath.deltaAngle(e.azimuth, arSensor.heading) *
          status.hPixelPerDegree;
      e.arPosition = Offset(dx, dy);
      return e;
    }).toList();
  }

  /// Resolves horizontal overlaps between annotation labels by stacking
  /// colliding ones onto extra vertical "rows".
  ///
  /// Annotations are processed in distance order (closest first, so closer
  /// POIs keep their natural, unshifted position); each one is placed on the
  /// first row whose already-placed intervals it doesn't overlap, found via
  /// binary search against that row's sorted, non-overlapping intervals
  /// ([_Row.overlaps]) instead of comparing against every previously placed
  /// annotation. That keeps the common case close to O(n log n) instead of
  /// the O(n^2) full pairwise comparison a naive implementation requires.
  /// The only remaining worst case is every annotation sharing the exact
  /// same horizontal position, which inherently needs one row per
  /// annotation no matter the algorithm.
  void _transformAnnotation(
      List<ArAnnotation> annotations, AnnotationLayoutConfig config) {
    annotations
        .sort((a, b) => a.distanceFromUser.compareTo(b.distanceFromUser));

    final step = (config.yOffsetOverlap ?? config.annotationHeight) +
        config.paddingOverlap;
    final rows = <_Row>[];

    for (final annotation in annotations) {
      final start = annotation.arPosition.dx;
      final end = start + config.annotationWidth;

      var rowIndex = rows.indexWhere((row) => !row.overlaps(start, end));
      if (rowIndex == -1) {
        rowIndex = rows.length;
        rows.add(_Row());
      }

      annotation.arPositionOffset = Offset(0, -rowIndex * step);
      rows[rowIndex].insert(start, end);
    }
  }
}

/// A row of horizontally non-overlapping `[start, end]` intervals, kept
/// sorted by `start`. Because the intervals in a row never overlap each
/// other, only the immediate neighbours of the insertion point can possibly
/// overlap a new interval, so [overlaps] only needs a binary search plus two
/// comparisons rather than scanning every interval already in the row.
class _Row {
  final List<double> _starts = [];
  final List<double> _ends = [];

  bool overlaps(double start, double end) {
    final index = _lowerBound(start);
    if (index > 0 && _ends[index - 1] >= start) return true;
    if (index < _starts.length && _starts[index] <= end) return true;
    return false;
  }

  void insert(double start, double end) {
    final index = _lowerBound(start);
    _starts.insert(index, start);
    _ends.insert(index, end);
  }

  int _lowerBound(double start) {
    var lo = 0;
    var hi = _starts.length;
    while (lo < hi) {
      final mid = (lo + hi) >> 1;
      if (_starts[mid] < start) {
        lo = mid + 1;
      } else {
        hi = mid;
      }
    }
    return lo;
  }
}
