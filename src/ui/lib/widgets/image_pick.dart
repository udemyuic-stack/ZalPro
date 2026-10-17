import 'dart:typed_data';
import 'package:image_picker/image_picker.dart';

class PickedImage {
  final Uint8List bytes;
  final String contentType;
  const PickedImage(this.bytes, this.contentType);
}

String imageContentType(XFile file) {
  final mime = file.mimeType?.toLowerCase() ?? '';
  if (const {'image/jpeg', 'image/png', 'image/webp'}.contains(mime)) return mime;
  final name = (file.name.isNotEmpty ? file.name : file.path).toLowerCase();
  if (name.endsWith('.png')) return 'image/png';
  if (name.endsWith('.webp')) return 'image/webp';
  return 'image/jpeg';
}

Future<PickedImage> _read(XFile file) async =>
    PickedImage(await file.readAsBytes(), imageContentType(file));

Future<PickedImage?> pickGalleryImage() async {
  final file = await ImagePicker().pickImage(
    source: ImageSource.gallery,
    maxWidth: 1600,
    maxHeight: 1600,
    imageQuality: 80,
  );
  return file == null ? null : _read(file);
}

Future<PickedImage?> pickCameraImage() async {
  final file = await ImagePicker().pickImage(
    source: ImageSource.camera,
    maxWidth: 1600,
    maxHeight: 1600,
    imageQuality: 80,
  );
  return file == null ? null : _read(file);
}

Future<List<PickedImage>> pickGalleryImages() async {
  final files = await ImagePicker().pickMultiImage(
    maxWidth: 1600,
    maxHeight: 1600,
    imageQuality: 80,
  );
  return [for (final file in files) await _read(file)];
}
