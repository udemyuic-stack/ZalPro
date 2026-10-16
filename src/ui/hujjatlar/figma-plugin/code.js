// Diamond UI — Figma plagini.
// Ishga tushirilganda Figma ichida rang stillari, komponentlar va 6 ta ekran ramkasini yaratadi.
// Hammasi haqiqiy Figma qatlami: to'rtburchak, matn, doira — tahrirlash mumkin.

const C = {
  bg: '#16191E',
  bgDeep: '#11141A',
  card: '#22262F',
  cardHigh: '#2C313B',
  text: '#E3E8EE',
  textMuted: '#96A0AE',
  textFaint: '#6B7480',
  accent: '#4AF2FF',
  onAccent: '#08131A',
  success: '#4ADE80',
  warning: '#FBBF24',
  danger: '#FB7185',
  water: '#38BDF8',
  protein: '#A78BFA',
  white: '#FFFFFF',
};

const W = 390;
const H = 844;
const NAV_H = 64;

function rgb(hex) {
  const h = hex.replace('#', '');
  return {
    r: parseInt(h.slice(0, 2), 16) / 255,
    g: parseInt(h.slice(2, 4), 16) / 255,
    b: parseInt(h.slice(4, 6), 16) / 255,
  };
}

function solid(hex, opacity) {
  return { type: 'SOLID', color: rgb(hex), opacity: opacity === undefined ? 1 : opacity };
}

// ---------- qurilish yordamchilari ----------

function frame(name, x, y, w, h, fillHex) {
  const f = figma.createFrame();
  f.name = name;
  f.resize(w, h);
  f.x = x;
  f.y = y;
  f.fills = [solid(fillHex || C.bg)];
  f.clipsContent = true;
  return f;
}

function rect(parent, x, y, w, h, opt) {
  const o = opt || {};
  const r = figma.createRectangle();
  parent.appendChild(r);
  r.resize(w, h);
  r.x = x;
  r.y = y;
  r.cornerRadius = o.radius === undefined ? 12 : o.radius;
  r.fills = o.fill ? [solid(o.fill, o.opacity)] : [];
  if (o.stroke) {
    r.strokes = [solid(o.stroke, o.strokeOpacity === undefined ? 1 : o.strokeOpacity)];
    r.strokeWeight = 1;
  }
  r.name = o.name || 'Ramka';
  return r;
}

function ellipse(parent, x, y, size, opt) {
  const o = opt || {};
  const e = figma.createEllipse();
  parent.appendChild(e);
  e.resize(size, size);
  e.x = x;
  e.y = y;
  e.fills = o.fill ? [solid(o.fill, o.opacity)] : [];
  if (o.stroke) {
    e.strokes = [solid(o.stroke, o.strokeOpacity === undefined ? 1 : o.strokeOpacity)];
    e.strokeWeight = o.strokeWeight || 1;
  }
  e.name = o.name || 'Doira';
  return e;
}

function label(parent, x, y, chars, opt) {
  const o = opt || {};
  const t = figma.createText();
  parent.appendChild(t);
  t.fontName = { family: 'Inter', style: o.style || 'Regular' };
  t.fontSize = o.size || 13;
  t.characters = chars;
  t.fills = [solid(o.color || C.text)];
  if (o.spacing) t.letterSpacing = { unit: 'PIXELS', value: o.spacing };
  if (o.width) {
    t.textAutoResize = 'HEIGHT';
    t.resize(o.width, t.height);
    t.textAlignHorizontal = o.align || 'LEFT';
  }
  t.x = x;
  t.y = y;
  t.name = chars.length > 24 ? chars.slice(0, 24) + '…' : chars;
  return t;
}

/** Shisha kartochka: shaffof to'ldirish + ingichka qirra */
function card(parent, x, y, w, h, feature) {
  const r = rect(parent, x, y, w, h, {
    radius: 12,
    fill: feature ? C.accent : C.card,
    opacity: feature ? 0.07 : 0.72,
    stroke: feature ? C.accent : C.white,
    strokeOpacity: feature ? 0.22 : 0.08,
    name: feature ? 'Karta (urg‘u)' : 'Karta',
  });
  return r;
}

