// The extension owns the socket, so page CSP cannot break the bridge.
let socket, reconnect, heartbeat, authenticated = false;
const sources = new Map();
async function connect() {
  clearTimeout(reconnect);
  const { token } = await chrome.storage.local.get('token');
  if (!token || socket?.readyState === WebSocket.OPEN || socket?.readyState === WebSocket.CONNECTING) return;
  const current = new WebSocket('ws://127.0.0.1:9876');
  socket = current;
  current.onopen = () => current.send(JSON.stringify({ type: 'hello', token }));
  current.onmessage = async ({ data }) => {
    if (socket !== current) return;
    let msg;
    try { msg = JSON.parse(data); } catch { return; }
    if (msg.type === 'authenticated') {
      authenticated = true;
      for (const payload of sources.values()) send(payload);
      heartbeat = setInterval(() => send({ type: 'heartbeat' }), 20000);
    }
    if (msg.type === 'command' && authenticated) {
      const source = sources.get(msg.sourceID);
      let result;
      try {
        if (!source) throw new Error('Media tab closed.');
        if (msg.action === 'activate') {
          await chrome.tabs.update(source.tabID, { active: true });
          const tab = await chrome.tabs.get(source.tabID);
          await chrome.windows.update(tab.windowId, { focused: true });
          result = { ok: true };
        } else result = await chrome.tabs.sendMessage(source.tabID, msg, { frameId: 0 });
      } catch (error) { result = { ok: false, error: error.message }; }
      send({ type: 'ack', requestID: msg.requestID, ...result });
    }
  };
  current.onclose = () => { if (socket !== current) return; authenticated = false; clearInterval(heartbeat); reconnect = setTimeout(connect, 3000); };
  current.onerror = () => current.close();
}
function send(payload) {
  if (authenticated && socket?.readyState === WebSocket.OPEN) socket.send(JSON.stringify(payload));
}
chrome.runtime.onMessage.addListener((message, sender, respond) => {
  if (message.type === 'status') { respond({ connected: authenticated }); return; }
  if (message.type === 'reconnect') { socket?.close(); connect(); respond({ ok: true }); return; }
  if (!sender.tab || sender.frameId !== 0) return;
  const sourceID = String(sender.tab.id);
  if (message.type === 'track_update') {
    const payload = { ...message, sourceID, tabID: sender.tab.id };
    sources.set(sourceID, payload); send(payload);
  } else if (message.type === 'remove') {
    sources.delete(sourceID); send({ type: 'remove', sourceID });
  }
  respond({ ok: true });
});
chrome.tabs.onRemoved.addListener(id => { sources.delete(String(id)); send({ type: 'remove', sourceID: String(id) }); });
chrome.runtime.onStartup.addListener(connect);
chrome.runtime.onInstalled.addListener(connect);
chrome.alarms.create('bridge-reconnect', { periodInMinutes: 0.5 });
chrome.alarms.onAlarm.addListener(() => { if (!authenticated) connect(); });
connect();
