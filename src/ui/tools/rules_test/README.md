# firestore.rules testlari

Xavfsizlik qoidalarini **lokal emulyatorda** sinaydi — haqiqiy bazaga tegmaydi.
230 ta holat: rol o'zgartirish, akkaunt o'chirish, trener biriktirish, o'qish
huquqlari, reja/mahsulot yozish, vazn, zal, do'kon (tovar va buyurtma), chat va
ro'yxatdan o'tish.

## Ishga tushirish

Kerak: Node.js va Java 21 (emulyator uchun; PATH da eski Java bo'lsa, `JAVA_HOME` ni Java 21 ga qarating).

```powershell
# 1-terminal: emulyator
firebase emulators:start --only firestore --project demo-rules-test

# 2-terminal: testlar
cd tools\rules_test
npm install          # bir marta
node test.mjs
```

Natija `230 otdi, 0 xato` bo'lishi kerak. `firestore.rules` o'zgartirilsa,
joylashdan **oldin** shu testni ishga tushiring.
