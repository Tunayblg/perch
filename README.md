<div align="center">

<img src="docs/icon.png" width="128" alt="Perch app icon">

# Perch

**Your notch, put to work.**

A tiny, native macOS app that turns the MacBook notch into a music player, timer, to-do list, voice notepad, file shelf and system monitor — one hover away.

![macOS 14+](https://img.shields.io/badge/macOS-14%2B-black?logo=apple)
![Swift 5.9](https://img.shields.io/badge/Swift-5.9-F05138?logo=swift&logoColor=white)
![No dependencies](https://img.shields.io/badge/dependencies-none-brightgreen)
![License MIT](https://img.shields.io/badge/license-MIT-blue)

**English** · [Türkçe](README.tr.md)

</div>

<!-- Add a demo GIF here once recorded:  ![Perch demo](docs/demo.gif)  -->

---

## Why Perch?

The notch is dead space. Perch gives it a job. Move your mouse to the notch and it opens; move away and it gets out of the way. No Dock icon, no windows, no subscription, no account.

Most notch apps focus on music and a file shelf. Perch adds the **time and planning tools** around them — Pomodoro, timers, to-dos and a **voice note that lands in Apple Notes** — in a single, lightweight (~60 MB RAM) app.

## What makes Perch different

- **Planning, not just playback.** Timers, Pomodoro and to-dos sit in the notch next to your music, so it becomes a small command center instead of a now-playing widget.
- **Voice → Apple Notes → iPhone.** Capture a thought with one global shortcut. It's transcribed on-device and shows up in Notes on every Apple device you own.
- **Private by design.** On-device speech recognition, a memory-only clipboard that skips password-manager copies, no accounts, no telemetry.
- **Free and honest.** No ads, no upgrade banners, no subscription. MIT licensed.
- **Tiny and dependency-free.** About 2,600 lines of Swift and ~60 MB of RAM. Nothing to install but the app.
- **Yours to shape.** Hide and reorder tabs, choose an accent color, swipe between tabs, switch between English and Turkish.
- **Turkish first-class.** Full Turkish interface and on-device Turkish dictation, not an afterthought.

## Features

| | |
|---|---|
| 🎵 **Music** | Spotify & Apple Music: artwork, progress, previous / play / next. While a song plays the closed notch grows to show the cover on one side and a live equalizer on the other. |
| ⏱ **Timers & Pomodoro** | Run several timers at once (5 / 10 / 15 / 30 min) plus a Pomodoro cycle with configurable focus and break lengths. The countdown lives *in* the notch; when time is up the panel pops open, plays a sound and sends a notification. |
| 🎙 **Voice notes** | Press `⌃⌥N` from anywhere, talk, press again. Speech is transcribed **on-device** and saved to **Apple Notes** — so it shows up on your iPhone through iCloud. The audio file stays on your Mac. |
| ✅ **To-do** | Add a task straight from the notch, tick it off. Saved between launches. |
| 📥 **File shelf + AirDrop** | Drag a file toward the notch: the panel opens on the shelf. Park files there to drag out later, or drop one on the AirDrop target to send it right away. |
| 📋 **Clipboard history** | Your last 20 copied texts; click one to copy it again. Memory-only, and copies flagged as secret by password managers are never stored. |
| 📊 **System** | Live CPU and RAM rings, network up/down speed with sparklines, battery and free disk space. Sampled only while the tab is open. |
| ⚙️ **Make it yours** | Hide and reorder tabs, pick an accent color, switch between English and Turkish, launch at login. Two-finger swipe over the notch to change tabs. |

Works on Macs **without** a notch too, as a small floating pill at the top of the screen.

## Install

**From a release**

1. Download `Perch-x.y.z.dmg` from the [Releases](../../releases) page and drag **Perch** to *Applications*.
2. Perch is not notarized (no paid Apple Developer account), so on first launch macOS will warn you. Go to **System Settings → Privacy & Security → Open Anyway**, or run:
   ```bash
   xattr -cr /Applications/Perch.app
   ```
3. Move your mouse to the notch.

There is no Dock icon. Settings and Quit live in the menu bar icon (and in Perch's own Settings tab).

**From source** (Xcode 15+ or the Command Line Tools, Swift 5.9+)

```bash
git clone https://github.com/Tunayblg/perch.git
cd perch
./Scripts/build_app.sh     # → build/Perch.app
./Scripts/make_dmg.sh      # → build/Perch-1.0.0.dmg
open build/Perch.app
```

## Permissions

Perch asks only for what each feature needs, the first time you use it:

| Permission | Used for |
|---|---|
| Automation → Spotify / Music | Reading and controlling playback |
| Automation → Notes | Saving voice notes |
| Microphone | Recording voice notes |
| Speech Recognition | On-device transcription |
| Notifications | Timer and Pomodoro alerts |

## Privacy

- No accounts, no analytics, no telemetry.
- Speech is transcribed **on-device**; audio never leaves your Mac.
- The only network request Perch makes is loading the album cover from Spotify's CDN.
- Clipboard history is kept in memory only and is gone when the app quits.

## Under the hood

Pure Swift, **zero third-party dependencies**, roughly 2,600 lines. A few things that might be interesting to read:

- **Notch geometry** — the real notch size comes from `NSScreen.safeAreaInsets` and `auxiliaryTopLeftArea` / `auxiliaryTopRightArea`, so the shape lines up with the hardware on any model.
- **Overlay window** — a borderless, non-activating `NSPanel` above the menu bar on every Space. It can take keyboard input (for the to-do field) without ever stealing focus from your current app.
- **Hover & drag detection** — global `NSEvent` monitors open the panel on hover and, by inspecting the drag pasteboard, only when a *file* is being dragged (not a window or text).
- **Tab swipe** — scroll-wheel phases are accumulated into a single discrete swipe, with direction following the system's natural-scrolling setting.
- **Media bridge** — AppleScript against Spotify / Music, because the system-wide "now playing" API has been restricted since macOS 15.4.
- **Voice pipeline** — `AVAudioEngine` tap feeding both an AAC file writer and `SFSpeechRecognizer` with on-device recognition required; the result goes to Notes over AppleScript.
- **Global shortcut** — Carbon `RegisterEventHotKey`, which needs no Accessibility permission.
- **System stats** — Mach `host_statistics` for CPU and memory, `getifaddrs` for network counters (with 32-bit wrap handling), IOKit power sources for the battery.
- **Smooth UI** — SwiftUI for the views, a custom animatable notch `Shape`, directional tab transitions.

## Known limitations

- Music is read from Spotify and Apple Music only (no browser / YouTube yet). Apple Music artwork is not shown yet.
- Voice notes add **text** to Notes; Notes' scripting interface does not accept audio attachments.
- The file shelf stores file *paths*; it does not copy files.
- Not notarized, so the first launch needs the *Open Anyway* step.

## Roadmap

**Away Guard (planned, opt-in beta)** — working in a café and stepping away for a minute? Perch will hide your screen when your iPhone or Apple Watch moves out of range: lock it, blur it, or hide notification previews. A privacy helper, off by default, no camera involved.

Also planned: Alarm clock · Lower the music volume during Pomodoro breaks · Calendar (time to next meeting, one-click join) · Reminders · Habit streaks · Browser media support · Apple Music artwork · Quick "ask an AI" box

Details in [docs/PLAN.md](docs/PLAN.md) (Turkish).

## License

[MIT](LICENSE) © Tunayblg

Inspired by [boring.notch](https://github.com/TheBoredTeam/boring.notch), NotchNook and Atoll.
