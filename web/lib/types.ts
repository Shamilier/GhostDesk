export type RecordingSource = "zoom" | "meet" | "teams" | "local" | "screen";
export type RecordingKind = "meeting" | "lecture" | "workshop" | "system";
export type ProcessingStatus = "processing" | "ready" | "failed";

export interface TranscriptWord {
  text: string;
  offsetMs: number;
}

export interface TranscriptSegment {
  id: string;
  startMs: number;
  endMs: number;
  speaker: string;
  text: string;
  words?: TranscriptWord[];
}

export interface InsightChapter {
  title: string;
  startMs: number;
}

export interface InsightItem {
  id: string;
  summary: string;
  actionItems: string[];
  topics: string[];
  chapters: InsightChapter[];
  highlights: {
    quote: string;
    atMs: number;
  }[];
}

export interface Note {
  id: string;
  author: string;
  body: string;
  atMs?: number;
  isPrivate?: boolean;
  createdAt: string;
}

export interface Recording {
  id: string;
  title: string;
  description: string;
  source: RecordingSource;
  kind: RecordingKind;
  durationSeconds: number;
  createdAt: string;
  processedAt?: string;
  status: ProcessingStatus;
  tags: string[];
  participants: string[];
  thumbnailUrl: string;
  summary: string;
  pinned?: boolean;
  insights: InsightItem;
  transcript: TranscriptSegment[];
  notes: Note[];
  workspaceId: string;
  sizeBytes: number;
}

export interface Collection {
  id: string;
  name: string;
  description?: string;
  type: "manual" | "smart";
  filter?: string;
  count: number;
}
