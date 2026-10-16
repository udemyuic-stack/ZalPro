import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

/// YouTube pleyeri — telefonda: WebView ichida (sahifaning o'zida o'ynaydi).
Widget youtubeEmbed(String id) => _Embed(key: ValueKey(id), id: id);

class _Embed extends StatefulWidget {
  final String id;
  const _Embed({super.key, required this.id});

  @override
  State<_Embed> createState() => _EmbedState();
}

class _EmbedState extends State<_Embed> {
  late final WebViewController _web;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    // Pleyer manba manzilini (referrer) talab qiladi — sahifa shu `baseUrl` bilan yuklanadi,
    // aks holda YouTube "153" xatosini ko'rsatadi.
    const origin = 'https://www.youtube-nocookie.com';
    final src = '$origin/embed/${widget.id}?autoplay=1&playsinline=1&rel=0&modestbranding=1';
    _web = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.black)
      ..setNavigationDelegate(NavigationDelegate(
        onPageFinished: (_) {
          if (mounted) setState(() => _loading = false);
        },
        // pleyer ichidagi havolalar (kanal, "YouTube'da ko'rish") ilovani olib ketmasin
        onNavigationRequest: (r) => r.url.startsWith(origin) || r.url == 'about:blank'
            ? NavigationDecision.navigate
            : NavigationDecision.prevent,
      ))
      ..loadHtmlString('''
<!doctype html><html><head><meta name="viewport" content="width=device-width,initial-scale=1">
<style>html,body{margin:0;height:100%;background:#000}iframe{position:fixed;inset:0;width:100%;height:100%;border:0}</style>
</head><body>
<iframe src="$src" allow="autoplay; encrypted-media; picture-in-picture; fullscreen" allowfullscreen></iframe>
</body></html>''', baseUrl: origin);
  }

  @override
  Widget build(BuildContext context) => Stack(fit: StackFit.expand, children: [
        WebViewWidget(controller: _web),
        if (_loading) const Center(child: CircularProgressIndicator(color: Color(0xFFFF3B5C))),
      ]);
}
