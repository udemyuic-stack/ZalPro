// Brauzerni buyruq qatoridan boshqarish (ilovani tekshirish uchun).
// Chrome ni avval shunday ochish kerak:
//   chrome.exe --headless=new --remote-debugging-port=9222 --window-size=390,844 ^
//              --user-data-dir=<vaqtinchalik papka> about:blank
//
// Keyin:
//   node tools/brauzer/cdp.mjs goto http://127.0.0.1:8099/
//   node tools/brauzer/cdp.mjs shot ekran.png
//   node tools/brauzer/cdp.mjs click 195 412
//   node tools/brauzer/cdp.mjs type "matn"
//   node tools/brauzer/cdp.mjs key Enter
//   node tools/brauzer/cdp.mjs scroll 195 500 400
//   node tools/brauzer/cdp.mjs eval "document.title"
//   node tools/brauzer/cdp.mjs yop        — faqat shu brauzerni yopadi
import { writeFileSync } from 'node:fs';

const [cmd, ...args] = process.argv.slice(2);
const PORT = process.env.PORT ?? '9222';
const targets = await (await fetch(`http://127.0.0.1:${PORT}/json`)).json();
const page = targets.find((t) => t.type === 'page');
const ws = new WebSocket(page.webSocketDebuggerUrl);
await new Promise((r) => ws.addEventListener('open', r, { once: true }));
let id = 0;
const pending = new Map();
ws.addEventListener('message', (e) => {
  const m = JSON.parse(e.data);
  if (m.id && pending.has(m.id)) {
    pending.get(m.id)(m);
    pending.delete(m.id);
  }
});
const send = (method, params = {}) =>
  new Promise((resolve) => {
    const i = ++id;
    pending.set(i, resolve);
    ws.send(JSON.stringify({ id: i, method, params }));
  });
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
const mouse = (type, x, y) =>
  send('Input.dispatchMouseEvent', { type, x, y, button: 'left', clickCount: 1 });

switch (cmd) {
  case 'goto':
    await send('Emulation.setDeviceMetricsOverride', {
      width: Number(process.env.W ?? 390), height: Number(process.env.H ?? 844),
      deviceScaleFactor: 1, mobile: false,
    });
    await send('Network.enable');
    await send('Network.clearBrowserCache');
    await send('Network.setCacheDisabled', { cacheDisabled: true });
    await send('Page.navigate', { url: args[0] });
    break;
  case 'shot': {
    const r = await send('Page.captureScreenshot', { format: 'png' });
    writeFileSync(args[0], Buffer.from(r.result.data, 'base64'));
    break;
  }
  case 'click': {
    const [x, y] = args.map(Number);
    await mouse('mouseMoved', x, y);
    await mouse('mousePressed', x, y);
    await sleep(60);
    await mouse('mouseReleased', x, y);
    break;
  }
  case 'type':
    await send('Input.insertText', { text: args.join(' ') });
    break;
  case 'key': {
    const k = args[0];
    const codes = { Enter: 13, Tab: 9, Backspace: 8, Escape: 27 };
    for (const type of ['keyDown', 'keyUp']) {
      await send('Input.dispatchKeyEvent', {
        type, key: k, code: k, windowsVirtualKeyCode: codes[k], nativeVirtualKeyCode: codes[k],
      });
    }
    break;
  }
  case 'scroll': {
    const [x, y, dy] = args.map(Number);
    await send('Input.dispatchMouseEvent', { type: 'mouseWheel', x, y, deltaX: 0, deltaY: dy });
    break;
  }
  // Faqat shu tekshiruv brauzerini yopadi (9222-portdagisini).
  // DIQQAT: hech qachon `taskkill /IM chrome.exe` ishlatmang — u foydalanuvchining
  // ochiq Chrome oynalarini ham yopib yuboradi.
  case 'yop':
    await send('Browser.close');
    process.exit(0);
    break;
  case 'eval': {
    const r = await send('Runtime.evaluate', {
      expression: args.join(' '), returnByValue: true, awaitPromise: true,
    });
    console.log(JSON.stringify(r.result?.result?.value ?? r.result));
    break;
  }
}
await sleep(Number(process.env.WAIT ?? 1500));
ws.close();
