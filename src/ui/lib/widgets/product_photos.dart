import 'package:flutter/material.dart';
import '../l10n/tr.dart';
import '../models/shop.dart';
import '../services/api/api_error.dart';
import '../services/db.dart';
import '../theme.dart';
import 'food_image.dart';
import 'image_pick.dart';

const maxProductPhotos = 5;

class ProductPhotos extends StatefulWidget {
  final Product? product;
  final ValueChanged<String> onCover;
  const ProductPhotos({super.key, required this.product, required this.onCover});

  @override
  State<ProductPhotos> createState() => _ProductPhotosState();
}

class _ProductPhotosState extends State<ProductPhotos> {
  late List<String> _urls = [...?widget.product?.imageUrls];
  late List<String> _keys = [...?widget.product?.imageKeys];
  double? _progress;
  String? _error;

  bool get _busy => _progress != null;
  String? get _id => widget.product?.id.isEmpty ?? true ? null : widget.product!.id;

  void _apply(Product saved) {
    setState(() {
      _urls = saved.imageUrls;
      _keys = saved.imageKeys;
    });
    widget.onCover(saved.image);
  }

  Future<void> _add(String id) async {
    final room = maxProductPhotos - _keys.length;
    if (room <= 0) return;
    final picked = (await pickGalleryImages()).take(room).toList();
    if (picked.isEmpty) return;
    setState(() {
      _progress = 0;
      _error = null;
    });
    final added = <String>[];
    try {
      for (var i = 0; i < picked.length; i++) {
        final key = await Db.uploadProductImage(
          id,
          picked[i].bytes,
          contentType: picked[i].contentType,
          onProgress: (sent, total) {
            if (mounted && total > 0) {
              setState(() => _progress = (i + sent / total) / picked.length);
            }
          },
        );
        added.add(key);
      }
    } catch (e) {
      if (mounted) setState(() => _error = trf('Rasm yuklanmadi: {0}', [apiErrorText(e)]));
    }
    try {
      if (added.isNotEmpty) _apply(await Db.setProductImages(id, [..._keys, ...added]));
    } catch (e) {
      if (mounted) setState(() => _error = trf('Rasm yuklanmadi: {0}', [apiErrorText(e)]));
    }
    if (mounted) setState(() => _progress = null);
  }

  Future<void> _remove(String id, int index) async {
    setState(() {
      _progress = 0;
      _error = null;
    });
    try {
      final keys = [..._keys]..removeAt(index);
      final saved = await Db.setProductImages(id, keys);
      if (mounted) _apply(saved);
    } catch (e) {
      if (mounted) setState(() => _error = trf("Rasm o'chmadi: {0}", [apiErrorText(e)]));
    }
    if (mounted) setState(() => _progress = null);
  }

  @override
  Widget build(BuildContext context) {
    final id = _id;
    if (id == null) {
      return Align(
        alignment: Alignment.centerLeft,
        child: Text(
          tr("Rasm qo'shish uchun avval tovarni saqlang"),
          style: TextStyle(color: AppColors.textMuted),
        ),
      );
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(tr('Rasmlar'), style: Theme.of(context).textTheme.titleSmall),
      const SizedBox(height: AppSpace.sm),
      Wrap(spacing: AppSpace.sm, runSpacing: AppSpace.sm, children: [
        for (var i = 0; i < _urls.length; i++) _thumb(id, i),
        if (_keys.length < maxProductPhotos)
          InkWell(
            onTap: _busy ? null : () => _add(id),
            borderRadius: BorderRadius.circular(AppRadius.md),
            child: Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.textMuted.withValues(alpha: 0.5)),
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Icon(Icons.add_photo_alternate_outlined, color: AppColors.textMuted),
            ),
          ),
      ]),
      if (_busy) ...[
        const SizedBox(height: AppSpace.sm),
        LinearProgressIndicator(value: _progress == 0 ? null : _progress),
      ],
      if (_error != null) ...[
        const SizedBox(height: AppSpace.sm),
        Text(_error!, style: TextStyle(color: AppColors.danger)),
      ],
    ]);
  }

  Widget _thumb(String id, int i) {
    return SizedBox.square(
      dimension: 72,
      child: Stack(fit: StackFit.expand, children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.md),
          child: netImage(
            _urls[i],
            cacheWidth: 216,
            errorBuilder: (c, e, s) => Container(
              color: AppColors.textMuted.withValues(alpha: 0.15),
              child: Icon(Icons.broken_image_outlined, color: AppColors.textMuted),
            ),
          ),
        ),
        Positioned(
          top: 0,
          right: 0,
          child: InkWell(
            onTap: _busy ? null : () => _remove(id, i),
            child: Container(
              decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
              padding: const EdgeInsets.all(3),
              child: const Icon(Icons.close, size: 16, color: Colors.white),
            ),
          ),
        ),
        if (i == 0)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              color: Colors.black54,
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Text(
                tr('Muqova'),
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontSize: 12),
              ),
            ),
          ),
      ]),
    );
  }
}
