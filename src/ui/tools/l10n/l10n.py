# Tarjima vositasi (o'zbek -> rus, ingliz).
#
#   python tools/l10n/l10n.py scan lib/screens/x.dart        - tarjima qilinadigan matnlar ro'yxati
#   python tools/l10n/l10n.py wrap lib/screens/x.dart [--skip 3,7]  - matnlarni tr()/trf() ga o'raydi
#   python tools/l10n/l10n.py unconst                        - o'rashdan keyin yaroqsiz `const` larni oladi
#   python tools/l10n/l10n.py add qism.json                  - [[uz, ru, en], ...] ni tarjima.json ga qo'shadi
#   python tools/l10n/l10n.py gen                            - tarjima.json -> lib/l10n/ru.dart, en.dart
#   python tools/l10n/l10n.py check                          - koddagi kalitlarning tarjimasi borligini tekshiradi
#   python tools/l10n/l10n.py keys lib/screens/x.dart        - fayldagi tarjimasi yo'q kalitlar (JSON)
#
# Kalit - o'zbekcha matnning o'zi. O'zgaruvchili matn: '$n kun' -> trf('{0} kun', [n]).
# Loyiha ildizidan ishga tushiriladi.
import io
import json
import os
import re
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
JSON_PATH = os.path.join(ROOT, 'tools', 'l10n', 'tarjima.json')
ESC = {'n': '\n', 't': '\t', 'r': '\r', "'": "'", '"': '"', '\\': '\\', '$': '$'}


def rd(p):
    return io.open(p, encoding='utf-8').read()


def wr(p, s):
    io.open(p, 'w', encoding='utf-8', newline='\n').write(s)


class Lit:
    """Bitta satr literali: [start, end) va bo'laklari (matn yoki ifoda)."""

    def __init__(self, start, end, quote, raw, parts):
        self.start, self.end, self.quote, self.raw, self.parts = start, end, quote, raw, parts


def skip_ws_comments(s, i):
    n = len(s)
    while i < n:
        if s[i] in ' \t\r\n':
            i += 1
        elif s.startswith('//', i):
            j = s.find('\n', i)
            i = n if j < 0 else j
        elif s.startswith('/*', i):
            j = s.find('*/', i)
            i = n if j < 0 else j + 2
        else:
            break
    return i


def parse_string(s, i):
    """s[i] - ochuvchi qo'shtirnoq (yoki r dan keyingi). Lit qaytaradi."""
    start = i
    raw = False
    if s[i] == 'r':
        raw = True
        i += 1
    q = s[i]
    triple = s.startswith(q * 3, i)
    quote = q * 3 if triple else q
    i += len(quote)
    parts = []  # ('t', src_text) | ('e', expr_src)
    buf = []
    n = len(s)
    while i < n:
        if s.startswith(quote, i):
            if buf:
                parts.append(('t', ''.join(buf)))
            return Lit(start, i + len(quote), quote, raw, parts)
        c = s[i]
        if not raw and c == '\\':
            buf.append(s[i:i + 2])
            i += 2
            continue
        if not raw and c == '$':
            if i + 1 < n and s[i + 1] == '{':
                j = match_brace(s, i + 1)
                if buf:
                    parts.append(('t', ''.join(buf)))
                    buf = []
                parts.append(('e', s[i + 2:j].strip()))
                i = j + 1
                continue
            m = re.match(r'[A-Za-z_][A-Za-z0-9_]*', s[i + 1:])
            if m:
                if buf:
                    parts.append(('t', ''.join(buf)))
                    buf = []
                parts.append(('e', m.group(0)))
                i += 1 + len(m.group(0))
                continue
        buf.append(c)
        i += 1
    raise ValueError('yopilmagan satr: %d' % start)


def match_brace(s, i):
    """s[i] == '{' - mos '}' indeksini qaytaradi (ichidagi satrlarni hisobga olib)."""
    depth = 0
    n = len(s)
    while i < n:
        c = s[i]
        if c in '\'"':
            i = parse_string(s, i).end
            continue
        if c == '{':
            depth += 1
        elif c == '}':
            depth -= 1
            if depth == 0:
                return i
        i += 1
    raise ValueError('yopilmagan ${')


