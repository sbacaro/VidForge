import type { AlloyId, ForgeJob, Settings } from "./types";
import { alloyById, sleep } from "./lib";

export async function pingLocal(base: string): Promise<boolean> {
  try {
    const ctrl = new AbortController();
    const timer = setTimeout(() => ctrl.abort(), 800);
    const res = await fetch(`${trimSlash(base)}/api/jobs`, {
      signal: ctrl.signal,
      mode: "cors",
    });
    clearTimeout(timer);
    return res.ok;
  } catch {
    return false;
  }
}

export async function forgeLocal(
  settings: Settings,
  job: ForgeJob,
  onUpdate: (patch: Partial<ForgeJob>) => void
): Promise<void> {
  const base = trimSlash(settings.localBase);
  onUpdate({ phase: "prospecting", progress: 0.08, status: "Connecting to local companion…" });

  const res = await fetch(`${base}/api/forge`, {
    method: "POST",
    mode: "cors",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ url: job.url, alloy: job.alloy }),
  });

  if (!res.ok) {
    throw new Error(`Local companion HTTP ${res.status}`);
  }

  const created = (await res.json()) as { id?: string };
  const localId = created.id;

  for (let i = 0; i < 900; i++) {
    await sleep(1000);
    const list = (await (await fetch(`${base}/api/jobs`, { mode: "cors" })).json()) as Array<{
      id: string;
      url: string;
      title: string;
      phase: string;
      progress: number;
      status: string;
      output?: string;
      error?: string;
    }>;

    const match =
      list.find((x) => x.id === localId) ?? list.find((x) => x.url === job.url);
    if (!match) continue;

    onUpdate({
      title: match.title || job.title,
      phase: normalizePhase(match.phase),
      progress: match.progress ?? 0,
      status: match.status,
      outputPath: match.output,
      error: match.error,
    });

    if (match.phase === "finished") {
      onUpdate({ phase: "finished", progress: 1, status: "Ready on your Mac" });
      return;
    }
    if (match.phase === "failed") {
      throw new Error(match.error || match.status || "Local forge failed");
    }
  }

  throw new Error("Timed out waiting for local companion.");
}

export async function forgeCustomApi(
  settings: Settings,
  job: ForgeJob,
  onUpdate: (patch: Partial<ForgeJob>) => void
): Promise<void> {
  const base = trimSlash(settings.apiBase);
  if (!base) {
    throw new Error("Set a Cobalt-compatible API base in Settings.");
  }

  const alloy = alloyById(job.alloy);
  onUpdate({ phase: "smelting", progress: 0.2, status: "Requesting streams…" });

  const body: Record<string, unknown> = {
    url: job.url,
    filenameStyle: "pretty",
  };

  if (alloy.quality === "audio") {
    body.downloadMode = "audio";
    body.audioFormat = "best";
  } else {
    body.downloadMode = "auto";
    body.videoQuality = alloy.quality === "1080" ? "1080" : "max";
  }

  const headers: Record<string, string> = {
    Accept: "application/json",
    "Content-Type": "application/json",
  };
  if (settings.apiKey.trim()) {
    headers.Authorization = `Api-Key ${settings.apiKey.trim()}`;
  }

  const res = await fetch(`${base}/`, {
    method: "POST",
    mode: "cors",
    headers,
    body: JSON.stringify(body),
  });

  const data = (await res.json().catch(() => ({}))) as {
    status?: string;
    url?: string;
    filename?: string;
    tunnel?: string;
    picker?: Array<{ type?: string; url?: string; filename?: string }>;
    error?: { code?: string; message?: string };
    text?: string;
  };

  if (!res.ok || data.status === "error") {
    const code = data.error?.code || data.text || `HTTP ${res.status}`;
    if (String(code).includes("auth") || res.status === 401 || res.status === 403) {
      throw new Error(
        "API auth required. Official Cobalt blocks third-party apps — use your own instance + Api-Key, or the local companion."
      );
    }
    throw new Error(data.error?.message || String(code));
  }

  let downloadUrl = data.url || data.tunnel;
  let title = data.filename || job.title;

  if (data.status === "picker" && data.picker?.length) {
    const pick = data.picker.find((p) => p.type === "video") ?? data.picker[0];
    downloadUrl = pick.url;
    title = pick.filename || title;
  }

  if (!downloadUrl) {
    throw new Error("API returned no download URL.");
  }

  onUpdate({
    phase: "finished",
    progress: 1,
    title,
    downloadUrl,
    status: "Ready — download started in a new tab",
  });

  window.open(downloadUrl, "_blank", "noopener,noreferrer");
}

function normalizePhase(phase: string): ForgeJob["phase"] {
  switch (phase) {
    case "queued":
    case "prospecting":
    case "smelting":
    case "quenching":
    case "finished":
    case "failed":
      return phase;
    default:
      return "smelting";
  }
}

function trimSlash(value: string): string {
  return value.replace(/\/+$/, "");
}

export function describeEngineNeed(mode: Settings["engine"], online: boolean): string {
  if (mode === "local") {
    return online
      ? "Local companion online — max quality on this Mac."
      : "Local companion offline. Run: vidforge-ui";
  }
  return "Custom Cobalt-compatible API (needs your instance URL and usually an Api-Key).";
}

export type { AlloyId };
