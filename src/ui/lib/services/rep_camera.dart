import 'dart:async';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import '../models/rep_counter.dart';

class RepCameraDenied implements Exception {
  const RepCameraDenied();
}

class RepCameraUnavailable implements Exception {
  const RepCameraUnavailable();
}

abstract class RepCameraSource {
  Future<void> start(void Function(double? kneeAngle) onAngle);
  Widget preview();
  Future<void> stop();
}

class MlKitRepCamera implements RepCameraSource {
  static const _minFrameGap = Duration(milliseconds: 80);

  CameraController? _controller;
  PoseDetector? _detector;
  bool _busy = false;
  bool _stopped = false;
  DateTime _last = DateTime.fromMillisecondsSinceEpoch(0);

  @override
  Future<void> start(void Function(double? kneeAngle) onAngle) async {
    final cameras = await availableCameras();
    if (cameras.isEmpty) throw const RepCameraUnavailable();
    final camera = cameras.firstWhere(
      (c) => c.lensDirection == CameraLensDirection.front,
      orElse: () => cameras.first,
    );
    final controller = CameraController(
      camera,
      ResolutionPreset.medium,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.nv21,
    );
    try {
      await controller.initialize();
    } on CameraException catch (e) {
      await controller.dispose();
      if (e.code.contains('Denied') || e.code.contains('Restricted')) {
        throw const RepCameraDenied();
      }
      throw const RepCameraUnavailable();
    }
    if (_stopped) {
      await controller.dispose();
      return;
    }
    _controller = controller;
    _detector = PoseDetector(
      options: PoseDetectorOptions(mode: PoseDetectionMode.stream, model: PoseDetectionModel.base),
    );
    await controller.startImageStream((image) => _onImage(image, camera, onAngle));
  }

  Future<void> _onImage(
    CameraImage image,
    CameraDescription camera,
    void Function(double? kneeAngle) onAngle,
  ) async {
    final now = DateTime.now();
    if (_busy || _stopped || now.difference(_last) < _minFrameGap) return;
    _busy = true;
    _last = now;
    try {
      final input = _input(image, camera);
      final detector = _detector;
      if (input == null || detector == null) return;
      final poses = await detector.processImage(input);
      if (_stopped) return;
      onAngle(poses.isEmpty ? null : _angle(poses.first));
    } catch (_) {
      if (!_stopped) onAngle(null);
    } finally {
      _busy = false;
    }
  }

  InputImage? _input(CameraImage image, CameraDescription camera) {
    final rotation = InputImageRotationValue.fromRawValue(camera.sensorOrientation);
    final format = InputImageFormatValue.fromRawValue(image.format.raw as int);
    if (rotation == null || format != InputImageFormat.nv21 || image.planes.length != 1) {
      return null;
    }
    final plane = image.planes.first;
    return InputImage.fromBytes(
      bytes: plane.bytes,
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation,
        format: format!,
        bytesPerRow: plane.bytesPerRow,
      ),
    );
  }

  double? _angle(Pose pose) {
    Joint joint(PoseLandmarkType t) {
      final l = pose.landmarks[t];
      return l == null ? const Joint(0, 0, 0) : Joint(l.x, l.y, l.likelihood);
    }

    Leg leg(PoseLandmarkType h, PoseLandmarkType k, PoseLandmarkType a) =>
        (joint(h), joint(k), joint(a));

    return bestKneeAngle(
      leg(PoseLandmarkType.leftHip, PoseLandmarkType.leftKnee, PoseLandmarkType.leftAnkle),
      leg(PoseLandmarkType.rightHip, PoseLandmarkType.rightKnee, PoseLandmarkType.rightAnkle),
    );
  }

  @override
  Widget preview() {
    final c = _controller;
    if (c == null || !c.value.isInitialized) return const SizedBox.shrink();
    return CameraPreview(c);
  }

  @override
  Future<void> stop() async {
    _stopped = true;
    final c = _controller;
    _controller = null;
    try {
      if (c != null && c.value.isStreamingImages) await c.stopImageStream();
    } catch (_) {}
    await c?.dispose();
    await _detector?.close();
    _detector = null;
  }
}
