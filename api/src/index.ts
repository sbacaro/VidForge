/**
 * VidForge cloud API — Cloudflare Worker (free).
 * Resolves YouTube streams via InnerTube (primary) and Piped (fallback).
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

interface YtFormat {
  url?: string;
  mimeType?: string;
  qualityLabel?: string;
  quality?: string;
  bitrate?: number;
  averageBitrate?: number;
  width?: number;
  height?: number;
  contentLength?: string;
}

interface YtPlayerResponse {
  playabilityStatus?: { status?: string; reason?: string };
  videoDetails?: { title?: string; author?: string; lengthSeconds?: string };
  streamingData?: {
    formats?: YtFormat[];
    adaptiveFormats?: YtFormat[];
  };
}

const PIPED_APIS = ["https://api.piped.private.coffee"];

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

        const meta = await resolveStreams(videoId);
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

async function resolveStreams(videoId: string): Promise<PipedResponse> {
  const errors: string[] = [];

  // Prefer Piped when healthy (sometimes higher-quality progressive via proxy).
  // Fall back to InnerTube; both get short retries for transient 5xx.
  for (const engine of [fetchPiped, fetchInnerTube] as const) {
    for (let attempt = 0; attempt < 3; attempt++) {
      try {
        if (attempt > 0) await sleep(350 * attempt);
        return await engine(videoId);
      } catch (e) {
        const msg = friendlyResolverError(e);
        if (attempt === 2) errors.push(msg);
      }
    }
  }

  throw new Error(
    errors.length
      ? errors.slice(0, 2).join(" · ")
      : "Cloud resolver unavailable. Try again shortly."
  );
}

function sleep(ms: number): Promise<void> {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

function friendlyResolverError(err: unknown): string {
  const raw = err instanceof Error ? err.message : String(err);
  if (/SignInConfirmNotBot|LOGIN_REQUIRED|not a bot/i.test(raw)) {
    return "YouTube is blocking anonymous access for this video on the free cloud resolver. Try another video or try again later.";
  }
  if (/HTTP 5\d\d/.test(raw)) {
    return "Free cloud resolver is overloaded or blocked by YouTube right now. Try again in a minute.";
  }
  if (/innertube/i.test(raw) && /UNPLAYABLE|ERROR|LOGIN_REQUIRED/i.test(raw)) {
    return "YouTube refused playback for this video via the free cloud path.";
  }
  // Keep short host errors; strip huge Java stacks from Piped.
  const firstLine = raw.split("\n")[0] ?? raw;
  return firstLine.length > 180 ? `${firstLine.slice(0, 177)}…` : firstLine;
}

/** Android VR InnerTube client returns direct googlevideo URLs (no cipher). */
async function fetchInnerTube(videoId: string): Promise<PipedResponse> {
  const body = {
    context: {
      client: {
        clientName: "ANDROID_VR",
        clientVersion: "1.60.19",
        deviceMake: "Oculus",
        deviceModel: "Quest 3",
        osName: "Android",
        osVersion: "12L",
        androidSdkVersion: 32,
        hl: "en",
        gl: "US",
      },
    },
    videoId,
    contentCheckOk: true,
    racyCheckOk: true,
  };

  const endpoints = [
    "https://youtubei.googleapis.com/youtubei/v1/player?prettyPrint=false",
    "https://www.youtube.com/youtubei/v1/player?prettyPrint=false",
  ];

  const errors: string[] = [];
  for (const endpoint of endpoints) {
    for (let attempt = 0; attempt < 2; attempt++) {
      try {
        const res = await fetch(endpoint, {
          method: "POST",
          headers: {
            "Content-Type": "application/json",
            "User-Agent": "com.google.android.apps.youtube.vr.oculus/1.60.19",
            "X-Goog-Api-Format-Version": "2",
          },
          body: JSON.stringify(body),
        });
        if (!res.ok) {
          errors.push(`innertube HTTP ${res.status}`);
          continue;
        }
        const data = (await res.json()) as YtPlayerResponse;
        const status = data.playabilityStatus?.status ?? "UNKNOWN";
        if (status !== "OK") {
          errors.push(data.playabilityStatus?.reason || `innertube ${status}`);
          continue;
        }
        const mapped = mapInnerTube(data);
        const count =
          (mapped.videoStreams?.length ?? 0) + (mapped.audioStreams?.length ?? 0);
        if (!count) {
          errors.push("innertube empty streams");
          continue;
        }
        return mapped;
      } catch (e) {
        errors.push(e instanceof Error ? e.message : String(e));
      }
    }
  }
  throw new Error(errors[0] || "innertube failed");
}