function pill(parent, x, y, chars, colorHex) {
  const w = Math.round(chars.length * 6.4 + 18);
  rect(parent, x, y, w, 22, {
    radius: 6,
    fill: colorHex,
    opacity: 0.12,
    stroke: colorHex,
    strokeOpacity: 0.22,
    name: 'Yorliq',
  });
  label(parent, x + 9, y + 5, chars, { size: 11, color: colorHex, style: 'Semi Bold' });
  return w;
}

function chip(parent, x, y, chars, on) {
  const w = Math.round(chars.length * 7 + 24);
  if (on) {
    rect(parent, x, y, w, 28, { radius: 14, fill: C.accent, name: 'Chip (tanlangan)' });
    label(parent, x + 12, y + 7, chars, { size: 11.5, color: C.onAccent, style: 'Semi Bold' });
  } else {
    rect(parent, x, y, w, 28, {
      radius: 14, stroke: C.white, strokeOpacity: 0.12, name: 'Chip',
    });
    label(parent, x + 12, y + 7, chars, { size: 11.5, color: C.textMuted });
  }
  return w;
}

function button(parent, x, y, w, chars, ghost, h) {
  const hh = h || 40;
  if (ghost) {
    rect(parent, x, y, w, hh, {
      radius: 10, stroke: C.white, strokeOpacity: 0.14, name: 'Tugma (ikkilamchi)',
    });
    label(parent, x, y + hh / 2 - 8, chars, {
      size: 12.5, color: C.text, style: 'Semi Bold', width: w, align: 'CENTER',
    });
  } else {
    rect(parent, x, y, w, hh, { radius: 10, fill: C.accent, name: 'Tugma' });
    label(parent, x, y + hh / 2 - 8, chars, {
      size: 12.5, color: C.onAccent, style: 'Bold', width: w, align: 'CENTER',
    });
  }
}

function thumb(parent, x, y, size, fillHex) {
  return rect(parent, x, y, size, size, {
    radius: Math.round(size * 0.28),
    fill: fillHex || C.cardHigh,
    name: 'Rasm o‘rni',
  });
}

function navbar(parent, items, active) {
  rect(parent, 0, H - NAV_H, W, NAV_H, { radius: 0, fill: C.bgDeep, name: 'Pastki menyu' });
  rect(parent, 0, H - NAV_H, W, 1, { radius: 0, fill: C.white, opacity: 0.08, name: 'Chiziq' });
  const step = W / items.length;
  for (let i = 0; i < items.length; i++) {
    const on = i === active;
    const col = on ? C.accent : C.textFaint;
    ellipse(parent, step * i + step / 2 - 8, H - 50, 16, {
      stroke: col, strokeWeight: 1.4, name: 'Ikonka',
    });
    label(parent, step * i, H - 26, items[i], {
      size: 9.5, color: col, style: on ? 'Semi Bold' : 'Regular', width: step, align: 'CENTER',
    });
  }
}

function appbar(parent, title, subtitle, action) {
  label(parent, 20, 24, title, { size: 17, color: C.text, style: 'Bold' });
  label(parent, 20, 46, subtitle, { size: 10.5, color: C.textMuted });
  rect(parent, 0, 70, W, 1, { radius: 0, fill: C.white, opacity: 0.08, name: 'Chiziq' });
  if (action) button(parent, W - 20 - 104, 22, 104, action, false, 34);
}

function statRow(parent, y, items) {
  const gap = 8;
  const w = (W - 40 - gap * (items.length - 1)) / items.length;
  for (let i = 0; i < items.length; i++) {
    const x = 20 + i * (w + gap);
    card(parent, x, y, w, 64);
    label(parent, x + 12, y + 14, items[i][0], {
      size: 9, color: C.textFaint, style: 'Medium', spacing: 0.8,
    });
    label(parent, x + 12, y + 32, items[i][1], { size: 18, color: C.text, style: 'Bold' });
  }
}

// ---------- rang stillari ----------

function createStyles() {
  const names = Object.keys(C);
  for (let i = 0; i < names.length; i++) {
    const key = names[i];
    const st = figma.createPaintStyle();
    st.name = 'Diamond/' + key;
    st.paints = [solid(C[key])];
  }
}

// ---------- ekranlar ----------

