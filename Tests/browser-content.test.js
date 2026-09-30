const { readFileSync } = require('node:fs');
const vm = require('node:vm');
const assert = require('node:assert/strict');
const sent = [];
let receiver;
const events = {};
const media = { isConnected: true, readyState: 4, ended: false, paused: false,
  duration: 120, currentTime: 5, currentSrc: 'https://example.test/music.mp3', seekable: { length: 1 },
  addEventListener(name, callback) { events[name] = callback; },
  async play() { this.paused = false; }, pause() { this.paused = true; } };
const context = vm.createContext({
  chrome: { runtime: { sendMessage: async data => { sent.push(data); }, onMessage: { addListener: cb => receiver = cb } } },
  document: { title: 'Real page title', querySelectorAll: () => [media], querySelector: () => null },
  location: { hostname: 'example.test', href: 'https://example.test/player' },
  navigator: { mediaSession: { metadata: { title: 'Song & punctuation ::: intact', artist: 'Artist' } } },
  window: { addEventListener() {} }, URL, Date, WeakSet, setInterval() {}
});
vm.runInContext(readFileSync('Extension/AmpsoriaConnected/content.js', 'utf8'), context);
const command = msg => new Promise(resolve => receiver({ type: 'command', ...msg }, {}, resolve));
(async () => {
  assert.equal(sent.at(-1).title, 'Song & punctuation ::: intact');
  assert.equal(sent.at(-1).canSkip, false);
  assert.equal((await command({ action: 'togglePlayPause' })).ok, true);
  assert.equal(media.paused, true);
  assert.equal(sent.at(-1).isPlaying, false);
  await command({ action: 'togglePlayPause' });
  assert.equal(media.paused, false);
  await command({ action: 'seek', time: 500 });
  assert.equal(media.currentTime, 120);
  assert.equal((await command({ action: 'next' })).ok, false);
  media.duration = Infinity;
  assert.equal((await command({ action: 'seek', time: 10 })).ok, false);
  media.ended = true; events.ended();
  assert.equal(sent.at(-1).type, 'remove');
  console.log('PASS: browser content commands affect media, acknowledge errors, clamp seeks and remove ended media');
})().catch(error => { console.error(error); process.exitCode = 1; });
