# Tana zarrachalari ro'yxatini yasaydi ("Tana xaritasi" ekrani uchun).
#   python tools/tana/zarrachalar.py <360-rasm> [namuna-papka]
# Manba: zal egasi bergan "360 gradus" varag'i (1254x1254) - yuqori qatorida bitta qomat
# 8 tomondan (0, 45, 90 ... 315 gradus) turibdi. Har ko'rinish fondan ajratiladi va
# zarrachalarga aylantiriladi.
# Natija: lib/widgets/body_photo_points.dart
#   bodyW x bodyH (400x900) o'lchamda 8 ta ro'yxat; har nuqta: x, y, yorqinlik darajasi 0..5.
#   Hamma ko'rinishda nuqtalar soni bir xil va tartibi mos (yuqoridan pastga, chapdan o'ngga) -
#   ilova bir ko'rinishdan ikkinchisiga nuqtama-nuqta o'tadi (aylanish shunday chiqadi).
# Manba rasm repoga qo'yilmaydi - faqat undan olingan nuqtalar.
import random
import sys
from PIL import Image, ImageChops, ImageDraw, ImageFilter

W, H = 400, 900          # bitta ko'rinish o'lchami (manbadan 2 baravar katta)
TOP, BOT = 82, 532       # manba rasmda qomatlar qatori
# har ko'rinishning manbadagi chap-o'ng chegarasi
BOX = [(8, 188), (190, 348), (358, 472), (474, 622), (618, 792), (790, 930), (932, 1040), (1062, 1234)]
# qomatlar orasidagi bo'sh ustunlar - fon yorqinligi shulardan olinadi
GAPS = [3, 189, 352, 473, 620, 791, 931, 1050, 1240]
STEP = 3                 # zarrachalar to'ri qadami
ROWS, PER_ROW = 130, 96  # har ko'rinishda ROWS x PER_ROW ta zarracha
LOW = 372               # shundan pastda (qator ichida) pol yorug' - faqat boldir ustunlari olinadi
TORSO = 36               # gavdaning o'rta chiziqdan yarim kengligi (teshik to'ldirish uchun)
SPECK = 140              # shundan kichik (piksel) uzilgan bo'lak - shovqin
FEET = 2                 # botinka boldirdan shuncha piksel keng bo'lishi mumkin
FLOOR = 428              # shundan pastda (qator ichida) pol aksi - olinmaydi


