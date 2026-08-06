/**
 * VidForge cloud API — Cloudflare Worker (free).
 * Resolves YouTube streams via Piped instances (server-side) and returns a download URL.
 * Nothing runs on the user's computer.
 */

export interface Env {}

type Alloy = "archive-pure" | "crystal" | "tempered" | "audio-ingot";

interface ForgeRequest {
  url?: string;
  alloy?: Alloy;
}

interface PipedStream {
  url?: string;
  format?: string;
  quality?: string;
  mimeType?: string;
  videoOnly?: boolean;
  bitrate?: number;
  contentLength?: number;
  codec?: string;
}

interface PipedResponse {
  title?: string;
  thumbnailUrl?: string;
  duration?: number;
  uploader?: string;
  videoStreams?: PipedStream[];
  audioStreams?: PipedStream[];
  error?: string;
  message?: string;
}

const PIPED_APIS = [
  "https://pipedapi.kavin.rocks",
  "https://pipedapi.nosebs.ru",
  "https://api.piped.private.coffee",
  "https://pipedapi.adminforge.de",
];

const ALLOWED_ORIGINS = new Set([
  "https://sbacaro.github.io",
  "http://127.0.0.1:5173",
  "http://localhost:5173",
  "http://127.0.0.1:4173",
  "http://localhost:4173",
]);

export default {
  async fetch(request: Request, _env: Env): Promise<Response> {
    const origin = request.headers.get("Origin") ?? "";
    if (request.method === "OPTIONS") {
      return cors(new Response(null, { status: 204 }), origin);
    }

    const url = new URL(request.url);

    if (request.method === "GET" && url.pathname === "/api/health") {
      return cors(json({ ok: true, service: "vidforge-api", mode: "cloud" }), origin);
    }

    if (request.method === "POST" && url.pathname === "/api/forge") {
      try {
        const body = (await request.json()) as ForgeRequest;
        const source = (body.url ?? "").trim();
        const alloy = body.alloy ?? "archive-pure";
        if (!source) return cors(json({ error: "Missing url" }, 400), origin);

        const videoId = extractYouTubeId(source);
        if (!videoId) {
          return cors(
            json(
              {
                error:
                  "Cloud free engine currently supports YouTube links only. Other sites coming later.",
              },
              400
            ),
            origin
          );
        }

        const meta = await fetchPiped(videoId);
        const pick = pickStream(meta, alloy);
        if (!pick?.url) {
          return cors(json({ error: "No suitable stream found for this alloy." }, 502), origin);
        }

        return cors(
          json({
            status: "finished",
            title: meta.title ?? `YouTube ${videoId}`,
            alloy,
            downloadUrl: pick.url,
            quality: pick.quality ?? null,
            kind: pick.kind,
            filename: sanitizeFilename(`${meta.title ?? videoId}${pick.ext}`),
          }),
          origin
        );
      } catch (err) {
        const message = err instanceof Error ? err.message : String(err);
        return cors(json({ error: message }, 502), origin);
      }
    }

    return cors(
      json({
        service: "VidForge API",
        endpoints: ["GET /api/health", "POST /api/forge"],
        ui: "https://sbacaro.github.io/VidForge/",
      }),
      origin
    );
  },
};

async function fetchPiped(videoId: string): Promise<PipedResponse> {
  let lastError = "All Piped instances failed.";
  for (const base of PIPED_APIS) {
    try {
      const res = await fetch(`${base}/streams/${videoId}`, {
        headers: {
          Accept: "application/json",
          "User-Agent": "VidForge/1.0 (+https://github.com/sbacaro/VidForge)",
        },
      });
      if (!res.ok) {
        lastError = `Piped ${base} HTTP ${res.status}`;
        continue;
      }
      const data = (await res.json()) as PipedResponse;
      if (data.error || data.message?.toLowerCase().includes("error")) {
        lastError = data.error || data.message || lastError;
        continue;
      }
      if ((data.videoStreams?.length ?? 0) + (data.audioStreams?.length ?? 0) === 0) {
        lastError = "Empty stream list";
        continue;
      }
      return data;
    } catch (e) {
      lastError = e instanceof Error ? e.message : String(e);
    }
  }
  throw new Error(lastError);
}

