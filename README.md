<p align="center">
  <img src="ClipboardHistory/Assets.xcassets/AppIcon.appiconset/appicon.png" width="128" alt="ClipX">
</p>

<h1 align="center">ClipX — Copy less, paste more</h1>

<p align="center">
  A lightweight macOS menu bar clipboard manager. Never lose anything you copy again.
</p>

<p align="center">
  <a href="#features">Features</a> &bull;
  <a href="#download">Download</a> &bull;
  <a href="#build">Build</a> &bull;
  <a href="#license">License</a>
</p>

---

## Features

- **Menu bar app** — lives in your macOS menu bar, zero clutter
- **Clipboard history** — tracks text, images, and files you copy
- **Smart categorization** — auto-detects text, image, video, and file types
- **Search & filter** — quickly find what you need with type filters and search
- **Global hotkey** — press `Cmd+Shift+V` (customizable) to summon from anywhere
- **Cursor positioning** — popover appears right at your mouse cursor
- **200-item history** — persisted across restarts
- **Multi-language** — English / 中文, follows system language or manual switch

## Download

Download the latest DMG from [Releases](https://github.com/BABYSHARPYIN/ClipX/releases).

Open the DMG, drag **ClipX.app** to your **Applications** folder, and launch it.

> When running for the first time, grant **Accessibility** permission in **System Settings > Privacy & Security > Accessibility** so the global hotkey works.

## Build

```bash
git clone https://github.com/BABYSHARPYIN/ClipX.git
cd ClipX
bash scripts/build_app.sh
open build/ClipX.app
```

Or open `ClipboardHistory.xcodeproj` in Xcode and hit `⌘R`.

**Requirements**: macOS 14+, Xcode 15+, Swift 5.9

## Usage

| Action | Shortcut |
|--------|----------|
| Show / hide panel | `Cmd+Shift+V` (configurable) |
| Menu bar icon click | Show panel |
| Right-click menu bar icon | Settings, About, etc. |
| Click a history item | Copy back to clipboard |
| Search | Type in the search bar |
| Filter by type | Click the segmented tabs |

## Feedback

Found a bug or have a suggestion?

- [GitHub Issues](https://github.com/BABYSHARPYIN/ClipX/issues)
- Email: [1455395994@qq.com](mailto:1455395994@qq.com)

## License

MIT © [Rio](https://github.com/BABYSHARPYIN)
