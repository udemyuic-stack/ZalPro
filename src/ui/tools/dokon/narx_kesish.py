# -*- coding: utf-8 -*-
"""Do'kon rasmlari: javon suratidan har bir mahsulotni alohida kesib oladi.

AllPituz kanalidagi suratlarda har mahsulot tepasida (yuqori qator) yoki
pastida (pastki qator) oq narx yorlig'i turadi. Shu yorliqlar bo'yicha
mahsulot ustuni topiladi.

    python tools/dokon/narx_kesish.py <rasm.jpg> <chiqish-papka> <nom-boshi> [joylashuv]

Joylashuv — yorliq mahsulotga nisbatan qayerda:
    tepa     yorliq mahsulot ustida (standart)
    past     yorliq mahsulot ostida
    aralash  yuqori qatorda ustida, pastki qatorda ostida
"""
import os
import sys

import numpy as np
from PIL import Image


def yorliqlar(a):
    """Oq narx yorliqlarini topadi -> [(x0, y0, x1, y1), ...]"""
    h, w, _ = a.shape
    white = a.min(axis=2) >= 235
    seen = np.zeros_like(white)
    out = []
    for y in range(h):
        for x in range(w):
            if not white[y, x] or seen[y, x]:
                continue
            # to'lqin bilan bog'langan sohani yig'amiz
            stack, pix = [(y, x)], []
            seen[y, x] = True
            while stack:
                cy, cx = stack.pop()
                pix.append((cy, cx))
                for ny, nx in ((cy-1, cx), (cy+1, cx), (cy, cx-1), (cy, cx+1)):
                    if 0 <= ny < h and 0 <= nx < w and white[ny, nx] and not seen[ny, nx]:
                        seen[ny, nx] = True
                        stack.append((ny, nx))
            if len(pix) < 700:
                continue
            ys = [p[0] for p in pix]
            xs = [p[1] for p in pix]
            y0, y1, x0, x1 = min(ys), max(ys), min(xs), max(xs)
            bw, bh = x1 - x0 + 1, y1 - y0 + 1
            if bw < w*0.045 or bh < h*0.035 or bw > w*0.30 or bh > h*0.25:
                continue
            if len(pix) / (bw*bh) < 0.55 or not 0.9 <= bw/bh <= 4.5:
                continue
            out.append((x0, y0, x1, y1))
    return sorted(out, key=lambda b: (b[1] > a.shape[0]*0.5, b[0]))


def kes(path, out_dir, prefix, joy='tepa'):
    im = Image.open(path).convert('RGB')
    a = np.asarray(im).astype(int)
    h, w, _ = a.shape
    tags = yorliqlar(a)
    os.makedirs(out_dir, exist_ok=True)
    rows = {}
    for b in tags:
        cy = (b[1] + b[3]) / 2
        rows.setdefault('yuqori' if cy < h*0.5 else 'pastki', []).append(b)
    n = 0
    for row, items in rows.items():
        items.sort(key=lambda b: b[0])
        for i, b in enumerate(items):
            x0, y0, x1, y1 = b
            cx = (x0 + x1) / 2
            left = (cx + (items[i-1][0]+items[i-1][2])/2) / 2 if i else max(0, cx - w*0.11)
            right = ((cx + (items[i+1][0]+items[i+1][2])/2) / 2
                     if i+1 < len(items) else min(w, cx + w*0.11))
            # bo'y: yorliqdan boshlab bir mahsulotlik (qo'shni qatorga o'tmasin)
            pastda = (joy == 'past') or (joy == 'aralash' and row == 'pastki')
            if pastda:  # mahsulot yorliqdan TEPADA
                ky0, ky1 = max(0, int(y0 - h*0.42)), y0 - 2
            else:       # mahsulot yorliqdan PASTDA
                ky0, ky1 = y1 + 2, min(h, int(y1 + h*0.42))
            n += 1
            p = os.path.join(out_dir, f'{prefix}-{row}-{i+1}.jpg')
            im.crop((int(left), int(ky0), int(right), int(ky1))).save(p, quality=92)
            print(p, '| yorliq', b)
    print('jami:', n, 'ta kesildi')


if __name__ == '__main__':
    kes(sys.argv[1], sys.argv[2],
        sys.argv[3] if len(sys.argv) > 3 else 'tovar',
        sys.argv[4] if len(sys.argv) > 4 else 'tepa')
