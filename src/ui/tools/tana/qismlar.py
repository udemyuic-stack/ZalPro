# Qismli tana chizmasi ma'lumotini yasaydi (har mushak - alohida ko'pburchak).
#   python tools/tana/qismlar.py <index.ts>
# Manba: react-body-highlighter (MIT, Copyright (c) 2020 GV79) - src/assets/index.ts
#   https://github.com/giavinh79/react-body-highlighter
# Natija: lib/widgets/body_parts_data.dart - old va orqa tomon, 200x440 o'lchamda
# (manba 1000x2200, 5 marta kichraytiriladi). Mushak nomlari ilovadagi id'larga o'giriladi
# (lib/models/exercises.dart); bosh, bo'yin, tizza - mushak emas (bo'sh nom).
import re
import sys

# manbadagi nom -> ilovadagi mushak id'si (old tomon, orqa tomon)
MAP = {
    'CHEST': ('chest', 'chest'),
    'ABS': ('abs', 'abs'),
    'OBLIQUES': ('abs', 'abs'),
    'BICEPS': ('biceps', 'biceps'),
    'TRICEPS': ('triceps', 'triceps'),
    'FOREARM': ('forearms', 'forearms'),
    'FRONT_DELTOIDS': ('shoulders', 'shoulders'),
    'BACK_DELTOIDS': ('shoulders', 'shoulders'),
    'TRAPEZIUS': ('traps', 'traps'),
    'UPPER_BACK': ('back', 'back'),
    'LOWER_BACK': ('back', 'back'),
    'GLUTEAL': ('glutes', 'glutes'),
    'QUADRICEPS': ('quads', 'quads'),
    'HAMSTRING': ('hamstrings', 'hamstrings'),
    # sonning ichki va tashqi mushaklari: oldda son oldiga, orqada son orqasiga qo'shiladi
    'ADDUCTOR': ('quads', 'hamstrings'),
    'ABDUCTORS': ('quads', 'hamstrings'),
    'CALVES': ('calves', 'calves'),
    'LEFT_SOLEUS': ('calves', 'calves'),
    'RIGHT_SOLEUS': ('calves', 'calves'),
    'HEAD': ('', ''),
    'NECK': ('', ''),
    'KNEES': ('', ''),
}

src = open(sys.argv[1], encoding='utf-8').read()
out = ("// GENERATSIYA QILINGAN - qo'lda tahrirlamang.\n"
       '// python tools/tana/qismlar.py <index.ts>\n'
       '// Manba: react-body-highlighter (MIT, Copyright (c) 2020 GV79),\n'
       '// https://github.com/giavinh79/react-body-highlighter - litsenziya matni:\n'
       '// tools/tana/LICENSE-react-body-highlighter.txt\n'
       "// Har qism: mushak id'si (bo'sh - mushak emas) va ko'pburchak nuqtalari x, y, x, y ...\n"
       "// (200x440 o'lchamda).\n")
for side, (name, k) in {'anteriorData': ('bodyPartsFront', 0), 'posteriorData': ('bodyPartsBack', 1)}.items():
    i = src.index('export const ' + side)
    j = src.find('export const', i + 10)
    blk = src[i:j if j > 0 else len(src)]
    out += 'const %s = <(String, List<double>)>[\n' % name
    n = 0
    for m in re.finditer(r'muscle: MuscleType\.(\w+),\s*svgPoints: \[(.*?)\]', blk, re.S):
        for p in re.findall(r"'([^']*)'", m.group(2)):
            pts = ['%g' % round(float(v) / 5, 1) for v in p.split()]
            out += "  ('%s', [%s]),\n" % (MAP[m.group(1)][k], ', '.join(pts))
            n += 1
    out += '];\n'
    print(name, n)
open('lib/widgets/body_parts_data.dart', 'w', encoding='utf-8', newline='\n').write(out)