def literals(s):
    """Fayldagi hamma satr literallari (izohlar tashlab ketiladi)."""
    out = []
    i, n = 0, len(s)
    while i < n:
        if s.startswith('//', i):
            j = s.find('\n', i)
            i = n if j < 0 else j
        elif s.startswith('/*', i):
            j = s.find('*/', i)
            i = n if j < 0 else j + 2
        elif s[i] in '\'"':
            lit = parse_string(s, i)
            out.append(lit)
            i = lit.end
        elif s[i] == 'r' and i + 1 < n and s[i + 1] in '\'"' and (i == 0 or not (s[i - 1].isalnum() or s[i - 1] == '_')):
            lit = parse_string(s, i)
            out.append(lit)
            i = lit.end
        else:
            i += 1
    return out


def groups(s):
    """Yonma-yon turgan literallar bitta guruh ('a' 'b' -> bitta matn)."""
    lits = literals(s)
    out, cur = [], []
    for lit in lits:
        if cur and skip_ws_comments(s, cur[-1].end) == lit.start:
            cur.append(lit)
        else:
            if cur:
                out.append(cur)
            cur = [lit]
    if cur:
        out.append(cur)
    return out


def unescape(t):
    def f(m):
        c = m.group(1)
        if c.startswith('u'):
            return chr(int(c[1:].strip('{}'), 16))
        return ESC.get(c, c)
    return re.sub(r'\\(u\{[0-9a-fA-F]+\}|u[0-9a-fA-F]{4}|.)', f, t)


def template(group):
    """(kalit, ifodalar) - kalitda ifodalar o'rnida {0}, {1} ..."""
    key, exprs = [], []
    for lit in group:
        for kind, v in lit.parts:
            if kind == 't':
                key.append(v if lit.raw else unescape(v))
            else:
                key.append('{%d}' % len(exprs))
                exprs.append(v)
    return ''.join(key), exprs


LETTERS = re.compile(r"[A-Za-z\u0400-\u04ff\u2018\u2019\u02bb\u02bc]{2,}")


def candidate(s, group):
    """Odamga ko'rinadigan matnmi? (taxmin - ro'yxat ko'zdan kechiriladi)"""
    key, exprs = template(group)
    text = re.sub(r'\{\d+\}', '', key)
    if not LETTERS.search(text):
        return False
    a, b = group[0].start, group[-1].end
    line_start = s.rfind('\n', 0, a) + 1
    line = s[line_start:s.find('\n', a) if s.find('\n', a) >= 0 else len(s)]
    if re.match(r'\s*(import|export|part)\s', line):
        return False
    before = s[max(0, a - 40):a].rstrip()
    after = s[b:b + 6].lstrip()
    if re.search(r'(?<![A-Za-z0-9_])(tr|trf)\($', before):
        return False  # allaqachon o'ralgan
    if before.endswith('[') and after.startswith(']'):
        return False  # d['maydon']
    if after.startswith(':') and not exprs and re.match(r"^[A-Za-z_][A-Za-z0-9_]*$", key)             and (before.endswith('{') or before.endswith(',')):
        return False  # {'maydon': ...} (shartli ifodadagi `? 'a' : 'b'` emas)
    if re.search(r"(collection|doc|where|orderBy|RegExp|getString|getBool|getInt|setString|setBool|setInt|"
                 r"getStringList|setStringList|remove|startsWith|endsWith|ValueKey|Key|asset|AssetImage|"
                 r"getLocation|debugPrint|Exception|StateError|ArgumentError|fromEnvironment|"
                 r"hasPrefix|padLeft|padRight|split|replaceAll|contains|join)\($", before):
        return False
    if re.search(r'(==|!=|case)$', before):
        return False
    if after.startswith('=>') or after.startswith('=='):
        return False  # switch namunasi yoki solishtirish
    # bitta kichik harfli so'z / identifikator / yo'l - ko'pincha kalit
    if not exprs and re.match(r"^[a-z0-9_./:%@#+-]+$", key):
        return False
    return True


def line_of(s, i):
    return s.count('\n', 0, i) + 1


def cmd_scan(path):
    s = rd(path)
    k = 0
    for g in groups(s):
        if not candidate(s, g):
            continue
        key, exprs = template(g)
        print('%3d  L%-4d %s%s' % (k, line_of(s, g[0].start), json.dumps(key, ensure_ascii=False),
                                  '   <- ' + ' | '.join(exprs) if exprs else ''))
        k += 1


def rel_import(path):
    d = os.path.dirname(os.path.abspath(path))
    target = os.path.join(ROOT, 'lib', 'l10n', 'tr.dart')
    return os.path.relpath(target, d).replace(os.sep, '/')


