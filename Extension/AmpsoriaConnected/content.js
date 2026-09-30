(() => {
  let active = null;
  let lastSent = 0;
  const hooked = new WeakSet();
  function skipControl(direction) {
    const host = location.hostname;
    const selectors = host === 'music.youtube.com'
      ? (direction === 'next' ? '.next-button' : '.previous-button')
      : host.endsWith('youtube.com')
        ? (direction === 'next' ? '.ytp-next-button' : '.ytp-prev-button')
        : host === 'open.spotify.com'
          ? `[data-testid="control-button-skip-${direction === 'next' ? 'forward' : 'back'}"]` : '';
    const control = selectors && document.querySelector(selectors);
    return control && !control.disabled && control.getAttribute('aria-disabled') !== 'true' && control.getClientRects().length ? control : null;
  }
  function metadata() {
    let title = document.title, artist = location.hostname, thumbnail = null;
    if (location.hostname === 'music.youtube.com') {
      title = document.querySelector('ytmusic-player-bar .title')?.textContent?.trim() || title;
      artist = document.querySelector('ytmusic-player-bar .byline a')?.textContent?.trim() || artist;
      thumbnail = document.querySelector('ytmusic-player-bar img')?.src;
    } else if (location.hostname.endsWith('youtube.com')) {
      title = document.querySelector('ytd-watch-metadata h1')?.textContent?.trim() || title;
      artist = document.querySelector('ytd-watch-metadata #channel-name a')?.textContent?.trim() || artist;
      const videoID = new URL(location.href).searchParams.get('v');
      if (videoID) thumbnail = `https://i.ytimg.com/vi/${encodeURIComponent(videoID)}/hqdefault.jpg`;
    } else if (navigator.mediaSession?.metadata) {
      const meta = navigator.mediaSession.metadata;
      title = meta.title || title; artist = meta.artist || artist;
      thumbnail = meta.artwork?.[0]?.src;
    }
    return { title, artist, thumbnail };
  }
  function publish() {
    if (!active?.isConnected || active.ended || active.readyState === 0) {
      chrome.runtime.sendMessage({ type: 'remove' }).catch(() => {}); return;
    }
    const duration = Number.isFinite(active.duration) ? active.duration : 0;
    chrome.runtime.sendMessage({ type: 'track_update', ...metadata(),
      mediaID: location.href + ':' + (active.currentSrc || active.src || ''), source: location.hostname,
      duration, position: Number.isFinite(active.currentTime) ? active.currentTime : 0,
      isPlaying: !active.paused && !active.ended, canSeek: duration > 0 && active.seekable.length > 0,
      canSkip: !!skipControl('next') || !!skipControl('previous') }).catch(() => {});
    lastSent = Date.now();
  }
  function scan() {
    const media = [...document.querySelectorAll('video, audio')];
    for (const el of media) {
      if (hooked.has(el)) continue;
      hooked.add(el);
      for (const event of ['play', 'pause', 'seeked', 'loadedmetadata', 'ended', 'emptied']) {
        el.addEventListener(event, () => {
          if (event === 'play' || !active || active === el) { active = el; publish(); }
        });
      }
    }
    if (!active?.isConnected || active.ended) active = media.find(el => !el.paused && !el.ended) || media.find(el => el.readyState > 0);
    if (Date.now() - lastSent > 900) publish();
  }
  chrome.runtime.onMessage.addListener((msg, _, respond) => {
    if (msg.type !== 'command') return;
    (async () => {
      try {
        if (!active?.isConnected) throw new Error('No media on this tab.');
        if (msg.action === 'togglePlayPause') {
          if (active.paused) await active.play(); else active.pause();
        } else if (msg.action === 'seek') {
          if (!Number.isFinite(msg.time) || !Number.isFinite(active.duration) || active.duration <= 0) throw new Error('This stream cannot seek.');
          active.currentTime = Math.min(Math.max(msg.time, 0), active.duration);
        } else if (msg.action === 'next' || msg.action === 'previous') {
          const button = skipControl(msg.action);
          if (!button) throw new Error('This page does not expose that track control.');
          button.click();
        } else throw new Error('Unsupported media command.');
        publish(); respond({ ok: true });
      } catch (error) { respond({ ok: false, error: error.message }); }
    })();
    return true;
  });
  window.addEventListener('pagehide', () => chrome.runtime.sendMessage({ type: 'remove' }).catch(() => {}));
  setInterval(scan, 1000);
  scan();
})();
