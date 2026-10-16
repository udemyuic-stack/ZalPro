import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'package:flutter/material.dart';

/// YouTube pleyeri — brauzerda: sahifaning o'ziga qo'yilgan `<iframe>` (yangi oyna ochilmaydi).
Widget youtubeEmbed(String id) => HtmlElementView.fromTagName(
      key: ValueKey(id),
      tagName: 'iframe',
      onElementCreated: (el) {
        final f = el as JSObject;
        void set(String k, String v) => f.setProperty(k.toJS, v.toJS);
        set('src',
            'https://www.youtube-nocookie.com/embed/$id?autoplay=1&playsinline=1&rel=0&modestbranding=1');
        set('allow', 'autoplay; encrypted-media; picture-in-picture; fullscreen');
        set('allowFullscreen', 'true');
        (f.getProperty('style'.toJS) as JSObject)
          ..setProperty('border'.toJS, '0'.toJS)
          ..setProperty('background'.toJS, '#000'.toJS);
      },
    );
