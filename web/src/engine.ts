import type { AlloyId, ForgeJob } from "./types";
import { alloyById } from "./lib";

/** Public Piped instances that allow browser CORS (*). */
const PIPED_APIS = [
  "https://api.piped.private.coffee",
  "https://pipedapi.adminforge.de",
  "https://pipedapi.kavin.rocks",
];

interface PipedStream {
  url?: string;
  format?: string;
  quality?: string;
  mimeType?: string;
  videoOnly?: boolean;
  bitrate?: number;
}

interface PipedResponse {
  title?: string;
  videoStreams?: PipedStream[];
  audioStreams?: PipedStream[];
  error?: string;
  message?: string;
}

export async function pingCloud(): Promise<boolean> {
  return navigator.onLine;
}

export async function forgeCloud(
  job: ForgeJob,
  onUpdate: (patch: Partial<ForgeJob>) => void
): Promise<void> {
  onUpdate({ phase: "prospecting", progress: 0.1, status: "Reading ore veins in the cloud…" });

  const videoId = extractYouTubeId(job.url);
  if (!videoId) {
    throw new Error("Free cloud engine supports YouTube links only right now.");
  }

  const alloy = alloyById(job.alloy);
  onUpdate({ phase: "smelting", progress: 0.35, status: `Smelting ${alloy.name}…` });

  const meta = await fetchPiped(videoId);
  const pick = pickStream(meta, job.alloy);
  if (!pick?.url) {
    throw new Error("No suitable stream found for this alloy.");
  }

  onUpdate({
    phase: "quenching",
    progress: 0.8,
    title: meta.title || job.title,
    status: pick.quality ? `Quenching ${pick.quality}…` : "Opening download…",
  });

  onUpdate({
    phase: "finished",
    progress: 1,
    title: meta.title || job.title,
    downloadUrl: pick.url,
    status: "Ready — tap Download",
  });

  window.open(pick.url, "_blank", "noopener,noreferrer");
}

async function fetchPiped(videoId: string): Promise<PipedResponse> {
  let last = "All cloud resolvers failed.";
  for (const base of PIPED_APIS) {
    try {
      const res = await fetch(`${base}/streams/${videoId}`, {
        headers: { Accept: "application/json" },
      });
      if (!res.ok) {
        last = `${base} HTTP ${res.status}`;
        continue;
      }
      const data = (await res.json()) as PipedResponse;
      if (data.error) {
        last = data.error;
        continue;
      }
      const count = (data.videoStreams?.length ?? 0) + (data.audioStreams?.length ?? 0);
      if (!count) {
        last = "Empty stream list";
        continue;
      }
      return data;
    } catch (e) {
      last = e instanceof Error ? e.message : String(e);
    }
  }
  throw new Error(last);
}

function pickStream(
  meta: PipedResponse,
  alloy: AlloyId
): { url: string; quality?: string } | null {
  const videos = meta.videoStreams ?? [];
  const audios = meta.audioStreams ?? [];

  if (alloy === "audio-ingot") {
    const best = [...audios].sort((a, b) => (b.bitrate ?? 0) - (a.bitrate ?? 0))[0];
    return best?.url ? { url: best.url, quality: best.quality ?? `${best.bitrate ?? "?"}bps` } : null;
  }

  const muxed = videos.filter((v) => v.videoOnly === false && v.url);
  const pool = muxed.length ? muxed : videos.filter((v) => v.url);
  if (!pool.length) return null;

  const ranked = pool
    .map((v) => ({ v, h: parseHeight(v.quality) }))
    .sort((a, b) => b.h - a.h || (b.v.bitrate ?? 0) - (a.v.bitrate ?? 0));

  let chosen = ranked[0];
  if (alloy === "tempered") {
    chosen = ranked.find((x) => x.h > 0 && x.h <= 1080) ?? ranked.find((x) => x.h === 720) ?? ranked[0];
  }

  return { url: chosen.v.url!, quality: chosen.v.quality ?? `${chosen.h}p` };
}

function parseHeight(quality?: string): number {
  if (!quality) return 0;
  const m = quality.match(/(\d{3,4})/);
  return m ? Number(m[1]) : 0;
}

function extractYouTubeId(input: string): string | null {
  try {
    const u = new URL(input);
    const host = u.hostname.replace(/^www\./, "");
    if (host === "youtu.be") return u.pathname.split("/").filter(Boolean)[0] ?? null;
    if (host.endsWith("youtube.com") || host.endsWith("youtube-nocookie.com") || host === "m.youtube.com") {
      if (u.searchParams.get("v")) return u.searchParams.get("v");
      const parts = u.pathname.split("/").filter(Boolean);
      if (["shorts", "embed", "live"].includes(parts[0] ?? "")) return parts[1] ?? null;
    }
  } catch {
    /* bare id */
  }
  return /^[\w-]{11}$/.test(input.trim()) ? input.trim() : null;
}
