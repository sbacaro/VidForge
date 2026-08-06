# VidForge

Pull ore from the web. Quench it into lasting metal.

## Web UI (GitHub Pages)

**https://sbacaro.github.io/VidForge/**

Rewritten in **TypeScript + Vite**. GitHub Pages is the remote control UI.

For real downloads at max quality, run the local companion on your Mac (`yt-dlp` + `ffmpeg`). The official Cobalt public API requires JWT and is not supported for third-party sites.

### Use with companion

```bash
export PATH="$HOME/.local/bin:$PATH"
vidforge-ui
```

Keep that running, then use the Pages UI — it talks to `http://127.0.0.1:8742`.

### Develop / rebuild the Pages site

```bash
cd web
npm install
npm run dev      # local preview
npm run build    # writes static files into /docs
```

## Install Mac companion (no Xcode)

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

Output defaults to `~/Movies/VidForge`.

## Alloys

| Alloy | Intent |
|-------|--------|
| **Archive Pure** | Best fidelity / remux when possible |
| **Crystal** | Near-lossless keepers |
| **Tempered** | Everyday high quality / 1080p |
| **Audio Ingot** | Best audio |

## Layout

- `web/` — TypeScript + Vite source for GitHub Pages  
- `docs/` — built static site (Pages source)  
- `CLI/` — `vidforge` terminal tool  
- `UIServer/` — local companion used by `vidforge-ui`  
- `VidForge/` — SwiftUI app sources  
- `Scripts/` — install + vendor helpers  

## Notes

- Respect site terms and copyright.  
- Bundled binaries are not stored in git; `Scripts/vendor-tools.sh` fetches them.