def cmd_wrap(path, skip):
    s = rd(path)
    cands = [g for g in groups(s) if candidate(s, g)]
    todo = [(i, g) for i, g in enumerate(cands) if i not in skip]
    keys = []
    for _, g in reversed(todo):
        key, exprs = template(g)
        keys.append(key)
        a, b = g[0].start, g[-1].end
        if not exprs:
            new = 'tr(' + s[a:b] + ')'
        else:
            n = 0
            pieces = []
            pos = a
            for lit in g:
                pieces.append(s[pos:lit.start])
                body = []
                for kind, v in lit.parts:
                    if kind == 't':
                        body.append(v)
                    else:
                        body.append('{%d}' % n)
                        n += 1
                pieces.append(('r' if lit.raw else '') + lit.quote + ''.join(body) + lit.quote)
                pos = lit.end
            new = 'trf(' + ''.join(pieces) + ', [' + ', '.join(exprs) + '])'
        s = s[:a] + new + s[b:]
    imp = "import '%s';" % rel_import(path)
    if todo and imp not in s:
        lines = s.split('\n')
        idx = [i for i, l in enumerate(lines) if l.startswith('import ')]
        rel = [i for i in idx if lines[i].startswith("import '.") or lines[i].startswith("import 'l10n")
               or not lines[i].startswith("import 'package:") and not lines[i].startswith("import 'dart:")]
        at = idx[-1] + 1 if idx else 0
        for i in rel:
            if lines[i] > imp:
                at = i
                break
        lines.insert(at, imp)
        s = '\n'.join(lines)
    wr(path, s)
    print('o\'raldi: %d ta (%s)' % (len(todo), path))


def used_keys(paths):
    """Koddagi tr('...') / trf('...', [...]) kalitlari."""
    out = {}
    for p in paths:
        s = rd(p)
        for g in groups(s):
            before = s[max(0, g[0].start - 6):g[0].start]
            if re.search(r'(?<![A-Za-z0-9_])(tr|trf)\($', before):
                key, _ = template(g)
                out.setdefault(key, p)
    return out


def all_dart():
    out = []
    for d, _, fs in os.walk(os.path.join(ROOT, 'lib')):
        for f in fs:
            if f.endswith('.dart'):
                out.append(os.path.join(d, f))
    return out


def load_json():
    return json.loads(rd(JSON_PATH)) if os.path.exists(JSON_PATH) else {}


def cmd_keys(path):
    have = load_json()
    miss = [k for k in used_keys([path]) if k not in have or not have[k].get('ru') or not have[k].get('en')]
    print(json.dumps(miss, ensure_ascii=False, indent=0))


def dart_str(v):
    return "'" + v.replace('\\', '\\\\').replace("'", "\\'").replace('$', '\\$').replace('\n', '\\n') + "'"


def cmd_gen():
    data = load_json()
    for lang in ('ru', 'en'):
        rows = ['// GENERATSIYA QILINGAN - qo\'lda tahrirlamang.',
                '// Manba: tools/l10n/tarjima.json;  python tools/l10n/l10n.py gen',
                '', 'const %s = <String, String>{' % lang]
        for k in sorted(data):
            v = data[k].get(lang, '')
            if v:
                rows.append('  %s: %s,' % (dart_str(k), dart_str(v)))
        rows.append('};')
        wr(os.path.join(ROOT, 'lib', 'l10n', lang + '.dart'), '\n'.join(rows) + '\n')
    print('lug\'at: %d kalit' % len(data))


def cmd_check():
    data = load_json()
    used = used_keys(all_dart())
    bad = 0
    for k, p in sorted(used.items()):
        t = data.get(k, {})
        miss = [l for l in ('ru', 'en') if not t.get(l)]
        if miss:
            bad += 1
            print('YO\'Q %s: %s  (%s)' % ('/'.join(miss), json.dumps(k, ensure_ascii=False),
                                         os.path.relpath(p, ROOT).replace(os.sep, '/')))
        else:
            for l in ('ru', 'en'):  # {0} lar soni mos kelishi kerak
                if sorted(re.findall(r'\{\d+\}', k)) != sorted(re.findall(r'\{\d+\}', t[l])):
                    bad += 1
                    print('O\'RINBOSAR MOS EMAS %s: %s' % (l, json.dumps(k, ensure_ascii=False)))
    extra = [k for k in data if k not in used]
    print('koddagi kalit: %d, tarjimasi yo\'q: %d, kodda ishlatilmagan: %d' % (len(used), bad, len(extra)))
    return 1 if bad else 0


