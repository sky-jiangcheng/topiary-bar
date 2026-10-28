# Topiary: macOS Menu Bar Manager

<p align="center">
  <img src="docs/assets/icon-256.png" alt="Topiary App Icon" width="128" height="128" />
</p>

<p align="center">
  <strong>Take full control of your macOS menu bar.</strong><br>
  See, launch, quit, and pin every menu bar app running on your Mac.
</p>

<p align="center">
  <a href="https://sky-jiangcheng.github.io/topiary-bar/"><strong>Official Website</strong></a> ·
  <a href="https://github.com/sky-jiangcheng/topiary-bar/releases/latest"><strong>Download DMG</strong></a> ·
  <a href="#quick-start"><strong>Quick Start</strong></a> ·
  <a href="README.zh-CN.md"><strong>简体中文</strong></a>
</p>

<p align="center">
  <a href="https://github.com/sky-jiangcheng/topiary-bar/releases"><img src="https://img.shields.io/github/v/release/sky-jiangcheng/topiary-bar?label=release&color=2E7D52" alt="Release"></a>
  <a href="https://github.com/sky-jiangcheng/topiary-bar/actions/workflows/test.yml"><img src="https://github.com/sky-jiangcheng/topiary-bar/actions/workflows/test.yml/badge.svg" alt="Test Status"></a>
  <a href="LICENSE"><img src="https://img.shields.io/badge/license-MIT-blue.svg" alt="License: MIT"></a>
  <a href="https://swift.org"><img src="https://img.shields.io/badge/Swift-6.0-orange?logo=swift&logoColor=white" alt="Swift 6.0"></a>
  <a href="https://www.apple.com/macos/"><img src="https://img.shields.io/badge/macOS-14%2B-black?logo=apple&logoColor=white" alt="macOS 14+"></a>
  <a href="https://sky-jiangcheng.github.io/topiary-bar/privacy/"><img src="https://img.shields.io/badge/Privacy-100%25%20Local-success" alt="Privacy"></a>
</p>

---

## 💡 Why Topiary?

Modern macOS status bars get overcrowded quickly. Background helper tools, sync daemons, and menu bar accessories hide behind notches, consume memory, and offer no standard way to inspect or quit them.

**Topiary** solves this cleanly:
- 🛡️ **Zero Tracking, Zero Permissions**: No Accessibility permissions required, no telemetry, no network calls. 100% of data stays on your device.
- 📌 **Resident Menu Bar Pinning**: Pin your critical apps directly to the system menu bar so they are always visible and actionable with one click.
- 🛟 **Notch Self-Healing**: Automatically alerts you when macOS swallows icons behind the camera notch so background agents never get lost.
- ⚡ **Lightweight & Native**: Built with Swift 6 and pure SwiftUI / AppKit with an instant memory footprint overview.

---

## ✨ Features at a Glance

### 📌 Menu Bar Residency
* **Pin to Menu Bar**: Pinned apps live directly in the menu bar as resident status items. Left-click to bring to front; right-click to open, unpin, or terminate.
* **Persistent Order**: Resident order survives reboots and app launches seamlessly.

### 🚦 Smart App Management
* **Auto Classification**: Automatically distinguishes between pure Status Bar accessories (`activationPolicy == .accessory`) and standard Dock applications.
* **Accessory Wake-Up**: Reliably foregrounds accessory-only apps using `openApplication(at:configuration:)` where macOS normally rejects `activate()`.
* **Graceful Termination**: Terminate unresponsive background apps gracefully, escalating to force kill only if needed (notarized Developer ID build).
* **Instant Search & Filter**: Rapidly filter apps by name, bundle identifier, or app type across both the popover and main window.

### 🎨 Clean macOS Design
* **Dual Interface**: Fast-access Popover for quick glance and stats + Full Main Window for management and settings.
* **Live Memory Monitor**: Real-time memory bar and per-process memory footprints.
* **Global Hotkey**: Press <kbd>⌃</kbd> <kbd>⌥</kbd> <kbd>M</kbd> anywhere to summon the manager without reaching for the mouse.
* **Native Customization**: Built-in light/dark appearance support, customizable status bar glyphs, and 5 native languages (English, 简体中文, 日本語, Deutsch, Español).

---

## 🚀 Quick Start

### Installation

#### Option 1: Direct Download (Recommended)
1. Download the latest `Topiary-<version>.dmg` from [GitHub Releases](https://github.com/sky-jiangcheng/topiary-bar/releases/latest).
2. Open the disk image and drag **Topiary.app** into your **Applications** folder.
3. Launch Topiary. *(Notarized with Apple Developer ID; contains full termination capabilities).*

#### Option 2: Mac App Store
Also available on the Mac App Store (sandboxed, operates without direct process termination per App Store Review Guidelines).

---

## 🛠️ Build from Source

### Prerequisites
* macOS 14.0 or newer
* Xcode 16.0+ (Swift 6.0 toolchain)

```bash
# Clone the repository
git clone https://github.com/sky-jiangcheng/topiary-bar.git
cd topiary-bar

# Build, sign (ad-hoc), and run locally
./script/build_and_run.sh

# Or build with Swift PM directly
swift build
```

---

## 🔐 Privacy & Security

Topiary is designed with privacy as a foundational principle:
* **No network capabilities configured**: The app makes zero external network connections.
* **No analytics or diagnostic telemetry**: Nothing is tracked or logged remotely.
* **No sensitive permissions**: Works entirely using standard public macOS APIs (`NSWorkspace`, `NSRunningApplication`) without requiring Accessibility or Full Disk Access.
* Shipped with an official Apple Privacy Manifest (`PrivacyInfo.xcprivacy`).

Read our complete [Privacy Policy](https://sky-jiangcheng.github.io/topiary-bar/privacy/).

---

## 🤝 Contributing

Contributions make the open-source community an inspiring place to learn, inspire, and create. Any contributions you make are **greatly appreciated**!

1. Fork the Project
2. Create your Feature Branch (`git checkout -b feature/AmazingFeature`)
3. Commit your Changes (`git commit -m 'feat: add some AmazingFeature'`)
4. Push to the Branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

If you enjoy using Topiary, please consider giving it a ⭐️ on GitHub to help others discover it!

---

## 📄 License & Commercial Terms

This project is licensed under the **MIT License**.

```text
Copyright (c) 2026 sky-jiangcheng

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software...
```

### What does this mean?
- ✅ **Free for Personal & Commercial Use**: You can run, study, and integrate this software in proprietary or open-source projects.
- ✅ **Modification & Distribution**: You can modify, fork, and distribute copies under the same permissive terms.
- ℹ️ **Notice Requirement**: Retain the original copyright notice and permission block in distributions.
- 🛡️ **Warranty**: The software is provided "as is", without warranty of any kind.

See the full text in the [`LICENSE`](LICENSE) file.

---

<p align="center">
  Crafted with ❤️ for the macOS community · <a href="https://sky-jiangcheng.github.io/topiary-bar/">Visit Website</a>
</p>
