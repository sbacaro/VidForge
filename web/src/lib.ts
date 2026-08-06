import type { AlloyId, ForgeJob, Settings } from "./types";
import { ALLOYS, DEFAULT_SETTINGS } from "./types";

const KEY = "vidforge.pages.v2";

export function loadSettings(): Settings {
  try {
    const raw = localStorage.getItem(KEY);
    if (!raw) return { ...DEFAULT_SETTINGS };
    return { ...DEFAULT_SETTINGS, ...JSON.parse(raw) };
  } catch {
    return { ...DEFAULT_SETTINGS };
  }
}

export function saveSettings(settings: Settings): void {
  localStorage.setItem(KEY, JSON.stringify(settings));
}

export function alloyById(id: AlloyId) {
  return ALLOYS.find((a) => a.id === id) ?? ALLOYS[0];
}

export function uid(): string {
  return crypto.randomUUID();
}

export function sleep(ms: number): Promise<void> {
  return new Promise((r) => setTimeout(r, ms));
}

export function phaseLabel(phase: ForgeJob["phase"]): string {
  switch (phase) {
    case "queued":
      return "Queued";
    case "prospecting":
      return "Prospecting";
    case "smelting":
      return "Smelting";
    case "quenching":
      return "Quenching";
    case "finished":
      return "Forged";
    case "failed":
      return "Cracked";
  }
}