def cmd_add(path):
    """[[uz, ru, en], ...] ro'yxatini tarjima.json ga qo'shadi (bor kalit yangilanadi)."""
    data = load_json()
    rows = json.loads(rd(path))
    for uz, ru, en in rows:
        data[uz] = {'ru': ru, 'en': en}
    wr(JSON_PATH, json.dumps(dict(sorted(data.items())), ensure_ascii=False, indent=1) + '\n')
    print('qo\'shildi: %d, jami: %d' % (len(rows), len(data)))


def cmd_unconst():
    """`flutter analyze` xatolari bo'yicha yaroqsiz `const` larni olib tashlaydi."""
    codes = ('invalid_constant', 'const_with_non_const', 'non_constant_list_element',
             'non_constant_map_value', 'non_constant_map_element', 'const_eval_method_invocation',
             'const_initialized_with_non_constant_value', 'non_constant_default_value',
             'const_with_non_constant_argument', 'non_constant_set_element')
    for rnd in range(40):
        out = subprocess.run('flutter analyze --no-fatal-infos --no-fatal-warnings', shell=True, cwd=ROOT,
                             capture_output=True, text=True, encoding='utf-8', errors='replace').stdout
        errs = []
        for m in re.finditer(r'error - .*? - (lib[\\/][^:]+):(\d+):(\d+) - (\w+)', out):
            if m.group(4) in codes:
                errs.append((m.group(1), int(m.group(2)), int(m.group(3))))
        if not errs:
            print('const xatosi qolmadi (%d aylanish)' % rnd)
            return
        by = {}
        for f, l, c in errs:
            by.setdefault(f, []).append((l, c))
        fixed = 0
        for f, locs in by.items():
            p = os.path.join(ROOT, f)
            s = rd(p)
            starts = [0]
            for m in re.finditer('\n', s):
                starts.append(m.end())
            removes = set()
            for l, c in locs:
                off = starts[l - 1] + c - 1
                k = enclosing_const(s, off)
                if k is not None:
                    removes.add(k)
            for k in sorted(removes, reverse=True):
                s = s[:k] + s[k + 6:]
                fixed += 1
            wr(p, s)
        print('aylanish %d: %d xato, %d const olindi' % (rnd, len(errs), fixed))
        if not fixed:
            print('const topilmadi - qo\'lda ko\'ring:')
            for e in errs[:15]:
                print('  ', e)
            return


def enclosing_const(s, off):
    """off ni o'z ichiga olgan eng yaqin `const ` ifodasining boshlanishi."""
    for m in reversed(list(re.finditer(r'(?<![A-Za-z0-9_])const ', s[:off + 1]))):
        k = m.start()
        j = m.end()
        # const dan keyingi ifoda oxirini topamiz: birinchi ( [ { dan mos yopilishigacha
        mm = re.search(r'[(\[{;]', s[j:])
        if not mm or s[j + mm.start()] == ';':
            continue
        o = j + mm.start()
        if '=' in s[j:o]:
            continue  # e'lon (`const x = ...`) — `const` olib tashlansa kod buziladi; qo'lda ko'riladi
        e = match_any(s, o)
        if e is not None and o <= off <= e or k <= off <= o:
            return k
    return None


def match_any(s, i):
    pairs = {'(': ')', '[': ']', '{': '}'}
    stack = []
    n = len(s)
    while i < n:
        c = s[i]
        if c in '\'"':
            i = parse_string(s, i).end
            continue
        if s.startswith('//', i):
            j = s.find('\n', i)
            i = n if j < 0 else j
            continue
        if c in pairs:
            stack.append(pairs[c])
        elif stack and c == stack[-1]:
            stack.pop()
            if not stack:
                return i
        i += 1
    return None


if __name__ == '__main__':
    os.chdir(ROOT)
    a = sys.argv[1:]
    if not a:
        print(__doc__ or 'scan | wrap | unconst | gen | check | keys')
    elif a[0] == 'scan':
        cmd_scan(a[1])
    elif a[0] == 'wrap':
        skip = set()
        if '--skip' in a:
            skip = {int(x) for x in a[a.index('--skip') + 1].split(',') if x}
        cmd_wrap(a[1], skip)
    elif a[0] == 'keys':
        cmd_keys(a[1])
    elif a[0] == 'add':
        cmd_add(a[1])
    elif a[0] == 'gen':
        cmd_gen()
    elif a[0] == 'check':
        sys.exit(cmd_check())
    elif a[0] == 'unconst':
        cmd_unconst()