function screenBugun(x) {
  const f = frame('Bugun — shogird', x, 0, W, H);
  label(f, 20, 28, 'CHORSHANBA, 17-SENTABR', {
    size: 10, color: C.textFaint, style: 'Medium', spacing: 1.4,
  });
  label(f, 20, 48, 'Salom, Shogird 1', { size: 26, color: C.text, style: 'Bold' });
  rect(f, W - 66, 30, 46, 46, { radius: 13, fill: '#3A3157', name: 'Avatar' });
  label(f, W - 66, 46, 'NR', { size: 14, color: '#C6B6FF', style: 'Bold', width: 46, align: 'CENTER' });

  card(f, 20, 92, W - 40, 116, true);
  const ringBg = ellipse(f, 40, 114, 72, { fill: C.cardHigh, name: 'Halqa (fon)' });
  ringBg.arcData = { startingAngle: 0, endingAngle: Math.PI * 2, innerRadius: 0.78 };
  const arc = ellipse(f, 40, 114, 72, { fill: C.accent, name: 'Halqa (bajarilgan)' });
  arc.arcData = { startingAngle: -Math.PI / 2, endingAngle: Math.PI * 0.26, innerRadius: 0.78 };
  label(f, 40, 142, '560', { size: 15, color: C.text, style: 'Bold', width: 72, align: 'CENTER' });
  label(f, 128, 112, 'BUGUNGI REJA', { size: 9.5, color: C.textFaint, style: 'Medium', spacing: 1.2 });
  label(f, 128, 130, 'Ozish • 1 haftalik ratsion', { size: 13, color: C.text, style: 'Semi Bold' });
  label(f, 128, 152, '938', { size: 28, color: C.accent, style: 'Bold' });
  label(f, 184, 164, 'kkal qoldi', { size: 12, color: C.textMuted });
  label(f, 128, 184, '38% bajarildi', { size: 10.5, color: C.textFaint });

  statRow(f, 220, [['OQSIL', '125 g'], ['NORMA', '2244'], ['OVQAT', '2/5']]);

  card(f, 20, 296, W - 40, 76);
  label(f, 34, 310, 'SUV · 1 STAKAN = 250 ML', {
    size: 9.5, color: C.water, style: 'Medium', spacing: 1.2,
  });
  label(f, 20, 310, '750 / 2000 ml', {
    size: 10.5, color: C.textFaint, width: W - 54, align: 'RIGHT',
  });
  for (let i = 0; i < 8; i++) {
    ellipse(f, 34 + i * 40, 336, 22, i < 3
      ? { fill: C.water, name: 'Stakan (to‘la)' }
      : { stroke: C.water, strokeOpacity: 0.45, name: 'Stakan' });
  }

  rect(f, 20, 388, W - 40, 100, { radius: 12, fill: '#4A3B2C', name: 'Ratsion rasmi' });
  rect(f, 20, 456, W - 40, 32, { radius: 12, fill: '#000000', opacity: 0.45, name: 'Rasm ustidagi qora' });
  label(f, 32, 464, 'Trener bergan ratsion · Chorshanba', { size: 11, color: C.white, style: 'Medium' });

  const meals = [
    ['08:00  Nonushta', '377 kkal · 34 g oqsil', true],
    ['11:00  Perekus', '156 kkal · 1 g oqsil', false],
    ['14:00  Tushlik', '330 kkal · 11 g oqsil', false],
  ];
  for (let i = 0; i < meals.length; i++) {
    const y = 504 + i * 84;
    card(f, 20, y, W - 40, 72);
    thumb(f, 32, y + 18, 36);
    label(f, 78, y + 16, meals[i][0], { size: 13, color: C.text, style: 'Semi Bold' });
    label(f, 78, y + 38, meals[i][1], { size: 11, color: C.textMuted });
    if (meals[i][2]) pill(f, 200, y + 14, 'Navbatdagi', C.accent);
  }

  navbar(f, ['Bugun', 'Progress', 'Zal', 'Do‘kon', 'Trener', 'Profil'], 0);
  return f;
}

