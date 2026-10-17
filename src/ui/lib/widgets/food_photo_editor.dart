import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../l10n/tr.dart';
import '../models/models.dart';
import '../services/api/api_error.dart';
import '../services/db.dart';
import '../theme.dart';
import 'food_image.dart';
import 'image_pick.dart';

class FoodPhotoEditor extends StatefulWidget {
  final Food? food;
  final TextEditingController name;
  const FoodPhotoEditor({super.key, required this.food, required this.name});

  @override
  State<FoodPhotoEditor> createState() => _FoodPhotoEditorState();
}

class _FoodPhotoEditorState extends State<FoodPhotoEditor> {
  late String _url = widget.food?.imageUrl ?? '';
  Uint8List? _pending;
  double? _progress;
  String? _error;

  bool get _busy => _progress != null;
  String? get _id => widget.food?.id.isEmpty ?? true ? null : widget.food!.id;

  Future<void> _pick(String id) async {
    final picked = await pickGalleryImage();
    if (picked == null) return;
    setState(() {
      _pending = picked.bytes;
      _progress = 0;
      _error = null;
    });
    try {
      final saved = await Db.uploadFoodImage(
        id,
        picked.bytes,
        contentType: picked.contentType,
        onProgress: (sent, total) {
          if (mounted && total > 0) setState(() => _progress = sent / total);
        },
      );
      if (mounted) {
        setState(() {
          _url = saved.imageUrl;
          _pending = null;
          _progress = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _pending = null;
          _progress = null;
          _error = trf('Rasm yuklanmadi: {0}', [apiErrorText(e)]);
        });
      }
    }
  }

  Future<void> _remove(String id) async {
    setState(() {
      _progress = 0;
      _error = null;
    });
    try {
      await Db.deleteFoodImage(id);
      if (mounted) {
        setState(() {
          _url = '';
          _progress = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _progress = null;
          _error = trf("Rasm o'chmadi: {0}", [apiErrorText(e)]);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final id = _id;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        ListenableBuilder(
          listenable: widget.name,
          builder: (context, _) {
            final pending = _pending;
            if (pending != null) {
              return ClipRRect(
                borderRadius: BorderRadius.circular(80 * 0.28),
                child: Image.memory(pending, width: 80, height: 80, fit: BoxFit.cover),
              );
            }
            return FoodImage(name: widget.name.text, url: _url, size: 80);
          },
        ),
        const SizedBox(width: AppSpace.md),
        Expanded(
          child: id == null
              ? Text(
                  tr("Rasm qo'shish uchun avval mahsulotni saqlang"),
                  style: TextStyle(color: AppColors.textMuted),
                )
              : Wrap(spacing: AppSpace.sm, runSpacing: AppSpace.sm, children: [
                  OutlinedButton.icon(
                    onPressed: _busy ? null : () => _pick(id),
                    icon: const Icon(Icons.photo_library_outlined),
                    label: Text(_url.isEmpty ? tr('Rasm tanlash') : tr('Rasmni almashtirish')),
                  ),
                  if (_url.isNotEmpty)
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(foregroundColor: AppColors.danger),
                      onPressed: _busy ? null : () => _remove(id),
                      icon: const Icon(Icons.delete_outline),
                      label: Text(tr("Rasmni o'chirish")),
                    ),
                ]),
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
}
