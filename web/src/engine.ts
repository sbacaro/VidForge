import type { ForgeJob, JobPhase } from "./types";
import { alloyById } from "./lib";

const LOCAL_BASE = "http://127.0.0.1:8742";
const CLOUD_BASE =
  (import.meta.env.VITE_API_BASE as string | undefined)?.replace(/\/$/, "") ||
  "https://vidforge.samuelbacaro.workers.dev";

export type EngineMode = "local" | "cloud" | "offline";

export interface EngineStatus {
  mode: EngineMode;
  label: string;
  cookiesBrowser?: string | null;
  cookiesOk?: boolean;
}

interface LocalHealth {
  ok?: boolean;
  service?: string;
  cookiesBrowser?: string | null;
  cookiesOk?: boolean;
  cookiesMessage?: string;
}

interface LocalJob {
  id: string;
  url: string;
  alloy: string;
  title: string;
  phase: string;
  progress: number;
  status: string;
  output?: string | null;
  error?: string | null;
}

interface CloudForgeResponse {
  status?: string;
  title?: string;
  downloadUrl?: string;
  quality?: string | null;
  filename?: string;
  error?: string;
}

export async function pingEngine(): Promise<EngineStatus> {
  try {
    const res = await fetch(`${LOCAL_BASE}/api/health`, {
      method: "GET",
      headers: { Accept: "application/json" },
    });
    if (res.ok) {
      const data = (await res.json()) as LocalHealth;
      if (data.ok !== false) {
        const browser = data.cookiesBrowser ?? null;
        const cookiesOk = Boolean(data.cookiesOk);
        const browserLabel = browser ? capitalize(browser) : "browser";
        return {
          mode: "local",
          cookiesBrowser: browser,
          cookiesOk,
          label: cookiesOk
            ? `Local forge ready · ${browserLabel} cookies`
            : `Local forge ready · cookies weak`,
        };
      }
    }
  } catch {
    /* companion offline */
  }

  try {
    const res = await fetch(`${CLOUD_BASE}/api/health`, {
      method: "GET",
      headers: { Accept: "application/json" },
    });
    if (res.ok) {
      return {
        mode: "cloud",
        label: "Companion offline — cloud fallback",
      };
    }
  } catch {
    /* cloud unreachable */
  }

  return { mode: "offline", label: "Forge offline" };
}

export async function forgeJob(
  job: ForgeJob,
  onUpdate: (patch: Partial<ForgeJob>) => void
): Promise<void> {
  const status = await pingEngine();
  if (status.mode === "local") {
    await forgeLocal(job, onUpdate);
    return;
  }
  if (status.mode === "cloud") {
    await forgeCloud(job, onUpdate);
    return;
  }
  throw new Error(
    "Companion offline. In Terminal: export PATH=\"$HOME/.local/bin:$PATH\" && vidforge-ui"
  );
}

async function forgeLocal(
  job: ForgeJob,
  onUpdate: (patch: Partial<ForgeJob>) => void
): Promise<void> {
  onUpdate({ phase: "prospecting", progress: 0.08, status: "Sending ore to local forge…" });

  const res = await fetch(`${LOCAL_BASE}/api/forge`, {
    method: "POST",
    headers: {
      Accept: "application/json",
      "Content-Type": "application/json",
    },
    body: JSON.stringify({ url: job.url, alloy: job.alloy }),
  });
  const created = (await res.json()) as LocalJob & { error?: string };
  if (!res.ok) {
    throw new Error(created.error || `Local forge HTTP ${res.status}`);
  }

  const localId = created.id;
  onUpdate({
    title: created.title || job.title,
    phase: normalizePhase(created.phase),
    progress: created.progress,
    status: created.status,
  });

  // Poll companion job list until finished/failed.
  for (;;) {
    await sleep(700);
    const listRes = await fetch(`${LOCAL_BASE}/api/jobs`, {
      headers: { Accept: "application/json" },
    });
    if (!listRes.ok) throw new Error(`Local jobs HTTP ${listRes.status}`);
    const jobs = (await listRes.json()) as LocalJob[];
    const current = jobs.find((j) => j.id === localId);
    if (!current) throw new Error("Local job disappeared from the anvil rack.");

    onUpdate({
      title: current.title || job.title,
      phase: normalizePhase(current.phase),
      progress: current.progress,
      status: current.status,
      error: current.error ?? undefined,
      output: current.output ?? undefined,
    });

    if (current.phase === "finished") {
      if (current.output) {
        onUpdate({
          status: `Ready — ${current.output}`,
          output: current.output,
        });
      }
      return;
    }
    if (current.phase === "failed") {
      throw new Error(current.error || current.status || "Local forge failed.");
    }
  }
}

async function forgeCloud(
  job: ForgeJob,
  onUpdate: (patch: Partial<ForgeJob>) => void
): Promise<void> {
  onUpdate({
    phase: "prospecting",
    progress: 0.1,
    status: "Companion offline — trying anonymous cloud…",
  });

  const videoId = extractYouTubeId(job.url);
  if (!videoId) {
    throw new Error("Cloud fallback supports YouTube links only. Start vidforge-ui for full forging.");
  }

  const alloy = alloyById(job.alloy);
  onUpdate({ phase: "smelting", progress: 0.35, status: `Smelting ${alloy.name} in the cloud…` });

  let data: CloudForgeResponse;
  try {
    const res = await fetch(`${CLOUD_BASE}/api/forge`, {
      method: "POST",
      headers: {
        Accept: "application/json",
        "Content-Type": "application/json",
      },
      body: JSON.stringify({ url: job.url, alloy: job.alloy }),
    });
    data = (await res.json()) as CloudForgeResponse;
    if (!res.ok) {
      throw new Error(data.error || `Cloud forge HTTP ${res.status}`);
    }
  } catch (e) {
    const msg = e instanceof Error ? e.message : String(e);
    if (msg === "Load failed" || msg === "Failed to fetch" || msg.includes("NetworkError")) {
      throw new Error(
        "Cloud unreachable and companion offline. Start: export PATH=\"$HOME/.local/bin:$PATH\" && vidforge-ui"
      );
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
    status: "Ready — tap Download (cloud stream)",
  });

  window.open(data.downloadUrl, "_blank", "noopener,noreferrer");
}

export async function revealLocalPath(path: string): Promise<void> {
  await fetch(`${LOCAL_BASE}/api/reveal`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ path }),
  });
}

function normalizePhase(phase: string): JobPhase {
  switch (phase) {
    case "queued":
    case "prospecting":
    case "smelting":
    case "quenching":
    case "finished":
    case "failed":
      return phase;
    default:
      return "prospecting";
  }
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

function capitalize(value: string): string {
  return value ? value.charAt(0).toUpperCase() + value.slice(1) : value;
}

function sleep(ms: number): Promise<void> {
  return new Promise((resolve) => setTimeout(resolve, ms));
}