function screenZal(x) {
  const f = frame('Zal — shogird', x, 0, W, H);
  label(f, 20, 28, 'BUGUN · CHORSHANBA', {
    size: 10, color: C.textFaint, style: 'Medium', spacing: 1.4,
  });
  label(f, 20, 48, 'Zal', { size: 26, color: C.text, style: 'Bold' });
  pill(f, W - 150, 46, 'Kunlar tanlangan', C.success);

  card(f, 20, 92, W - 40, 96, true);
  label(f, 36, 110, 'BUGUNGI MASHG‘ULOT', {
    size: 9.5, color: C.textFaint, style: 'Medium', spacing: 1.2,
  });
  label(f, 36, 128, 'Qanot (orqa) + oyoq', { size: 19, color: C.text, style: 'Bold' });
  label(f, 36, 158, '2-mashg‘ulot · haftada 3 marta', { size: 11, color: C.textMuted });

  card(f, 20, 200, W - 40, 112);
  label(f, 36, 216, 'MENING KUNLARIM', {
    size: 9.5, color: C.textFaint, style: 'Medium', spacing: 1.2,
  });
  let cx = 36;
  const days = [['Du', true], ['Se', false], ['Chor', true], ['Pay', false], ['Ju', true], ['Sha', false]];
  for (let i = 0; i < days.length; i++) {
    cx += chip(f, cx, 238, days[i][0], days[i][1]) + 7;
  }
  label(f, 36, 282, 'Dushanba · Chorshanba · Juma', { size: 11, color: C.textMuted });

  card(f, 20, 324, W - 40, 96);
  thumb(f, 36, 344, 36);
  label(f, 84, 348, 'Mashqlar ro‘yxati', { size: 13, color: C.text, style: 'Semi Bold' });
  label(f, 84, 368, 'Ishlab chiqilmoqda — trener matni', { size: 11, color: C.textMuted });
  label(f, 84, 386, 'qo‘shilgach shu yerda chiqadi.', { size: 11, color: C.textMuted });

  card(f, 20, 432, W - 40, 150);
  label(f, 36, 448, 'HAFTALIK JADVAL', {
    size: 9.5, color: C.textFaint, style: 'Medium', spacing: 1.2,
  });
  const week = [
    ['Dushanba', 'Ko‘krak + biceps', false],
    ['Chorshanba', 'Qanot + oyoq', true],
    ['Juma', 'Yelka + triceps', false],
  ];
  for (let i = 0; i < week.length; i++) {
    const y = 476 + i * 32;
    label(f, 36, y, week[i][0], {
      size: 12, color: week[i][2] ? C.accent : C.text, style: 'Semi Bold',
    });
    label(f, 20, y, week[i][1], { size: 11, color: C.textMuted, width: W - 56, align: 'RIGHT' });
  }

  card(f, 20, 594, W - 40, 64);
  label(f, 36, 610, 'Keyingi: Juma', { size: 12.5, color: C.text, style: 'Semi Bold' });
  label(f, 36, 630, 'Yelka + qo‘lning orqasi', { size: 11, color: C.textMuted });
  pill(f, W - 100, 616, '2 kun', C.textMuted);

  navbar(f, ['Bugun', 'Progress', 'Zal', 'Do‘kon', 'Trener', 'Profil'], 2);
  return f;
}

