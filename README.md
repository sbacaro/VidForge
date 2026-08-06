# VidForge

Pull ore from the web. Quench it into lasting metal.

Native Mac companion (**yt-dlp + ffmpeg bundled locally**) plus a **GitHub Pages** web forge.

## Use on the web

**Web UI:** [https://sbacaro.github.io/VidForge/](https://sbacaro.github.io/VidForge/)

The Pages UI can:

1. Talk to your **local companion** at `http://127.0.0.1:8742` for max-quality Archival remux/encode on your Mac  
2. Or use a **Cobalt-compatible** public API for in-browser downloads (GitHub Pages cannot run ffmpeg in the cloud)

## Install Mac companion (no Xcode)

```bash
git clone https://github.com/sbacaro/VidForge.git
cd VidForge
./Scripts/vendor-tools.sh    # downloads ffmpeg + yt-dlp into the project
./Scripts/install-cli.sh     # installs `vidforge` CLI into ~/.local
./Scripts/install-ui.sh      # installs browser UI server (`vidforge-ui`)
```

Then:

```bash
export PATH="$HOME/.local/bin:$PATH"
vidforge-ui                  # opens local UI + enables Pages→local mode
vidforge "https://…"         # pure CLI forge
```

Output defaults to `~/Movies/VidForge`.

## Alloys

| Alloy | Intent |
|-------|--------|
| **Archive Pure** | Best fidelity / remux when possible |
| **Crystal** | Near-lossless HEVC locally (or max web quality) |
| **Tempered** | High-quality H.264 / 1080p web |
| **Audio Ingot** | Best audio |

## Repository layout

- `CLI/` — `vidforge` terminal tool  
- `UIServer/` — local web UI server used by `vidforge-ui`  
- `VidForge/` — SwiftUI Mac app sources  
- `docs/` — GitHub Pages site  
- `Scripts/` — install + vendor helpers  

Bundled binaries are **not** stored in git (GitHub 100MB limit). `Scripts/vendor-tools.sh` fetches them.

## Notes

- Respect site terms and copyright. Only keep media you have rights to.  
- Steinberg Activation Manager / SpectraLayers is unrelated to VidForge.
