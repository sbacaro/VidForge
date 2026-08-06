# VidForge

Native **macOS** app that pulls web video (YouTube and sites yt-dlp supports) and quenches it into lasting local files.

Stack: **Swift + SwiftUI** (best fit for a Mac-native UI) driving bundled **yt-dlp** and **ffmpeg**. YouTube auth uses your browser session (`--cookies-from-browser`).

## Install

```bash
cd ~/Projects/VidForge
./Scripts/install-app.sh
```

That vendors engines (if needed), builds `VidForge.app`, copies it to `~/Applications`, and opens it.

## Use

1. Stay logged into YouTube in **Chrome** (preferred) or Safari.
2. If cookie reads fail: **System Settings → Privacy & Security → Full Disk Access** → enable **VidForge**.
3. Paste a URL, pick an alloy, hit **Strike**.
4. Files land in `~/Movies/VidForge`.

Settings (⌘,) let you force a browser cookie source.

## Alloys

| Alloy | Result |
|-------|--------|
| Archive Pure | Max-fidelity remux → MKV |
| Crystal | Near-lossless HEVC (x265) |
| Tempered | High-quality H.264 |
| Audio Ingot | Best audio → FLAC |

## Develop

```bash
./Scripts/vendor-tools.sh   # once
swift run VidForge          # debug from repo (uses ./vendor)
./Scripts/bundle-app.sh     # produce dist/VidForge.app
```

## Notes

- Engines in `vendor/` are gitignored (large binaries). Install scripts download them.
- No Cloudflare Worker, no GitHub Pages companion. Everything runs on your Mac.
