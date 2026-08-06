export type AlloyId = "archive-pure" | "crystal" | "tempered" | "audio-ingot";

export type JobPhase =
  | "queued"
  | "prospecting"
  | "smelting"
  | "quenching"
  | "finished"
  | "failed";

export type EngineMode = "local" | "custom-api";

export interface Alloy {
  id: AlloyId;
  name: string;
  mark: string;
  blurb: string;
  quality: "max" | "1080" | "audio";
}

export interface ForgeJob {
  id: string;
  url: string;
  alloy: AlloyId;
  title: string;
  phase: JobPhase;
  progress: number;
  status: string;
  downloadUrl?: string;
  outputPath?: string;
  error?: string;
  createdAt: number;
}

export interface Settings {
  engine: EngineMode;
  localBase: string;
  apiBase: string;
  apiKey: string;
}

export const ALLOYS: Alloy[] = [
  {
    id: "archive-pure",
    name: "Archive Pure",
    mark: "I",
    blurb: "Highest fidelity. Remux when possible.",
    quality: "max",
  },
  {
    id: "crystal",
    name: "Crystal",
    mark: "II",
    blurb: "Near-lossless clarity for keepers.",
    quality: "max",
  },
  {
    id: "tempered",
    name: "Tempered",
    mark: "III",
    blurb: "Sharp everyday playback at 1080p.",
    quality: "1080",
  },
  {
    id: "audio-ingot",
    name: "Audio Ingot",
    mark: "IV",
    blurb: "Strip the image. Keep the sound.",
    quality: "audio",
  },
];

export const DEFAULT_SETTINGS: Settings = {
  engine: "local",
  localBase: "http://127.0.0.1:8742",
  apiBase: "",
  apiKey: "",
};
