import 'package:flutter/material.dart';
import '../theme.dart';

/// Reja kunining rasmi — trener bergan ratsion surati.
/// Yo'l `assets/...` (ilova ichida) yoki `https://...` bo'lishi mumkin.
/// Bosilsa to'liq ekranda ochiladi va kattalashtirsa bo'ladi.
class PlanPhoto extends StatelessWidget {
  final String path;
  final String caption;
  final double? height;
  const PlanPhoto({super.key, required this.path, this.caption = '', this.height});

  ImageProvider get _image =>
      path.startsWith('http') ? NetworkImage(path) : AssetImage(path) as ImageProvider;

  void _openFull(BuildContext context) => showDialog<void>(
        context: context,
        barrierColor: Colors.black.withValues(alpha: 0.92),
        builder: (ctx) => Stack(children: [
          Positioned.fill(
            child: InteractiveViewer(
              maxScale: 5,
              child: Center(child: Image(image: _image, fit: BoxFit.contain)),
            ),
          ),
          Positioned(
            top: 8,
            right: 8,
            child: SafeArea(
              child: IconButton.filledTonal(
                onPressed: () => Navigator.pop(ctx),
                icon: const Icon(Icons.close),
              ),
            ),
          ),
        ]),
      );

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return GestureDetector(
      onTap: () => _openFull(context),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: Stack(children: [
          Image(
            image: _image,
            width: double.infinity,
            height: height,
            fit: height == null ? BoxFit.fitWidth : BoxFit.cover,
            alignment: Alignment.topCenter,
            errorBuilder: (_, __, ___) => const SizedBox.shrink(),
          ),
          if (caption.isNotEmpty)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                padding: const EdgeInsets.fromLTRB(AppSpace.md, AppSpace.lg, AppSpace.md, 10),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Colors.black.withValues(alpha: 0.75)],
                  ),
                ),
                child: Row(children: [
                  Expanded(
                    child: Text(
                      caption,
                      style: t.bodySmall?.copyWith(color: Colors.white),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const Icon(Icons.zoom_out_map, size: 16, color: Colors.white70),
                ]),
              ),
            ),
        ]),
      ),
    );
  }
}