function screenShop(x) {
  const f = frame('Do‘kon — shogird', x, 0, W, H);
  label(f, 20, 30, 'Do‘kon', { size: 26, color: C.text, style: 'Bold' });
  pill(f, W - 140, 38, '1 ta buyurtma', C.warning);

  label(f, 20, 78, 'MENING BUYURTMALARIM', {
    size: 9.5, color: C.textFaint, style: 'Medium', spacing: 1.2,
  });
  card(f, 20, 96, W - 40, 72);
  thumb(f, 32, 114, 36, '#2E2A45');
  label(f, 78, 114, 'Protein izolyat × 2', { size: 13, color: C.text, style: 'Semi Bold' });
  label(f, 78, 136, '900 000 so‘m • Kutilmoqda', { size: 11, color: C.textMuted });
  label(f, 20, 124, 'Bekor', { size: 12, color: C.accent, style: 'Semi Bold', width: W - 52, align: 'RIGHT' });

  let cx = 20;
  const cats = [['Hammasi', true], ['Forma', false], ['Anjomlar', false], ['Pitaniya', false]];
  for (let i = 0; i < cats.length; i++) {
    cx += chip(f, cx, 186, cats[i][0], cats[i][1]) + 8;
  }
  label(f, 20, 226, 'To‘lov zalda, naqd — ilovada karta so‘ralmaydi.', { size: 11, color: C.textFaint });

  const goods = [
    ['Diamond mayka (L)', '', '120 000 so‘m', 'Qoldi: 3', '#2B3A4A'],
    ['Protein izolyat 900 g', 'Shokolad · 30 porsiya', '450 000 so‘m', '', '#2E2A45'],
    ['Qo‘lqop (M)', '', '90 000 so‘m', '', '#3A3A2A'],
  ];
  for (let i = 0; i < goods.length; i++) {
    const y = 250 + i * 108;
    card(f, 20, y, W - 40, 96);
    thumb(f, 32, y + 20, 56, goods[i][4]);
    label(f, 100, y + 20, goods[i][0], { size: 13.5, color: C.text, style: 'Semi Bold' });
    if (goods[i][1]) label(f, 100, y + 40, goods[i][1], { size: 11, color: C.textMuted });
    label(f, 100, y + 60, goods[i][2], { size: 13, color: C.accent, style: 'Bold' });
    if (goods[i][3]) pill(f, 200, y + 58, goods[i][3], C.warning);
    button(f, W - 20 - 88, y + 28, 88, 'Olaman', false, 38);
  }

  label(f, 20, 592, 'OLDINGI BUYURTMALAR', {
    size: 9.5, color: C.textFaint, style: 'Medium', spacing: 1.2,
  });
  label(f, 20, 616, 'Diamond mayka × 1', { size: 12, color: C.text });
  pill(f, W - 92, 612, 'Berildi', C.success);

  navbar(f, ['Bugun', 'Progress', 'Zal', 'Do‘kon', 'Trener', 'Profil'], 3);
  return f;
}

function screenClients(x) {
  const f = frame('Mijozlar — trener', x, 0, W, H);
  appbar(f, 'Mijozlar', 'Trener paneli • Diamond');

  card(f, 20, 86, W - 40, 104);
  label(f, 36, 100, 'KATALOGDAGI PROFILIM', {
    size: 9.5, color: C.textFaint, style: 'Medium', spacing: 1.2,
  });
  label(f, 20, 100, 'Tahrirlash', { size: 11, color: C.accent, style: 'Semi Bold', width: W - 56, align: 'RIGHT' });
  label(f, 36, 120, 'Kotta Qani (trener)', { size: 15, color: C.text, style: 'Bold' });
  label(f, 36, 150, 'Yangi shogird qabul qilaman', { size: 12, color: C.text, style: 'Semi Bold' });
  rect(f, W - 84, 146, 48, 26, { radius: 13, fill: C.accent, name: 'Tugmacha' });
  ellipse(f, W - 62, 149, 20, { fill: C.onAccent, name: 'Tugmacha nuqtasi' });

  statRow(f, 202, [['JAMI', '2'], ['REJA BOR', '2'], ['KUTMOQDA', '0']]);

  rect(f, 20, 282, W - 40, 44, { radius: 10, fill: C.cardHigh, opacity: 0.5, name: 'Qidiruv' });
  label(f, 38, 296, 'Ism yoki telefon raqam bo‘yicha qidirish', { size: 12, color: C.textFaint });

  label(f, 20, 342, 'RO‘YXAT', { size: 9.5, color: C.textFaint, style: 'Medium', spacing: 1.2 });
  label(f, 20, 358, 'Mijozlar', { size: 20, color: C.text, style: 'Bold' });
  label(f, 20, 364, '2', { size: 14, color: C.textMuted, width: W - 40, align: 'RIGHT' });

  const clients = [
    ['JA', 'Shogird 2', '57 kg · BMI 22.3 · 1881 kkal', '#8FD3FF', '#2B3A4A'],
    ['NR', 'Shogird 1', '93 kg · BMI 32.2 · 2604 kkal', '#C6B6FF', '#3A3157'],
  ];
  for (let i = 0; i < clients.length; i++) {
    const y = 396 + i * 92;
    card(f, 20, y, W - 40, 80);
    rect(f, 34, y + 20, 40, 40, { radius: 12, fill: clients[i][4], name: 'Avatar' });
    label(f, 34, y + 32, clients[i][0], {
      size: 13, color: clients[i][3], style: 'Bold', width: 40, align: 'CENTER',
    });
    label(f, 88, y + 22, clients[i][1], { size: 14, color: C.text, style: 'Bold' });
    pill(f, 88 + clients[i][1].length * 8 + 10, y + 20, 'Ozish', C.accent);
    label(f, 88, y + 46, clients[i][2], { size: 11, color: C.textMuted });
    pill(f, W - 118, y + 30, 'Reja bor', C.success);
  }

  card(f, 20, 584, W - 40, 88);
  label(f, 36, 600, 'E’TIBOR BERING', { size: 9.5, color: C.warning, style: 'Medium', spacing: 1.2 });
  label(f, 36, 622, 'Shogird 1: vazn 2 haftadan beri', { size: 12, color: C.text });
  label(f, 36, 642, 'kiritilmagan', { size: 12, color: C.text });

  navbar(f, ['Mijozlar', 'Zal', 'Rejalar', 'Ovqat', 'Do‘kon'], 0);
  return f;
}

