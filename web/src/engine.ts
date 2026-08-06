import type { AlloyId, ForgeJob } from "./types";
import { alloyById } from "./lib";

/** Cloudflare Worker that resolves streams server-side (avoids browser CORS / Load failed). */
const API_BASE =
  (import.meta.env.VITE_API_BASE as string | undefined)?.replace(/\/$/, "") ||
  "https://vidforge.samuelbacaro.workers.dev";

interface ForgeResponse {
  status?: string;
  title?: string;
  downloadUrl?: string;
  quality?: string | null;
  filename?: string;
  error?: string;
}

export async function pingCloud(): Promise<boolean> {
  try {
    const res = await fetch(`${API_BASE}/api/health`, {
      method: "GET",
      headers: { Accept: "application/json" },
    });
    if (!res.ok) return false;
    const data = (await res.json()) as { ok?: boolean };
    return Boolean(data.ok);
  } catch {
    return navigator.onLine;
  }
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

  let data: ForgeResponse;
  try {
    const res = await fetch(`${API_BASE}/api/forge`, {
      method: "POST",
      headers: {
        Accept: "application/json",
        "Content-Type": "application/json",
      },
      body: JSON.stringify({ url: job.url, alloy: job.alloy }),
    });
    data = (await res.json()) as ForgeResponse;
    if (!res.ok) {
      throw new Error(data.error || `Cloud forge HTTP ${res.status}`);
    }
  } catch (e) {
    const msg = e instanceof Error ? e.message : String(e);
    if (msg === "Load failed" || msg === "Failed to fetch" || msg.includes("NetworkError")) {
      throw new Error("Cloud API unreachable. Check your network or try again in a moment.");
    }
    throw e instanceof Error ? e : new Error(msg);
  }

  if (data.error) throw new Error(data.error);
  if (!data.downloadUrl) throw new Error("Cloud forge returned no download URL.");

  onUpdate({
    phase: "quenching",
    progress: 0.8,
    title: data.title || job.title,
    status: data.quality ? `Quenching ${data.quality}…` : "Opening download…",
  });

  onUpdate({
    phase: "finished",
    progress: 1,
    title: data.title || job.title,
    downloadUrl: data.downloadUrl,
    status: "Ready — tap Download",
  });

  window.open(data.downloadUrl, "_blank", "noopener,noreferrer");
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
