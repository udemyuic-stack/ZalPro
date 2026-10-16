// bore.pub protokoli bo'yicha TCP tunnel mijozi (rasmiy bore-cli o'rniga — GitHub yuklash bloklangan).
// Lokal portni internetga ochadi: bore.pub:<remotePort> -> localhost:<localPort>. Akkaunt kerak emas.
// Usage: node tools/bore-lite.mjs <localPort> <remotePort> [server=bore.pub]
//
// Protokol (ekzhang/bore): control ulanish :7835, JSON xabarlar '\0' bilan ajratiladi.
//   mijoz -> {"Hello": port}        server -> {"Hello": port} | {"Error": "..."}
//   server -> "Heartbeat"            (e'tiborsiz)
//   server -> {"Connection": uuid}  mijoz yangi :7835 ulanish ochib {"Accept": uuid} yuboradi,
//                                    keyin baytlar lokal port bilan to'g'ridan-to'g'ri almashadi.
import net from 'node:net';

const [, , localPort, remotePort = '0', server = 'bore.pub'] = process.argv;
const CONTROL_PORT = 7835;

if (!localPort) {
  console.log('Usage: node tools/bore-lite.mjs <localPort> <remotePort> [server]');
  process.exit(2);
}

const send = (sock, msg) => sock.write(JSON.stringify(msg) + '\0');

function onMessages(sock, handler) {
  let buf = '';
  sock.on('data', (chunk) => {
    buf += chunk.toString('utf8');
    let i;
    while ((i = buf.indexOf('\0')) >= 0) {
      const frame = buf.slice(0, i);
      buf = buf.slice(i + 1);
      if (frame) handler(JSON.parse(frame));
    }
  });
}

function accept(id) {
  const remote = net.connect(CONTROL_PORT, server, () => {
    send(remote, { Accept: id });
    const local = net.connect(Number(localPort), '127.0.0.1');
    const close = () => { remote.destroy(); local.destroy(); };
    remote.pipe(local);
    local.pipe(remote);
    for (const s of [remote, local]) { s.on('error', close); s.on('close', close); }
  });
  remote.on('error', () => remote.destroy());
}

function start() {
  const ctl = net.connect(CONTROL_PORT, server, () => send(ctl, { Hello: Number(remotePort) }));
  ctl.setKeepAlive(true, 10000);
  onMessages(ctl, (m) => {
    if (m && m.Hello !== undefined) {
      console.log(`[OK] ${server}:${m.Hello} -> localhost:${localPort}`);
    } else if (m && m.Error) {
      console.log(`[X] server: ${m.Error}`);
      process.exit(1);
    } else if (m && m.Connection) {
      accept(m.Connection);
    }
  });
  ctl.on('error', (e) => console.log(`control xato: ${e.message}`));
  // uzilsa — o'sha port bilan qayta ulanadi (APK portlari o'zgarmasligi uchun)
  ctl.on('close', () => { console.log('control uzildi, 3 s dan keyin qayta ulanish...'); setTimeout(start, 3000); });
}

start();