function mapInnerTube(data: YtPlayerResponse): PipedResponse {
  const formats = data.streamingData?.formats ?? [];
  const adaptive = data.streamingData?.adaptiveFormats ?? [];
  const videoStreams: PipedStream[] = [];
  const audioStreams: PipedStream[] = [];

  for (const f of formats) {
    if (!f.url) continue;
    videoStreams.push({
      url: f.url,
      mimeType: f.mimeType,
      quality: f.qualityLabel || f.quality || (f.height ? `${f.height}p` : undefined),
      videoOnly: false,
      bitrate: f.bitrate ?? f.averageBitrate,
      contentLength: f.contentLength ? Number(f.contentLength) : undefined,
    });
  }

  for (const f of adaptive) {
    if (!f.url) continue;
    const mime = f.mimeType ?? "";
    const quality = f.qualityLabel || f.quality || (f.height ? `${f.height}p` : undefined);
    const stream: PipedStream = {
      url: f.url,
      mimeType: mime,
      quality,
      bitrate: f.bitrate ?? f.averageBitrate,
      contentLength: f.contentLength ? Number(f.contentLength) : undefined,
    };
    if (mime.startsWith("audio/")) {
      audioStreams.push(stream);
    } else if (mime.startsWith("video/")) {
      videoStreams.push({ ...stream, videoOnly: true });
    }
  }

  return {
    title: data.videoDetails?.title,
    uploader: data.videoDetails?.author,
    duration: data.videoDetails?.lengthSeconds
      ? Number(data.videoDetails.lengthSeconds)
      : undefined,
    videoStreams,
    audioStreams,
  };
}

async function fetchPiped(videoId: string): Promise<PipedResponse> {
  const errors: string[] = [];
  for (const base of PIPED_APIS) {
    for (let attempt = 0; attempt < 2; attempt++) {
      try {
        const res = await fetch(`${base}/streams/${videoId}`, {
          redirect: "manual",
          headers: {
            Accept: "application/json",
            "User-Agent": "VidForge/1.0 (+https://github.com/sbacaro/VidForge)",
          },
        });
        if (res.status >= 300 && res.status < 400) {
          errors.push(`${new URL(base).host} bad redirect`);
          continue;
        }
        if (!res.ok) {
          let detail = `${new URL(base).host} HTTP ${res.status}`;
          try {
            const errBody = (await res.json()) as PipedResponse;
            if (errBody.error) detail = errBody.error;
          } catch {
            /* ignore non-JSON error bodies */
          }
          errors.push(detail);
          continue;
        }
        const type = res.headers.get("content-type") ?? "";
        if (!type.includes("json")) {
          errors.push(`${new URL(base).host} non-JSON`);
          continue;
        }
        const data = (await res.json()) as PipedResponse;
        if (data.error) {
          errors.push(data.error);
          continue;
        }
        const count = (data.videoStreams?.length ?? 0) + (data.audioStreams?.length ?? 0);
        if (!count) {
          errors.push(`${new URL(base).host} empty streams`);
          continue;
        }
        return data;
      } catch (e) {
        errors.push(e instanceof Error ? e.message : String(e));
      }
    }
  }
  throw new Error(errors[0] || "piped failed");
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

  // Prefer progressive (video+audio) for one-click browser download.
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
  if (mime.includes("audio/mp4") || mime.includes("m4a")) return ".m4a";
  if (mime.includes("mp4")) return ".mp4";
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
