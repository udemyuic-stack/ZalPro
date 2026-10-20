import 'package:flutter/material.dart';

/// [IndexedStack] kabi, lekin bola faqat birinchi marta tanlanganda quriladi.
/// Oddiy `IndexedStack` hamma bo'limni birdan quradi — ilova ochilishida har biri o'z
/// so'rovini yuboradi. Bu yerda ochilmagan bo'lim o'rnida bo'sh joy turadi; bir marta
/// ochilgach holati (scroll, tanlov) saqlanadi.
class LazyIndexedStack extends StatefulWidget {
  final int index;
  final List<Widget> children;
  const LazyIndexedStack({super.key, required this.index, required this.children});

  @override
  State<LazyIndexedStack> createState() => _LazyIndexedStackState();
}

class _LazyIndexedStackState extends State<LazyIndexedStack> with SingleTickerProviderStateMixin {
  late final _seen = <int>{widget.index};
  late final _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 260), value: 1);

  @override
  void didUpdateWidget(LazyIndexedStack old) {
    super.didUpdateWidget(old);
    _seen.add(widget.index);
    if (old.index != widget.index) {
      final reduce = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
      if (!reduce) _c.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final curve = CurvedAnimation(parent: _c, curve: Curves.easeOutCubic);
    return FadeTransition(
      opacity: curve,
      child: SlideTransition(
        position: Tween(begin: const Offset(0, 0.02), end: Offset.zero).animate(curve),
        child: IndexedStack(
          index: widget.index,
          children: [
            for (var i = 0; i < widget.children.length; i++)
              _seen.contains(i) ? widget.children[i] : const SizedBox.shrink(),
          ],
        ),
      ),
    );
  }
}
