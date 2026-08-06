import type { AlloyId, ForgeJob } from "./types";
import { ALLOYS } from "./types";

export function alloyById(id: AlloyId) {
  return ALLOYS.find((a) => a.id === id) ?? ALLOYS[0];
}

export function uid(): string {
  return crypto.randomUUID();
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
