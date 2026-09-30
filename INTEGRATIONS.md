# Integration behavior

## First-run setup and permissions

The welcome window opens once per user profile and can be reopened from Settings or the menu bar. Closing or choosing Done defers setup without treating permissions as granted. Every feature can be configured independently. Existing granted permissions/preferences are preserved; they are never reset for testing.

Native media polling checks Automation access with `AEDeterminePermissionToAutomateTarget(..., false)` on a worker queue (cached for five seconds). It does not trigger prompts. The explicit Connect button opens the selected player and requests permission with `true`, also off the main thread. Bluetooth scanning is off by default for an undetermined authorization state; Classic Bluetooth monitoring waits until access is authorized. Users who previously granted Bluetooth retain the old enabled default. Microphone access is requested only by the setup action or song recognition. The waveform enable action starts the existing Core Audio tap request path; its UI reports capture status, not an invented permission check.

Validation on the development Mac: the first-launch window appeared automatically; Apple Music reported its existing allowed access, unavailable Spotify was identified as not installed, microphone access remained not requested, and the waveform continued receiving audio. Existing permissions were not reset, so brand-new macOS consent dialogs still need verification on a fresh user profile or another Mac.

Each permission section links to macOS Privacy & Security for previously denied access. System audio links to Screen & System Audio Recording, with instructions to use System Audio Recording Only. No Accessibility, Full Disk Access or broad screen-capture permission is requested. Browser extension installation remains a manual step documented in the included guide.

Apple APIs: https://developer.apple.com/documentation/coreservices/3025784-aedeterminepermissiontoautomatet (see local SDK AppleEvents.h for threading/target-running requirements); https://developer.apple.com/documentation/bundleresources/information-property-list/nsaudiocaptureusagedescription

## Music and browser

Native players are polled through Apple Events on a serial queue, with timeouts and displayed Automation errors. Artwork comes from the current player's metadata. Playback selection prefers active players; repeating heartbeats from a paused source cannot steal focus. Manual selection is available in the source menu.

The Chromium MV3 extension uses a background WebSocket connection, a per-install pairing token, source IDs, request IDs and acknowledgements. Commands target one client and tab. Disconnected/stale sources are removed. HTML media controls work only where the site exposes them; cross-origin embedded players and protected/custom site controls are not guaranteed. The extension is not installed automatically.

## Live waveform

Core Audio process taps capture system output locally (macOS 14.2+). A 1024-sample Hann-window DFT measures six frequency bands. Bars use the current artwork's dominant muted color. Pausing playback returns them to dots. Reduce Motion suppresses motion. No waveform is simulated while access is disabled. The tap measures all system output, so other audible apps can affect the bars; protected content may withhold samples. Audio is neither stored nor uploaded. Permission is controlled by macOS in Privacy & Security → Screen & System Audio Recording → System Audio Recording Only.

Apple API: https://developer.apple.com/documentation/CoreAudio/capturing-system-audio-with-core-audio-taps

Hardware creation/start/stop runs on a serial background queue. Slow Core Audio driver or permission responses must not block AppKit. Main-thread session generations reject stale callbacks after stop/restart; DSP buffers remain confined to the sample queue. Verified the updated app responds to Settings and preview playback actions while the audio meter reports real input.

## AirPods

IOBluetooth connection notifications and reconciliation detect real Mac connections without a generation-specific allowlist. Renamed devices may show a generic headset icon.

A separate CoreBluetooth scanner decodes Apple's proximity-pairing manufacturer advertisements for nearby case-open events. These broadcasts are not a public compatibility contract or proof of ownership. The HUD says nearby, rather than claiming that an unpaired device connected. Nearby people's devices may appear. RSSI filtering and lid-counter deduplication limit repeats. Model IDs include known AirPods/Pro/Max variants; Max has no charging-case lid event. Unrecognized future IDs use a generic model. Battery values, when present, are coarse ten-percent estimates; absent values remain absent. Earbud orientation is not guessed as left/right.

Physical case-opening behavior has not been validated across AirPods generations. Advertising, firmware, Bluetooth permission and distance affect availability. Do not advertise universal case-open support until tested with hardware.

Wire-format references used for the decoder:
- https://github.com/furiousMAC/continuity/blob/master/messages/proximity_pairing.md
- https://github.com/fischejo/airpods-notify/blob/master/doc/proximity_protocol.md
- https://github.com/will-ch-h/librepods-windowsbridge/blob/main/Proximity%20Pairing%20Message.md

## Other integrations

LRCLIB receives song metadata for lyric lookup; weather uses the selected city's coordinates. Failed lookups show unavailable. ShazamKit requires microphone permission and a real recognition result, which is presented separately from current playback. Neither its hardware recognition nor every browser site has been verified in this session.

## Lock Screen music

The optional Lock Screen overlay shows the current track's artwork, playback controls and a timestamp-driven scrolling lyric viewport. Persistent rows scroll with a 0.65-second ease-in/out transition when the active timestamp changes; their wrapping and layout heights remain fixed during emphasis changes. Reduce Motion disables the transition. Track changes reset the viewport immediately. The media card uses untinted native clear glass with adjustable material opacity (20–100%, default 62%). Notch and Lock Screen have independent persisted settings and a shared restore-defaults action; existing surfaces update in place. Classic Black and Reduce Transparency remain opaque; labels and controls retain full opacity. Reduce Transparency retains an opaque accessible fallback. It uses two nonactivating panels on the built-in display (or the first display), below the system clock and above the sign-in area. The lyrics panel passes clicks through. Panels cannot become key or main windows. The system wallpaper is preserved; the reference image is not used as an asset. Plain lyrics without timestamps are not presented as synced lyrics.

The Mac remains locked by macOS. AmpNotch does not supply a lock screen, collect passwords, intercept keyboard input, install authorization plug-ins, alter login policy, or prevent sleep. Its media controls expose only playback actions. Song metadata is intentionally visible while locked when this option is enabled. StandBy remains a separate, unlocked app view.

Distributed lock notifications trigger a bounded reconciliation with the current session dictionary, not perpetual lock polling. Panels require a locked session on the console, an awake display, an enabled preference and current media. Unlock, screen sleep, session changes, disabling the feature and quitting remove the panels and destroy their private space. Screen changes rebuild the layout. Hidden panels retain no SwiftUI rendering tree.

Implementation uses dynamically resolved, undocumented SkyLight space functions. Missing symbols or failed membership verification prevent presentation; there is no fallback that pretends the unlocked desktop is locked. Compatibility can change after macOS updates. This is not a WidgetKit Lock Screen extension and does not work at FileVault startup before the app runs.

Validation: build/signature and all regression tests pass on macOS 26.3.1. Geometry tests cover 800×600 through 2560×1440; visibility tests cover all combinations of lock, console, display, media and preference state. A native integration probe creates a space, attaches an invisible panel, reads its membership back from WindowServer and destroys the space successfully. End-to-end appearance, controls and authentication on the actual locked screen still require an interactive lock/unlock test.

API/ABI references:
- https://developer.apple.com/documentation/appkit/nswindow/canbecomevisiblewithoutlogin
- https://github.com/Lakr233/SkyLightWindow/blob/main/Sources/SkyLightWindow/SkyLightOperator.swift
- https://github.com/NUIKit/CGSInternal/blob/master/CGSSpace.h
- https://github.com/koekeishiya/yabai/blob/master/src/misc/extern.h

This release does not implement third-party call answering, global notification mirroring, a replacement secure lock screen, brightness HUD or every Alcove feature. The earlier call/track/equalizer demos were removed instead of being presented as real integrations.
