import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../models/photo.dart';
import '../theme.dart';

class ProgressPhotoImage extends StatelessWidget {
  final ProgressPhoto photo;
  final BoxFit fit;
  final int? cacheWidth;
  const ProgressPhotoImage(this.photo, {super.key, required this.fit, this.cacheWidth});

  @override
  Widget build(BuildContext context) {
    final url = photo.url;
    if (photo.bytes.isNotEmpty || url == null) {
      return Image.memory(photo.bytes, fit: fit, gaplessPlayback: true, cacheWidth: cacheWidth);
    }
    if (kIsWeb) {
      return Image.network(
        url,
        fit: fit,
        gaplessPlayback: true,
        cacheWidth: cacheWidth,
        errorBuilder: (_, __, ___) => Icon(Icons.broken_image_outlined, color: AppColors.textMuted),
      );
    }
    return CachedNetworkImage(
      imageUrl: url,
      cacheKey: photo.id,
      fit: fit,
      memCacheWidth: cacheWidth,
      fadeInDuration: const Duration(milliseconds: 120),
      errorWidget: (_, __, ___) => Icon(Icons.broken_image_outlined, color: AppColors.textMuted),
    );
  }
}
