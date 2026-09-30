const field = document.getElementById('token');
chrome.storage.local.get('token').then(({ token }) => { field.value = token || ''; });
document.getElementById('save').onclick = async () => {
  await chrome.storage.local.set({ token: field.value.trim() });
  await chrome.runtime.sendMessage({ type: 'reconnect' });
  refresh();
};
async function refresh() {
  const state = await chrome.runtime.sendMessage({ type: 'status' });
  document.getElementById('status').textContent = state.connected ? 'Connected to AmpNotch' : 'Not connected — check the code and open AmpNotch.';
}
setInterval(refresh, 1000); refresh();
