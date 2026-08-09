import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

/// Possible camera failures surfaced by [ArCamera].
enum ArCameraError {
  /// Camera permission has not been granted yet.
  authorizationRequired,

  /// The user denied camera permission.
  authorizationDenied,

  /// The camera could not be initialized.
  initializationFailed,
}

/// Builds a widget that renders a camera error message. If not provided,
/// [ArCamera] falls back to an English [Text].
typedef ArCameraErrorBuilder =
    Widget Function(BuildContext context, ArCameraError error);

class ArCamera extends StatefulWidget {
  const ArCamera({
    super.key,
    required this.onCameraError,
    required this.onCameraSuccess,
    this.errorBuilder,
  });

  final Function(String error) onCameraError;
  final Function() onCameraSuccess;

  /// Renders a localized message for [ArCameraError].
  final ArCameraErrorBuilder? errorBuilder;

  @override
  State<ArCamera> createState() => _ArCameraViewState();
}

class _ArCameraViewState extends State<ArCamera> {
  CameraController? controller;

  bool isCameraAuthorize = false;
  bool isCameraInitialize = false;
  ArCameraError? _error;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  @override
  void dispose() {
    super.dispose();
    controller?.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Widget child;
    final error = _error;
    if (error != null) {
      child = _buildError(error);
    } else if (!isCameraAuthorize) {
      child = _buildError(ArCameraError.authorizationRequired);
    } else if (!isCameraInitialize || controller == null) {
      child = const Center(
        child: CircularProgressIndicator(),
      );
    } else {
      child = _buildPreview();
    }
    return SizedBox(
      width: double.infinity,
      height: double.infinity,
      child: child,
    );
  }

  Widget _buildError(ArCameraError error) {
    final builder = widget.errorBuilder;
    if (builder != null) {
      return builder(context, error);
    }
    return Center(child: Text(_defaultMessage(error)));
  }

  String _defaultMessage(ArCameraError error) {
    switch (error) {
      case ArCameraError.authorizationRequired:
        return 'Need camera authorization';
      case ArCameraError.authorizationDenied:
        return 'Camera need authorization permission';
      case ArCameraError.initializationFailed:
        return 'On error when camera initialize';
    }
  }

  Widget _buildPreview() {
    // CameraPreview (camera >= 0.12) already computes the correct
    // aspect/rotation for any device orientation, so let it handle the
    // preview instead of applying our own transform.
    return Center(child: CameraPreview(controller!));
  }

  Future<void> _initializeCamera() async {
    try {
      await _requestCameraAuthorization();
      if (isCameraAuthorize) {
        final cameras = await availableCameras();
        final cameraDescription = cameras.firstWhere(
          (c) => c.lensDirection == CameraLensDirection.back,
          orElse: () => cameras.first,
        );
        controller = CameraController(
          cameraDescription,
          ResolutionPreset.high,
          enableAudio: false,
        );
        await controller?.initialize();
        isCameraInitialize = true;
        _error = null;
        widget.onCameraSuccess();
      }
    } catch (ex) {
      _error = ArCameraError.initializationFailed;
      widget.onCameraError(_defaultMessage(_error!));
      isCameraInitialize = false;
    } finally {
      setState(() {});
    }
  }

  Future<void> _requestCameraAuthorization() async {
    var isGranted = await Permission.camera.isGranted;
    if (!isGranted) {
      await Permission.camera.request();
      isGranted = await Permission.camera.isGranted;
      if (!isGranted) {
        _error = ArCameraError.authorizationDenied;
        widget.onCameraError(_defaultMessage(_error!));
      } else {
        isCameraAuthorize = true;
        setState(() {});
      }
    } else {
      isCameraAuthorize = true;
      setState(() {});
    }
  }
}
