# VidForge

Pull ore from the web. Quench it into lasting metal.

## Recommended — hybrid (reliable)

GitHub Pages UI + a small **local companion** on your Mac. The companion uses **bundled yt-dlp/ffmpeg** and your **browser YouTube login** (`--cookies-from-browser`, auto: Chrome → Chromium → Brave → Edge → Safari).

1. Install once:

```bash
cd ~/Projects/VidForge   # or your clone
./Scripts/install-ui.sh
```

2. Start the companion:

```bash
export PATH="$HOME/.local/bin:$PATH"
vidforge-ui
```

3. Use the UI: **https://sbacaro.github.io/VidForge/**

Forged files land in `~/Movies/VidForge`.

### Cookies / permissions

- Stay logged into YouTube in Chrome (preferred) or Safari.
- Force a browser: `export VIDFORGE_BROWSER=chrome`
- If yt-dlp cannot read cookies on macOS: **System Settings → Privacy & Security → Full Disk Access** → enable Terminal (or the app that starts `vidforge-ui`), then restart the companion.

### CLI

```bash
./Scripts/install-cli.sh   # if you also want `vidforge` on PATH
vidforge "https://www.youtube.com/watch?v=…"
```

## Cloud fallback (fragile)

If the companion is offline, the Pages UI can call a Cloudflare Worker. That path is **anonymous** and YouTube often blocks it (`not a bot`). Prefer the local companion for real use.

## Develop UI

```bash
cd web
npm install
npm run dev
npm run build   # writes static files to /docs for GitHub Pages
```

## Layout

| Path | Role |
|------|------|
| `web/` → `docs/` | GitHub Pages UI |
| `UIServer/` | Local companion API (`vidforge-ui`) |
| `CLI/` | Terminal forge (`vidforge`) |
| `Shared/` | Browser cookie detection for companion + CLI |
| `api/` | Optional Cloudflare Worker (anonymous fallback) |