function screenShopAdmin(x) {
  const f = frame('Do‘kon — trener', x, 0, W, H);
  appbar(f, 'Do‘kon', 'Trener paneli • Diamond');

  rect(f, 20, 86, W - 40, 40, {
    radius: 20, stroke: C.white, strokeOpacity: 0.12, name: 'Segment',
  });
  rect(f, 20, 86, (W - 40) / 2, 40, { radius: 20, fill: C.accent, name: 'Segment (tanlangan)' });
  label(f, 20, 100, 'Buyurtmalar', {
    size: 12.5, color: C.onAccent, style: 'Bold', width: (W - 40) / 2, align: 'CENTER',
  });
  label(f, 20 + (W - 40) / 2, 100, 'Tovarlar', {
    size: 12.5, color: C.textMuted, width: (W - 40) / 2, align: 'CENTER',
  });

  card(f, 20, 142, W - 40, 80, true);
  thumb(f, 36, 162, 40, '#1E3A2A');
  label(f, 90, 164, '30 kunda: 900 000 so‘m', { size: 15, color: C.text, style: 'Bold' });
  label(f, 90, 188, '1 ta buyurtma berildi', { size: 11, color: C.textMuted });

  label(f, 20, 240, 'Kutilmoqda', { size: 18, color: C.text, style: 'Bold' });
  pill(f, W - 52, 242, '1', C.warning);

  card(f, 20, 272, W - 40, 130);
  thumb(f, 34, 290, 40, '#2E2A45');
  label(f, 86, 290, 'Protein izolyat × 2', { size: 13.5, color: C.text, style: 'Semi Bold' });
  label(f, 86, 312, 'Shogird 1 • Chorshanba, 17-sentabr', { size: 11, color: C.textMuted });
  label(f, 20, 290, '900 000 so‘m', { size: 13, color: C.text, style: 'Bold', width: W - 54, align: 'RIGHT' });
  button(f, 34, 344, 200, '✓  Berildi', false, 42);
  button(f, 244, 344, 112, 'Bekor', true, 42);

  label(f, 20, 428, 'Tarix', { size: 18, color: C.text, style: 'Bold' });
  const hist = [
    ['Diamond mayka × 1', 'Shogird 2 • 14-sentabr'],
    ['Kreatin 300 g × 1', 'Shogird 1 • 9-sentabr'],
  ];
  for (let i = 0; i < hist.length; i++) {
    const y = 458 + i * 84;
    card(f, 20, y, W - 40, 72);
    thumb(f, 34, y + 18, 36);
    label(f, 82, y + 18, hist[i][0], { size: 13, color: C.text, style: 'Semi Bold' });
    label(f, 82, y + 40, hist[i][1], { size: 11, color: C.textMuted });
    pill(f, W - 100, y + 26, 'Berildi', C.success);
  }

  label(f, 20, 640, 'Qoldiq tovar berilganda avtomatik kamayadi.', { size: 11, color: C.textFaint });

  navbar(f, ['Mijozlar', 'Zal', 'Rejalar', 'Ovqat', 'Do‘kon'], 4);
  return f;
}