function pickStream(
  meta: PipedResponse,
  alloy: Alloy
): { url: string; quality?: string; kind: string; ext: string } | null {
  const videos = meta.videoStreams ?? [];
  const audios = meta.audioStreams ?? [];

  if (alloy === "audio-ingot") {
    const ranked = [...audios].sort((a, b) => (b.bitrate ?? 0) - (a.bitrate ?? 0));
    const best = ranked[0];
    if (!best?.url) return null;
    return {
      url: best.url,
      quality: best.quality ?? `${best.bitrate ?? "?"}bps`,
      kind: "audio",
      ext: extFromMime(best.mimeType, ".m4a"),
    };
  }

  // Prefer progressive (video+audio) streams for one-click browser download.
  const muxed = videos.filter((v) => v.videoOnly === false && v.url);
  const pool = muxed.length ? muxed : videos.filter((v) => v.url);
  if (!pool.length) return null;

  const scored = pool
    .map((v) => ({
      stream: v,
      height: parseHeight(v.quality),
    }))
    .sort((a, b) => b.height - a.height || (b.stream.bitrate ?? 0) - (a.stream.bitrate ?? 0));

  let chosen = scored[0];
  if (alloy === "tempered") {
    // Prefer closest to 1080p without going needlessly higher when muxed exists.
    chosen =
      scored.find((s) => s.height > 0 && s.height <= 1080) ??
      scored.find((s) => s.height === 720) ??
      scored[0];
  }

  const s = chosen.stream;
  return {
    url: s.url!,
    quality: s.quality ?? `${chosen.height}p`,
    kind: s.videoOnly ? "video-only" : "video",
    ext: extFromMime(s.mimeType, ".mp4"),
  };
}

function parseHeight(quality?: string): number {
  if (!quality) return 0;
  const m = quality.match(/(\d{3,4})/);
  return m ? Number(m[1]) : 0;
}

function extFromMime(mime?: string, fallback = ".mp4"): string {
  if (!mime) return fallback;
  if (mime.includes("webm")) return ".webm";
  if (mime.includes("mp4")) return ".mp4";
  if (mime.includes("audio/mp4") || mime.includes("m4a")) return ".m4a";
  if (mime.includes("opus")) return ".opus";
  if (mime.includes("mpeg")) return ".mp3";
  return fallback;
}

function extractYouTubeId(input: string): string | null {
  try {
    const u = new URL(input);
    const host = u.hostname.replace(/^www\./, "");
    if (host === "youtu.be") {
      return u.pathname.split("/").filter(Boolean)[0] ?? null;
    }
    if (host.endsWith("youtube.com") || host.endsWith("youtube-nocookie.com") || host === "m.youtube.com") {
      if (u.searchParams.get("v")) return u.searchParams.get("v");
      const parts = u.pathname.split("/").filter(Boolean);
      if (parts[0] === "shorts" || parts[0] === "embed" || parts[0] === "live") {
        return parts[1] ?? null;
      }
    }
  } catch {
    // bare id?
  }
  if (/^[\w-]{11}$/.test(input.trim())) return input.trim();
  return null;
}

function sanitizeFilename(name: string): string {
  return name.replace(/[\\/:*?"<>|]+/g, "-").replace(/\s+/g, " ").trim().slice(0, 180);
}

function json(data: unknown, status = 200): Response {
  return new Response(JSON.stringify(data), {
    status,
    headers: { "Content-Type": "application/json; charset=utf-8" },
  });
}

function cors(response: Response, origin: string): Response {
  const headers = new Headers(response.headers);
  const allow = ALLOWED_ORIGINS.has(origin) ? origin : "https://sbacaro.github.io";
  headers.set("Access-Control-Allow-Origin", allow);
  headers.set("Vary", "Origin");
  headers.set("Access-Control-Allow-Methods", "GET, POST, OPTIONS");
  headers.set("Access-Control-Allow-Headers", "Content-Type");
  headers.set("Access-Control-Max-Age", "86400");
  return new Response(response.body, { status: response.status, headers });
}
