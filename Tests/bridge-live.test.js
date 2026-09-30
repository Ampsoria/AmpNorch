// Run against the built app. Two protocol clients verify native routing and real WebSocket IO.
// This does not claim validation of a particular website's DOM or installed extension.
const { execFileSync } = require('node:child_process');
const assert = require('node:assert/strict');
const token = execFileSync('/usr/bin/defaults', ['read', 'com.ampsoria.AmpNotch', 'browserPairingToken'], { encoding: 'utf8' }).trim();
const opened = [];
function connect(secret) {
  return new Promise((resolve, reject) => {
    const ws = new WebSocket('ws://127.0.0.1:9876'); opened.push(ws);
    const timer = setTimeout(() => reject(Error('Handshake timed out')), 5000);
    ws.onopen = () => ws.send(JSON.stringify({ type: 'hello', token: secret }));
    ws.onmessage = ({ data }) => {
      if (JSON.parse(data).type === 'authenticated') { clearTimeout(timer); resolve(ws); }
    };
    ws.onclose = () => {
      clearTimeout(timer);
      if (secret === 'invalid-test-token') resolve(null); else reject(Error('Authentication rejected'));
    };
    ws.onerror = reject;
  });
}
const send = (ws, data) => ws.send(JSON.stringify(data));
const payload = (name, playing) => ({ type: 'track_update', sourceID: 'tab', title: name,
  artist: 'Local transport test', source: 'Protocol test', mediaID: name, duration: 180, position: 10,
  isPlaying: playing, canSeek: true, canSkip: true });
(async () => {
  assert.equal(await connect('invalid-test-token'), null);
  const a = await connect(token), b = await connect(token);
  let commands = 0;
  const timer = setTimeout(() => { throw Error('Timed out waiting for notch playback command'); }, 120000);
  let keepAlive;
  const dataA = payload('[Transport test] Inactive tab', false);
  const dataB = payload('[Transport test] Active tab', true);
  for (const ws of [a,b]) {
    ws.onmessage = ({ data }) => {
      const message = JSON.parse(data);
      if (message.type === 'command') {
        assert.equal(ws, b, 'Command was incorrectly broadcast/routed to the inactive client');
        assert.equal(message.action, 'togglePlayPause');
        dataB.isPlaying = !dataB.isPlaying;
        send(b, dataB);
        send(b, { type: 'ack', requestID: message.requestID, ok: true });
        commands++;
        clearTimeout(timer); clearInterval(keepAlive);
        console.log('PASS: rejected unauthenticated peer, selected active browser source, routed command to only its owner, received acknowledgement');
        setTimeout(() => { for (const ws of opened) ws.close(); }, 500);
      }
    };
  }
  send(a, dataA); send(b, dataB);
  keepAlive = setInterval(() => { send(a, dataA); send(b, dataB); }, 1000);
  console.log('READY: click Pause playback in AmpNotch on [Transport test] Active tab');

})().catch(error => { console.error(error); for (const ws of opened) ws.close(); process.exitCode = 1; });