function screenPlanEditor(x) {
  const f = frame('Reja muharriri — trener', x, 0, W, H);
  appbar(f, 'Rejani tahrirlash', 'Ozish • 1 haftalik ratsion', '✓  Saqlash');

  statRow(f, 86, [['CHOR · KALORIYA', '1498'], ['OQSIL', '125 g']]);

  card(f, 20, 166, W - 40, 72);
  label(f, 36, 182, 'Har kunga alohida menyu', { size: 13.5, color: C.text, style: 'Semi Bold' });
  label(f, 36, 204, '7 xil menyu — shogirdda o‘sha kunniki', { size: 11, color: C.textMuted });
  rect(f, W - 84, 184, 48, 26, { radius: 13, fill: C.accent, name: 'Tugmacha' });
  ellipse(f, W - 62, 187, 20, { fill: C.onAccent, name: 'Tugmacha nuqtasi' });

  let cx = 20;
  const dd = [['Du', false], ['Se', false], ['Chor', true], ['Pay', false],
    ['Ju', false], ['Sha', false], ['Yak', false]];
  for (let i = 0; i < dd.length; i++) {
    cx += chip(f, cx, 254, dd[i][0], dd[i][1]) + 6;
  }

  label(f, 20, 298, 'Chorshanba menyusi', { size: 16, color: C.text, style: 'Bold' });
  label(f, 20, 302, 'Hamma kunga', { size: 11.5, color: C.accent, style: 'Semi Bold', width: W - 40, align: 'RIGHT' });

  rect(f, 20, 326, W - 40, 100, { radius: 12, fill: '#4A3B2C', name: 'Kun rasmi' });
  rect(f, 20, 394, W - 40, 32, { radius: 12, fill: '#000000', opacity: 0.45, name: 'Rasm ustidagi qora' });
  label(f, 32, 402, 'Shogird shu rasmni ko‘radi', { size: 11, color: C.white, style: 'Medium' });

  label(f, 20, 444, 'Ovqatlanish mahallari (5)', { size: 15, color: C.text, style: 'Bold' });

  card(f, 20, 470, W - 40, 150);
  rect(f, 34, 486, 54, 28, { radius: 8, fill: C.accent, opacity: 0.14, name: 'Vaqt' });
  label(f, 34, 493, '08:00', { size: 12, color: C.accent, style: 'Bold', width: 54, align: 'CENTER' });
  label(f, 100, 486, 'Nonushta', { size: 13.5, color: C.text, style: 'Semi Bold' });
  label(f, 100, 506, '377 kkal · 34 g oqsil', { size: 11, color: C.textMuted });
  const items = [
    ['Tvorog 5% — sirniki uchun', '150 g', '182 kkal'],
    ['Tuxum, butun (1 dona)', '50 g', '78 kkal'],
    ['Un', '20 g', '68 kkal'],
  ];
  for (let i = 0; i < items.length; i++) {
    const y = 538 + i * 24;
    rect(f, 34, y, 16, 16, { radius: 5, fill: C.cardHigh, name: 'Mahsulot rasmi' });
    label(f, 58, y, items[i][0], { size: 11.5, color: C.text });
    label(f, 20, y, items[i][1], { size: 11.5, color: C.text, style: 'Semi Bold', width: W - 116, align: 'RIGHT' });
    label(f, 20, y, items[i][2], { size: 11, color: C.textMuted, width: W - 54, align: 'RIGHT' });
  }

  card(f, 20, 636, W - 40, 72);
  rect(f, 34, 652, 54, 28, { radius: 8, fill: C.accent, opacity: 0.14, name: 'Vaqt' });
  label(f, 34, 659, '11:00', { size: 12, color: C.accent, style: 'Bold', width: 54, align: 'CENTER' });
  label(f, 100, 652, 'Perekus', { size: 13.5, color: C.text, style: 'Semi Bold' });
  label(f, 100, 672, '156 kkal · 1 g oqsil', { size: 11, color: C.textMuted });

  button(f, W - 20 - 158, 716, 158, '+  Mahal qo‘shish', false, 44);

  navbar(f, ['Mijozlar', 'Zal', 'Rejalar', 'Ovqat', 'Do‘kon'], 2);
  return f;
}

