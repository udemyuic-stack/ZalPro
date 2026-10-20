import 'dart:async';
import 'package:camera/camera.dart';

class HrCameraDenied implements Exception {
  const HrCameraDenied();
}

class HrCameraUnavailable implements Exception {
  const HrCameraUnavailable();
}

abstract class HrCameraSource {
  Future<void> start(void Function(int timeMs, double red) onSample);
  Future<void> stop();
}

double redOf(CameraImage image) {
  if (image.planes.length < 3) return 0;
  final y = image.planes[0];
  final u = image.planes[1];
  final v = image.planes[2];
  final w = image.width;
  final h = image.height;
  final uvStep = u.bytesPerPixel ?? 1;
  var sum = 0.0;
  var n = 0;
  for (var row = h ~/ 3; row < h * 2 ~/ 3; row += 4) {
    for (var col = w ~/ 3; col < w * 2 ~/ 3; col += 4) {
      final yi = row * y.bytesPerRow + col;
      final ci = (row ~/ 2) * u.bytesPerRow + (col ~/ 2) * uvStep;
      if (yi >= y.bytes.length || ci >= v.bytes.length) continue;
      final r = y.bytes[yi] + 1.402 * (v.bytes[ci] - 128);
      sum += r.clamp(0, 255);
      n++;
    }
  }
  return n == 0 ? 0 : sum / n;
}

class TorchHrCamera implements HrCameraSource {
  CameraController? _controller;
  bool _stopped = false;
  final Stopwatch _clock = Stopwatch();

  @override
  Future<void> start(void Function(int timeMs, double red) onSample) async {
    _stopped = false;
    final cameras = await availableCameras();
    if (cameras.isEmpty) throw const HrCameraUnavailable();
    final camera = cameras.firstWhere(
      (c) => c.lensDirection == CameraLensDirection.back,
      orElse: () => cameras.first,
    );
    final controller = CameraController(
      camera,
      ResolutionPreset.low,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.yuv420,
    );
    _controller = controller;
    try {
      await controller.initialize();
      if (_stopped) {
        await _release(controller);
        return;
      }
      await controller.setFlashMode(FlashMode.torch);
      _clock
        ..reset()
        ..start();
      await controller.startImageStream((image) {
        if (_stopped) return;
        onSample(_clock.elapsedMilliseconds, redOf(image));
      });
    } on CameraException catch (e) {
      await _release(controller);
      if (e.code.contains('Denied') || e.code.contains('Restricted')) {
        throw const HrCameraDenied();
      }
      throw const HrCameraUnavailable();
    } catch (_) {
      await _release(controller);
      throw const HrCameraUnavailable();
    }
  }

  Future<void> _release(CameraController controller) async {
    if (identical(_controller, controller)) _controller = null;
    try {
      if (controller.value.isStreamingImages) await controller.stopImageStream();
    } catch (_) {}
    try {
      if (controller.value.isInitialized) await controller.setFlashMode(FlashMode.off);
    } catch (_) {}
    try {
      await controller.dispose();
    } catch (_) {}
  }

  @override
  Future<void> stop() async {
    _stopped = true;
    _clock.stop();
    final c = _controller;
    if (c != null) await _release(c);
  }
}