def prepare(src):
    """Fon ayirilgan rasm (qomat yorug', fon qora) va qomat chegarasi."""
    im = Image.open(src).convert('L')
    # manba juda qorong'i: to'q ohanglar ko'tariladi
    enh = im.point(lambda v: min(255, int((v / 255) ** 0.45 * 255))).filter(ImageFilter.GaussianBlur(1.0))
    px = enh.load()
    bg = Image.new('L', im.size)
    bd = ImageDraw.Draw(bg)
    for y in range(im.height):
        v = sorted(px[x, y] for x in GAPS)
        bd.line([(0, y), (im.width, y)], fill=v[len(v) // 2])
    diff = ImageChops.subtract(enh, bg)
    mask = diff.point(lambda v: 255 if v > 6 else 0)
    mask = mask.filter(ImageFilter.MaxFilter(9)).filter(ImageFilter.MinFilter(9))   # teshiklar yopiladi
    mask = mask.filter(ImageFilter.MinFilter(7)).filter(ImageFilter.MaxFilter(7))   # ingichka dog'lar ketadi
    md = ImageDraw.Draw(mask)
    md.rectangle((0, TOP + FLOOR, im.width, im.height), fill=0)
    # Pol aksi: oyoq ostida va oyoqlar orasida pol yaltiraydi - nuqtalar "sochilib" chiqadi.
    # Botinka sohasida faqat boldir ustunlari (sal kengaytirilgan) qoldiriladi.
    mp = mask.load()
    y0 = TOP + LOW
    for l, r in BOX:
        legs = [any(mp[x, y] for y in range(y0 - 30, y0)) for x in range(l, r)]
        for i, x in enumerate(range(l, r)):
            if not any(legs[max(0, i - FEET):i + FEET + 1]):
                md.line([(x, y0), (x, TOP + FLOOR)], fill=0)
    # Gavda ichidagi teshiklar (ko'krak osti va kurak soyasi): juda qorong'i bo'lgani uchun
    # chegaradan tushib qolgan - ko'krak yoki qorin tanlanganda o'sha joy bo'sh qolardi.
    # Faqat gavdaning o'rta ustunlarida to'ldiriladi: qo'l bilan gavda orasidagi haqiqiy
    # bo'shliq (chetroqda) ochiq qoladi.
    out = mask.copy()
    ImageDraw.floodfill(out, (0, 0), 128)
    holes = out.point(lambda v: 255 if v == 0 else 0)
    mid = Image.new('L', im.size, 0)
    for l, r in BOX:
        bb = mask.crop((l, TOP, r, BOT)).getbbox()
        cx = l + (bb[0] + bb[2]) // 2
        ImageDraw.Draw(mid).rectangle((cx - TORSO, TOP + 60, cx + TORSO, TOP + 215), fill=255)
    mask = ImageChops.lighter(mask, ImageChops.multiply(holes, mid))
    return diff, mask


def view(diff, mask, box):
    """Bitta ko'rinish: W x H rasm va chegara, qomat o'rtaga qo'yilgan."""
    l, r = box
    bb = mask.crop((l, TOP, r, BOT)).getbbox()
    cx = l + (bb[0] + bb[2]) // 2
    crop = (cx - W // 4, TOP, cx + W // 4, BOT)
    # qo'shni qomat kirib qolmasin
    keep = Image.new('L', diff.size, 0)
    ImageDraw.Draw(keep).rectangle((l, 0, r, diff.height), fill=255)
    m = ImageChops.multiply(mask, keep)
    # Qomatdan uzilgan mayda dog'lar (fon shovqini) - nuqtalar "sochilib" ko'rinadi.
    # Kichik bo'laklar tashlanadi; yirik bo'lak qoladi (botinka boldirdan uzilgan bo'lishi
    # mumkin - shim pochasi juda qorong'i).
    lab = m.crop((l, TOP, r, BOT)).point(lambda v: 255 if v > 127 else 0)
    lp, n, keep_ids = lab.load(), 0, set()
    for y in range(lab.height):
        for x in range(lab.width):
            if lp[x, y] == 255 and n < 250:
                n += 1
                ImageDraw.floodfill(lab, (x, y), n)
                if lab.histogram()[n] >= SPECK:
                    keep_ids.add(n)
    main = Image.new('L', diff.size, 0)
    main.paste(lab.point(lambda v: 255 if v in keep_ids else 0), (l, TOP))
    m = ImageChops.multiply(m, main)
    im = diff.crop(crop).resize((W, H), Image.LANCZOS)
    # Qora kiyim (ko'ylak, shim) terisi ochiq qo'llardan ancha xira - ko'krak, qorin, orqa
    # relyefi yo'qolib ketadi. Har joy o'z atrofining o'rtacha yorqinligiga bo'linadi:
    # kiyim ichidagi burma va mushak qirralari ham to'liq ko'rinadi. Asl rasm bilan
    # aralashtiriladi - qo'llar baribir yorug'roq qoladi.
    loc = im.filter(ImageFilter.GaussianBlur(26)).load()
    px = im.load()
    for y in range(H):
        for x in range(W):
            v = px[x, y]
            n = min(255, 118 * v / (loc[x, y] + 10))
            px[x, y] = int(v * 0.3 + n * 0.7)
    # mushak qirralari aniqroq chiqsin (relyef)
    im = im.filter(ImageFilter.UnsharpMask(radius=6, percent=170, threshold=2))
    return im, m.crop(crop).resize((W, H), Image.BILINEAR)


def sample(im, mask, seed):
    """Zarrachalar: xira joyda siyrak, yorug' joyda zich."""
    px, mk = im.load(), mask.load()
    rnd = random.Random(seed)
    pts = []
    for gy in range(0, H, STEP):
        for gx in range(0, W, STEP):
            x = min(W - 1, max(0, gx + rnd.randint(-1, 1)))
            y = min(H - 1, max(0, gy + rnd.randint(-1, 1)))
            if mk[x, y] < 128:
                continue
            lum = min(1.0, px[x, y] / 190)
            # soyada nuqta kam, yorug'da ko'p - relyef zichlikdan ham bilinadi
            if rnd.random() > min(1.0, 0.3 + lum * 1.9):
                continue
            pts.append((x, y, min(5, int(lum ** 0.85 * 6.4))))
    # hamma ko'rinishda bir xil son: ortig'i tashlanadi, kami takrorlanadi
    n = ROWS * PER_ROW
    rnd.shuffle(pts)
    while len(pts) < n:
        x, y, q = pts[rnd.randrange(len(pts))]
        pts.append((min(W - 1, x + rnd.randint(-1, 1)), min(H - 1, y + rnd.randint(-1, 1)), q))
    pts = sorted(pts[:n], key=lambda p: p[1])
    # mos tartib: yuqoridan pastga teng qatorlar, qator ichida chapdan o'ngga
    out = []
    for i in range(ROWS):
        out += sorted(pts[i * PER_ROW:(i + 1) * PER_ROW])
    return out


def preview(pts, path):
    """Namuna: 2 baravar katta, 50 birlikli to'r bilan (mushak joylarini belgilash uchun)."""
    prev = Image.new('RGB', (W * 2, H * 2), (0, 0, 0))
    pd = ImageDraw.Draw(prev)
    for x, y, q in pts:
        g = 38 + q * 43
        r = 1.0 + q * 0.22
        pd.ellipse((x * 2 - r, y * 2 - r, x * 2 + r, y * 2 + r), fill=(g, g, g))
    for v in range(0, W, 50):
        pd.line([(v * 2, 0), (v * 2, H * 2)], fill=(70, 40, 160))
        pd.text((v * 2 + 3, 2), str(v), fill=(255, 200, 60))
    for v in range(0, H, 50):
        pd.line([(0, v * 2), (W * 2, v * 2)], fill=(70, 40, 160))
        pd.text((3, v * 2 + 2), str(v), fill=(255, 200, 60))
    prev.save(path)


diff, mask = prepare(sys.argv[1])
views = [sample(*view(diff, mask, b), seed=11 + i) for i, b in enumerate(BOX)]

out = ("// GENERATSIYA QILINGAN - qo'lda tahrirlamang.\n"
       '// python tools/tana/zarrachalar.py <360-rasm>\n'
       '// Tana zarrachalari 8 tomondan (0, 45 ... 315 gradus; 0 - old, 4 - orqa).\n'
       "// Har nuqta: x, y (%dx%d o'lchamda), yorqinlik darajasi 0..5. Tartib hamma ko'rinishda mos.\n"
       'const bodyW = %d.0, bodyH = %d.0;\n'
       'const bodyViews = <List<int>>[\n' % (W, H, W, H))
for v in views:
    out += '  [%s],\n' % ', '.join('%d, %d, %d' % p for p in v)
out += '];\n'
open('lib/widgets/body_photo_points.dart', 'w', encoding='utf-8', newline='\n').write(out)
print('korinishlar:', len(views), 'har birida:', len(views[0]))
if len(sys.argv) > 2:
    for i, v in enumerate(views):
        preview(v, '%s/v%d.png' % (sys.argv[2], i))
    strip = Image.new('RGB', (W * 4, H // 2), (0, 0, 0))
    for i in range(8):
        strip.paste(Image.open('%s/v%d.png' % (sys.argv[2], i)).resize((W // 2, H // 2)), (i * W // 2, 0))
    strip.save(sys.argv[2] + '/hammasi.png')
    mask.crop((0, TOP, mask.width, BOT)).save(sys.argv[2] + '/chegara.png')