// ---------- dizayn tizimi taxtasi ----------

function styleBoard(x) {
  const f = frame('Dizayn tizimi', x, 0, 900, 640, C.bg);
  label(f, 40, 40, 'Diamond — dizayn tizimi', { size: 28, color: C.text, style: 'Bold' });
  label(f, 40, 78, 'Ranglar, komponentlar va oraliqlar. Qiymatlar ilova kodi bilan bir xil.', {
    size: 13, color: C.textMuted,
  });

  const keys = Object.keys(C);
  for (let i = 0; i < keys.length; i++) {
    const cxx = 40 + (i % 7) * 120;
    const cyy = 116 + Math.floor(i / 7) * 104;
    rect(f, cxx, cyy, 104, 56, { radius: 10, fill: C[keys[i]], name: keys[i] });
    label(f, cxx, cyy + 62, C[keys[i]], { size: 11.5, color: C.text, style: 'Semi Bold' });
    label(f, cxx, cyy + 78, keys[i], { size: 10.5, color: C.textMuted });
  }

  label(f, 40, 344, 'Komponentlar', { size: 20, color: C.text, style: 'Bold' });
  card(f, 40, 376, 250, 92);
  thumb(f, 56, 396, 40);
  label(f, 108, 400, 'Karta (BentoTile)', { size: 14, color: C.text, style: 'Bold' });
  label(f, 108, 422, 'shaffof + ingichka qirra', { size: 11, color: C.textMuted });
  label(f, 108, 440, 'radius 12 · ichki bo‘shliq 14', { size: 11, color: C.textFaint });

  card(f, 310, 376, 250, 92, true);
  label(f, 326, 396, 'Karta (urg‘u)', { size: 14, color: C.text, style: 'Bold' });
  label(f, 326, 418, 'olmos ko‘ki bilan bo‘yalgan', { size: 11, color: C.textMuted });
  label(f, 326, 440, 'urg‘u bloklarida', { size: 11, color: C.textFaint });

  let px = 590;
  const pills = [['Reja bor', C.success], ['Kutilmoqda', C.warning], ['Tugagan', C.danger]];
  for (let i = 0; i < pills.length; i++) {
    px += pill(f, px, 382, pills[i][0], pills[i][1]) + 8;
  }
  button(f, 590, 420, 140, 'Asosiy tugma');
  button(f, 744, 420, 110, 'Bekor', true);

  label(f, 40, 500, 'Oraliqlar', { size: 20, color: C.text, style: 'Bold' });
  const sp = [['xs', 4], ['sm', 8], ['md', 14], ['lg', 20], ['xl', 28], ['xxl', 40]];
  for (let i = 0; i < sp.length; i++) {
    const sx = 40 + i * 130;
    rect(f, sx, 532, sp[i][1], 14, { radius: 3, fill: C.accent, opacity: 0.6, name: sp[i][0] });
    label(f, sx, 556, sp[i][0] + ' · ' + sp[i][1] + ' px', { size: 11.5, color: C.textMuted });
  }

  label(f, 40, 596, 'Ramka: 390 × 844 · yon chet 20 px · bosiladigan element ≥ 52 px', {
    size: 11.5, color: C.textFaint,
  });
  return f;
}

// ---------- ishga tushirish ----------

async function main() {
  const styles = ['Regular', 'Medium', 'Semi Bold', 'Bold'];
  for (let i = 0; i < styles.length; i++) {
    await figma.loadFontAsync({ family: 'Inter', style: styles[i] });
  }

  createStyles();

  const made = [];
  made.push(styleBoard(0));
  const screens = [screenBugun, screenZal, screenShop, screenClients, screenShopAdmin, screenPlanEditor];
  for (let i = 0; i < screens.length; i++) {
    made.push(screens[i](1000 + i * 460));
  }

  figma.currentPage.selection = made;
  figma.viewport.scrollAndZoomIntoView(made);
  figma.closePlugin('Diamond: ' + made.length + ' ta ramka va ' +
    Object.keys(C).length + ' ta rang stili yaratildi.');
}

main();
