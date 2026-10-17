import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../l10n/tr.dart';
import '../models/photo.dart';
import '../theme.dart';
import 'progress_photo_image.dart';
import 'ui.dart';

Future<void> showPhotoCompare(BuildContext context, List<ProgressPhoto> photos) =>
    showSheet<void>(context, PhotoCompareBody(photos: photos));

String photoCaption(ProgressPhoto p) => [
      p.dateLabel,
      if (p.weight > 0) trf('{0} kg', [fmtNum(p.weight)])
    ].where((e) => e.isNotEmpty).join(' · ');

String? weightDelta(ProgressPhoto before, ProgressPhoto after) {
  if (before.weight <= 0 || after.weight <= 0) return null;
  final d = after.weight - before.weight;
  final rounded = double.parse(d.abs().toStringAsFixed(1));
  if (rounded == 0) return trf('{0} kg', ['0']);
  return trf('{0} kg', ['${d > 0 ? '+' : '−'}${fmtNum(rounded)}']);
}

class PhotoCompareBody extends StatefulWidget {
  final List<ProgressPhoto> photos;
  const PhotoCompareBody({super.key, required this.photos});

  @override
  State<PhotoCompareBody> createState() => _PhotoCompareBodyState();
}

class _PhotoCompareBodyState extends State<PhotoCompareBody> {
  late int _before = 0;
  late int _after = widget.photos.length - 1;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final photos = widget.photos;
    final before = photos[_before];
    final after = photos[_after];
    final delta = weightDelta(before, after);
    final maxHeight = MediaQuery.of(context).size.height * 0.42;
    return SingleChildScrollView(
      child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(tr('Solishtirish'), style: t.titleLarge),
            const SizedBox(height: AppSpace.md),
            Center(
              child: SizedBox(
                height: maxHeight,
                child: AspectRatio(
                  aspectRatio: 3 / 4,
                  child: PhotoCompareSlider(before: before, after: after),
                ),
              ),
            ),
            const SizedBox(height: AppSpace.sm),
            Row(children: [
              Expanded(
                child: Text(
                  '${tr('Oldin')} · ${photoCaption(before)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: t.bodySmall?.copyWith(color: AppColors.textMuted),
                ),
              ),
              if (delta != null)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpace.sm),
                  child: Text(delta, key: const Key('compare-delta'), style: t.labelLarge),
                ),
              Expanded(
                child: Text(
                  '${tr('Keyin')} · ${photoCaption(after)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.end,
                  style: t.bodySmall?.copyWith(color: AppColors.textMuted),
                ),
              ),
            ]),
            const SizedBox(height: AppSpace.md),
            _Picker(
              label: tr('Oldin'),
              prefix: 'before',
              photos: photos,
              selected: _before,
              onSelect: (i) => setState(() => _before = i),
            ),
            const SizedBox(height: AppSpace.sm),
            _Picker(
              label: tr('Keyin'),
              prefix: 'after',
              photos: photos,
              selected: _after,
              onSelect: (i) => setState(() => _after = i),
            ),
            const SizedBox(height: AppSpace.md),
            OutlinedButton(onPressed: () => Navigator.pop(context), child: Text(tr('Yopish'))),
          ]),
    );
  }
}

class _Picker extends StatelessWidget {
  final String label;
  final String prefix;
  final List<ProgressPhoto> photos;
  final int selected;
  final ValueChanged<int> onSelect;
  const _Picker({
    required this.label,
    required this.prefix,
    required this.photos,
    required this.selected,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: t.labelLarge),
      const SizedBox(height: 4),
      SizedBox(
        height: 72,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: photos.length,
          separatorBuilder: (_, __) => const SizedBox(width: AppSpace.sm),
          itemBuilder: (_, i) => GestureDetector(
            key: Key('compare-$prefix-$i'),
            onTap: () => onSelect(i),
            child: Container(
              width: 54,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(
                  color: i == selected ? AppColors.accent : Colors.transparent,
                  width: 2,
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.md - 2),
                child: ProgressPhotoImage(photos[i], fit: BoxFit.cover, cacheWidth: 160),
              ),
            ),
          ),
        ),
      ),
    ]);
  }
}

class PhotoCompareSlider extends StatefulWidget {
  final ProgressPhoto before;
  final ProgressPhoto after;
  const PhotoCompareSlider({super.key, required this.before, required this.after});

  @override
  State<PhotoCompareSlider> createState() => _PhotoCompareSliderState();
}

class _PhotoCompareSliderState extends State<PhotoCompareSlider> {
  double _split = 0.5;

  void _move(double next) => setState(() => _split = math.min(1, math.max(0, next)));

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      final w = c.maxWidth;
      final h = c.maxHeight;
      return Semantics(
        slider: true,
        label: tr('Solishtirish'),
        value: '${(_split * 100).round()}%',
        increasedValue: '${(math.min(1, _split + 0.1) * 100).round()}%',
        decreasedValue: '${(math.max(0, _split - 0.1) * 100).round()}%',
        onIncrease: () => _move(_split + 0.1),
        onDecrease: () => _move(_split - 0.1),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onHorizontalDragUpdate: (d) => _move(_split + d.delta.dx / w),
          onTapDown: (d) => _move(d.localPosition.dx / w),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            child: Stack(fit: StackFit.expand, children: [
              ProgressPhotoImage(widget.after, fit: BoxFit.cover),
              ClipRect(
                child: Align(
                  key: const Key('compare-before-clip'),
                  alignment: Alignment.centerLeft,
                  widthFactor: _split,
                  child: SizedBox(
                    width: w,
                    height: h,
                    child: ProgressPhotoImage(widget.before, fit: BoxFit.cover),
                  ),
                ),
              ),
              Positioned(
                left: w * _split - 1,
                top: 0,
                bottom: 0,
                child: Container(width: 2, color: AppColors.accent),
              ),
              Positioned(
                left: w * _split - 18,
                top: h / 2 - 18,
                child: Container(
                  key: const Key('compare-handle'),
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(color: AppColors.accent, shape: BoxShape.circle),
                  child: Icon(Icons.swap_horiz, color: AppColors.onAccent),
                ),
              ),
            ]),
          ),
        ),
      );
    });
  }
}
