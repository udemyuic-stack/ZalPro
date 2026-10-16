import 'package:flutter/material.dart';
import '../l10n/tr.dart';
import 'food_image.dart';

/// Rasmlarni to'liq ekranda ko'rsatadi: barmoq bilan kattalashtirish, bir nechta bo'lsa
/// yonga surib varaqlash. Bosilsa yoki "X" bilan yopiladi.
Future<void> showImageViewer(BuildContext context, List<String> urls, {int initial = 0}) {
  if (urls.isEmpty) return Future.value();
  return showDialog<void>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.92),
    builder: (_) => _ImageViewer(urls: urls, initial: initial.clamp(0, urls.length - 1)),
  );
}

class _ImageViewer extends StatefulWidget {
  final List<String> urls;
  final int initial;
  const _ImageViewer({required this.urls, required this.initial});

  @override
  State<_ImageViewer> createState() => _ImageViewerState();
}

class _ImageViewerState extends State<_ImageViewer> {
  late final _pages = PageController(initialPage: widget.initial);
  late var _page = widget.initial;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final n = widget.urls.length;
    return Dialog.fullscreen(
      backgroundColor: Colors.transparent,
      child: SafeArea(
        child: Stack(children: [
          PageView.builder(
            controller: _pages,
            itemCount: n,
            onPageChanged: (i) => setState(() => _page = i),
            itemBuilder: (_, i) => InteractiveViewer(
              maxScale: 4,
              child: Center(
                child: netImage(
                  widget.urls[i],
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => const Icon(
                    Icons.broken_image_outlined,
                    color: Colors.white54,
                    size: 48,
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            top: 4,
            right: 4,
            child: IconButton(
              tooltip: tr('Yopish'),
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.close, color: Colors.white),
            ),
          ),
          if (n > 1)
            Positioned(
              left: 0,
              right: 0,
              bottom: 12,
              child: Text(
                '${_page + 1} / $n',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70),
              ),
            ),
        ]),
      ),
    );
  }
}
