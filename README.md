# VidForge

Pull ore from the web. Quench it into lasting metal.

## Web UI

**https://sbacaro.github.io/VidForge/**

TypeScript + Vite remote control. For real downloads, run the local companion.

```bash
export PATH="$HOME/.local/bin:$PATH"
vidforge-ui
```

## Install (no Xcode)

```bash
git clone https://github.com/sbacaro/VidForge.git
cd VidForge
./Scripts/vendor-tools.sh
./Scripts/install-cli.sh
./Scripts/install-ui.sh
```

```bash
export PATH="$HOME/.local/bin:$PATH"
vidforge "https://…"
vidforge-ui
```

Output: `~/Movies/VidForge`

## Develop the Pages site

```bash
cd web
npm install
npm run dev
npm run build   # writes to /docs
```

## Layout

| Path | Role |
|------|------|
| `web/` | Pages source (TypeScript + Vite) |
| `docs/` | Built static site for GitHub Pages |
| `CLI/` | `vidforge` terminal tool |
| `UIServer/` | Local companion API (`vidforge-ui`) |
| `Scripts/` | vendor + install helpers |
| `vendor/` | Local ffmpeg/yt-dlp (gitignored binaries) |

## Alloys

| Alloy | Intent |
|-------|--------|
| Archive Pure | Best fidelity |
| Crystal | Near-lossless keepers |
| Tempered | Everyday high quality / 1080p |
| Audio Ingot | Best audio |

## Notes

- Official Cobalt API requires JWT and is not used by default.
- Respect site terms and copyright.
