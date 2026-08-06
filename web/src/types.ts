export type AlloyId = "archive-pure" | "crystal" | "tempered" | "audio-ingot";

export type JobPhase =
  | "queued"
  | "prospecting"
  | "smelting"
  | "quenching"
  | "finished"
  | "failed";

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
  error?: string;
  createdAt: number;
}

export const ALLOYS: Alloy[] = [
  {
    id: "archive-pure",
    name: "Archive Pure",
    mark: "I",
    blurb: "Highest available YouTube stream.",
    quality: "max",
  },
  {
    id: "crystal",
    name: "Crystal",
    mark: "II",
    blurb: "Top clarity progressive stream.",
    quality: "max",
  },
  {
    id: "tempered",
    name: "Tempered",
    mark: "III",
    blurb: "Cap around 1080p for everyday use.",
    quality: "1080",
  },
  {
    id: "audio-ingot",
    name: "Audio Ingot",
    mark: "IV",
    blurb: "Best audio-only track.",
    quality: "audio",
  },
];
