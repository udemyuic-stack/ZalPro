# Orqa ko'rinishda (180 gradus) oyoq ostidagi pol aksini olib tashlab, botinkani chizadi.
#   python tools/tana/pol_tozalash.py
# Nega alohida: manba "360 gradus" rasmi repoda yo'q (va saqlanmagan), shuning uchun
# tuzatish zarrachalar.py da emas, tayyor nuqtalar ustida qilinadi
# (lib/widgets/body_photo_points.dart). Qayta ishga tushirilsa natija o'zgarmaydi.
# Muammo: orqa ko'rinishda boldirdan pastda pol yaltiraydi, botinka esa qora - nuqtalar
# botinkani emas, pol dog'larini chizgan va oyoq "sochilib yotgan" ko'rinardi.
# Yechim: shu zonadagi nuqtalar olib tashlanadi, o'rniga ikkita botinka shakli chiziladi
# (ichi xira, cheti va tagi yorug'roq) - rasmdan emas, qo'lda berilgan shakl.
import io
import random
import re

PATH = 'lib/widgets/body_photo_points.dart'
VIEW = 4            # orqa ko'rinish
FROM_Y = 752        # shundan pastda (400x900 o'lchamda) - botinka sohasi
STEP = 3            # nuqtalar to'ri qadami (zarrachalar.py bilan bir xil)
# chap botinka (ko'pburchak); o'ngisi - o'rta chiziqqa (x = 200) nisbatan ko'zgusi
BOOT = [(70, 752), (146, 752), (150, 800), (156, 842), (64, 842), (66, 800)]


def inside(x, y, poly):
    hit = False
    for i in range(len(poly)):
        (x1, y1), (x2, y2) = poly[i], poly[(i + 1) % len(poly)]
        if (y1 > y) != (y2 > y) and x < (x2 - x1) * (y - y1) / (y2 - y1) + x1:
            hit = not hit
    return hit


def boot(poly, rnd):
    xs, ys = [p[0] for p in poly], [p[1] for p in poly]
    pts = []
    for gy in range(min(ys), max(ys) + 1, STEP):
        for gx in range(min(xs), max(xs) + 1, STEP):
            x, y = gx + rnd.randint(-1, 1), gy + rnd.randint(-1, 1)
            if not inside(x, y, poly):
                continue
            # chetiga yaqinmi: atrofdagi nuqtalardan biri tashqarida
            edge = not all(inside(x + dx, y + dy, poly) for dx, dy in ((-5, 0), (5, 0), (0, -5), (0, 5)))
            if edge:
                pts.append((x, y, 4 if y > max(ys) - 8 else 3))
            elif rnd.random() < 0.55:
                pts.append((x, y, 1))
    return pts


src = io.open(PATH, encoding='utf-8').read()
rows = re.findall(r'^  \[([^\]]+)\],$', src, re.M)
assert len(rows) == 8, len(rows)
out = []
for k, row in enumerate(rows):
    n = [int(v) for v in row.split(',')]
    pts = list(zip(n[0::3], n[1::3], n[2::3]))
    if k == VIEW:
        rnd = random.Random(41)
        kept = [p for p in pts if p[1] < FROM_Y]
        right = [(400 - x, y) for x, y in BOOT]
        kept += boot(BOOT, rnd) + boot(right, rnd)
        print('korinish', k, ':', len(pts), '->', len(kept))
        pts = kept
    out.append('  [%s],' % ', '.join('%d, %d, %d' % p for p in pts))
head = src[:src.index('const bodyViews')]
note = "// Nuqtalar soni ko'rinishlarda har xil bo'lishi mumkin (tools/tana/pol_tozalash.py).\n"
if note not in head:
    head = head.replace('const bodyW', note + 'const bodyW')
io.open(PATH, 'w', encoding='utf-8', newline='\n').write(
    head + 'const bodyViews = <List<int>>[\n' + '\n'.join(out) + '\n];\n')
