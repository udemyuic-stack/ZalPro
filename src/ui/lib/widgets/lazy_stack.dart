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

class _LazyIndexedStackState extends State<LazyIndexedStack> {
  late final _seen = <int>{widget.index};

  @override
  void didUpdateWidget(LazyIndexedStack old) {
    super.didUpdateWidget(old);
    _seen.add(widget.index);
  }

  @override
  Widget build(BuildContext context) => IndexedStack(
        index: widget.index,
        children: [
          for (var i = 0; i < widget.children.length; i++)
            _seen.contains(i) ? widget.children[i] : const SizedBox.shrink(),
        ],
      );
}
