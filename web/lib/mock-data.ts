import { addDays, subDays } from "date-fns";
import type { Collection, Recording, TranscriptSegment } from "./types";

const participants = [
  "Alice Johnson",
  "Ivan Petrov",
  "Mei Chen",
  "Carlos Ramirez",
  "Sofia Martins",
  "Noah Becker",
  "Lara Singh",
  "James Smith"
];

function generateTranscript(seed: number): TranscriptSegment[] {
  return Array.from({ length: 18 }).map((_, index) => {
    const startMs = index * 45_000 + seed * 3000;
    return {
      id: `${seed}-${index}`,
      startMs,
      endMs: startMs + 45_000,
      speaker: participants[(index + seed) % participants.length],
      text: `Discussion topic ${index + 1}: exploring how GhostDesk surfaces insights with AI-driven summarisation and tagging mechanics for scenario ${seed}.`,
      words: Array.from({ length: 12 }).map((__, wordIndex) => ({
        text: `word${wordIndex}`,
        offsetMs: startMs + wordIndex * 1000
      }))
    };
  });
}

const baseDate = new Date();

export const mockRecordings: Recording[] = Array.from({ length: 1200 }).map((_, index) => {
  const createdAt = subDays(baseDate, index % 45);
  const duration = 900 + (index % 5) * 600;
  const status = index % 7 === 0 ? "processing" : "ready";
  const tags = ["team sync", "research", "ai", "questions", "product", "design"];
  return {
    id: `rec-${index}`,
    workspaceId: "workspace-ghost",
    title: `Session ${index + 1} · ${index % 2 === 0 ? "Product Review" : "Lecture"}`,
    description: "Detailed capture of the session with automatic summaries, highlights and actionable next steps.",
    source: index % 4 === 0 ? "zoom" : index % 4 === 1 ? "meet" : index % 4 === 2 ? "teams" : "local",
    kind: index % 3 === 0 ? "meeting" : index % 3 === 1 ? "lecture" : "workshop",
    durationSeconds: duration,
    createdAt: createdAt.toISOString(),
    processedAt: status === "ready" ? addDays(createdAt, 1).toISOString() : undefined,
    status,
    tags: tags.filter((_, tagIndex) => (tagIndex + index) % 2 === 0).slice(0, 3),
    participants: participants.slice(index % participants.length, (index % participants.length) + 3),
    thumbnailUrl: `https://images.unsplash.com/photo-1523475472560-d2df97ec485c?auto=format&fit=crop&w=800&q=80`,
    summary: "AI summary: Alignment on roadmap priorities, open questions around data quality and follow-up on experimentation backlog.",
    pinned: index % 20 === 0,
    insights: {
      id: `insight-${index}`,
      summary: "Alignment achieved on objectives and outstanding blockers identified for the upcoming sprint.",
      actionItems: [
        "Prepare training dataset quality report",
        "Schedule follow-up with research team",
        "Publish summary to workspace"
      ],
      topics: ["roadmap", "data quality", "experimentation"],
      chapters: [
        { title: "Opening & context", startMs: 0 },
        { title: "Deep dive", startMs: 420_000 },
        { title: "Decisions", startMs: 1_080_000 }
      ],
      highlights: [
        {
          quote: "We should surface definitions inline for faster recall.",
          atMs: 315_000
        },
        {
          quote: "Tagging automation saved us hours last week.",
          atMs: 780_000
        }
      ]
    },
    transcript: generateTranscript(index),
    notes: [
      {
        id: `note-${index}-1`,
        author: participants[index % participants.length],
        body: "Need to confirm dataset size before next sync.",
        atMs: 480_000,
        createdAt: addDays(createdAt, 2).toISOString()
      },
      {
        id: `note-${index}-2`,
        author: "You",
        body: "Share TL;DR with leadership. Also capture summary variations for A/B testing.",
        createdAt: addDays(createdAt, 2).toISOString(),
        isPrivate: true
      }
    ],
    sizeBytes: 450_000_000
  };
});

export const mockCollections: Collection[] = [
  {
    id: "col-1",
    name: "Weekly Leadership Sync",
    description: "Pinned highlights from the leadership alignment meetings.",
    type: "manual",
    count: 12
  },
  {
    id: "col-2",
    name: "Course · Machine Learning",
    description: "Auto-collected lectures from semester sessions.",
    type: "smart",
    filter: "tag:course",
    count: 28
  },
  {
    id: "col-3",
    name: "Smart · Ready to review",
    type: "smart",
    filter: "status:ready tag:questions",
    count: 17
  }
];

export const tags = Array.from(new Set(mockRecordings.flatMap((recording) => recording.tags)));
export const participantsSet = Array.from(new Set(mockRecordings.flatMap((recording) => recording.participants)));
