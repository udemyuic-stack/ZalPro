import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../l10n/tr.dart';
import '../models/photo.dart';
import '../services/api/api_error.dart';
import '../services/db.dart';
import '../theme.dart';
import 'ui.dart';

/// "Oldin / keyin" rasmlari — shogird qo'shadi, trener va bosh admin faqat ko'radi
/// ([readOnly]). Birinchi va oxirgi rasm yonma-yon, pastida hamma rasmlar.
class ProgressPhotos extends StatelessWidget {
  final String uid;

  /// Hozirgi vazn — rasm bilan birga yoziladi
  final double weight;
  final bool readOnly;
  const ProgressPhotos({super.key, required this.uid, this.weight = 0, this.readOnly = false});

  Future<void> _add(BuildContext context) async {
    var source = ImageSource.gallery;
    // brauzerda faqat fayl tanlash; telefonda kamera yoki galereya
    if (!kIsWeb) {
      final picked = await showModalBottomSheet<ImageSource>(
        context: context,
        builder: (ctx) => SafeArea(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: Text(tr('Kamera')),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: Text(tr('Galereya')),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
          ]),
        ),
      );
      if (picked == null) return;
      source = picked;
    }
    try {
      // Rasm hujjat ichida saqlanadi — shuning uchun kichraytirib, siqib olinadi
      final file = await ImagePicker().pickImage(source: source, maxWidth: 720, imageQuality: 60);
      if (file == null) return;
      final bytes = await file.readAsBytes();
      if (bytes.length > ProgressPhoto.maxBytes) {
        if (context.mounted) {
          showSnack(context,
              trf('Rasm juda katta ({0} KB). Boshqasini tanlang.', [bytes.length ~/ 1024]));
        }
        return;
      }
      await Db.addPhoto(uid, bytes, weight);
      if (context.mounted) showSnack(context, tr("Rasm qo'shildi"));
    } catch (e) {
      if (context.mounted) showSnack(context, trf("Bo'lmadi: {0}", [apiErrorText(e)]));
    }
  }

  void _open(BuildContext context, ProgressPhoto p) {
    showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        clipBehavior: Clip.antiAlias,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Flexible(child: InteractiveViewer(child: _PhotoImage(p, fit: BoxFit.contain))),
          Padding(
            padding: const EdgeInsets.all(AppSpace.sm),
            child: Row(children: [
              const SizedBox(width: AppSpace.sm),
              Expanded(child: Text(_caption(p))),
              if (!readOnly)
                TextButton.icon(
                  onPressed: () async {
                    final ok = await confirm(
                      ctx,
                      title: tr("Rasmni o'chirish"),
                      message: tr("Bu rasm o'chirilsinmi?"),
                      ok: tr("O'chirish"),
                      destructive: true,
                    );
                    if (!ok) return;
                    try {
                      await Db.deletePhoto(uid, p.id);
                      if (ctx.mounted) Navigator.pop(ctx);
                    } catch (e) {
                      if (ctx.mounted) {
                        showSnack(ctx, trf("Bo'lmadi: {0}", [apiErrorText(e)]));
                      }
                    }
                  },
                  icon: const Icon(Icons.delete_outline),
                  label: Text(tr("O'chirish")),
                ),
              TextButton(onPressed: () => Navigator.pop(ctx), child: Text(tr('Yopish'))),
            ]),
          ),
        ]),
      ),
    );
  }

  static String _caption(ProgressPhoto p) => [
        p.dateLabel,
        if (p.weight > 0) trf('{0} kg', [fmtNum(p.weight)])
      ].where((e) => e.isNotEmpty).join(' · ');

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return StreamBuilder<List<ProgressPhoto>>(
      stream: Db.photos(uid),
      builder: (context, snap) {
        if (snap.hasError) return ErrorState(error: snap.error, compact: true);
        final photos = snap.data ?? const <ProgressPhoto>[];
        // trener ko'rinishida rasm bo'lmasa bo'lim umuman chiqmaydi
        if (readOnly && photos.isEmpty) return const SizedBox.shrink();
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SectionHeader(
            tr('Rasmlar'),
            eyebrow: tr('Oldin / keyin'),
            trailing: readOnly
                ? null
                : TextButton.icon(
                    onPressed: () => _add(context),
                    icon: const Icon(Icons.add_a_photo_outlined),
                    label: Text(tr('Rasm')),
                  ),
          ),
          if (photos.isEmpty)
            Text(
              tr("Oyiga bir marta bir xil joyda, bir xil yorug'likda rasm oling — "
                  "o'zgarish tarozidan ko'ra rasmda yaxshiroq ko'rinadi. Rasmni faqat siz va "
                  'treneringiz ko\'radi.'),
              style: t.bodySmall?.copyWith(color: AppColors.textMuted),
            )
          else ...[
            if (photos.length >= 2)
              Row(children: [
                Expanded(
                    child: _Shot(photos.first, tr('Oldin'),
                        onTap: () => _open(context, photos.first))),
                const SizedBox(width: AppSpace.sm),
                Expanded(
                    child:
                        _Shot(photos.last, tr('Keyin'), onTap: () => _open(context, photos.last))),
              ]),
            if (photos.length != 2) ...[
              if (photos.length > 2) const SizedBox(height: AppSpace.sm),
              SizedBox(
                height: 132,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: photos.length,
                  separatorBuilder: (_, __) => const SizedBox(width: AppSpace.sm),
                  itemBuilder: (_, i) => SizedBox(
                    width: 96,
                    child: _Shot(photos[i], null, onTap: () => _open(context, photos[i])),
                  ),
                ),
              ),
            ],
          ],
          const SizedBox(height: AppSpace.lg),
        ]);
      },
    );
  }
}

class _Shot extends StatelessWidget {
  final ProgressPhoto photo;
  final String? label;
  final VoidCallback onTap;
  const _Shot(this.photo, this.label, {required this.onTap});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      GestureDetector(
        onTap: onTap,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          child: AspectRatio(
            aspectRatio: 3 / 4,
            // to'liq o'lchamda emas - katakcha eniga mos dekodlanadi (xotira va tezlik)
            child: _PhotoImage(photo, fit: BoxFit.cover, cacheWidth: 360),
          ),
        ),
      ),
      const SizedBox(height: 4),
      Text(
        [if (label != null) label!, ProgressPhotos._caption(photo)].join(' · '),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: t.bodySmall?.copyWith(color: AppColors.textMuted),
      ),
    ]);
  }
}

class _PhotoImage extends StatelessWidget {
  final ProgressPhoto photo;
  final BoxFit fit;
  final int? cacheWidth;
  const _PhotoImage(this.photo, {required this.fit, this.cacheWidth});

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
