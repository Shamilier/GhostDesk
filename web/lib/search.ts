import type { Recording } from "@/lib/types";

export type ComparisonOperator = ">" | ">=" | "<" | "<=" | "=";

export interface DurationFilter {
  comparison: ComparisonOperator;
  minutes: number;
}

export interface SearchQuery {
  terms: string[];
  tags: string[];
  sources: string[];
  speakers: string[];
  before?: Date;
  after?: Date;
  hasScreen?: boolean;
  duration?: DurationFilter;
}

const comparisonTokens: ComparisonOperator[] = [">", ">=", "<", "<=", "="];

export function parseSearchQuery(raw: string): SearchQuery {
  const tokens = raw.match(/"[^"]+"|\S+/g) ?? [];
  const result: SearchQuery = {
    terms: [],
    tags: [],
    sources: [],
    speakers: []
  };

  tokens.forEach((token) => {
    const cleaned = token.replace(/^"|"$/g, "");
    if (cleaned.startsWith("tag:")) {
      result.tags.push(cleaned.slice(4));
      return;
    }
    if (cleaned.startsWith("source:")) {
      result.sources.push(cleaned.slice(7));
      return;
    }
    if (cleaned.startsWith("speaker:")) {
      result.speakers.push(cleaned.slice(8));
      return;
    }
    if (cleaned.startsWith("before:")) {
      const date = new Date(cleaned.slice(7));
      if (!Number.isNaN(date.getTime())) {
        result.before = date;
      }
      return;
    }
    if (cleaned.startsWith("after:")) {
      const date = new Date(cleaned.slice(6));
      if (!Number.isNaN(date.getTime())) {
        result.after = date;
      }
      return;
    }
    if (cleaned.startsWith("duration:")) {
      const value = cleaned.slice(9);
      const comparison = comparisonTokens.find((token) => value.startsWith(token));
      if (comparison) {
        const numeric = value.slice(comparison.length);
        const normalized = numeric.endsWith("m") ? parseFloat(numeric) : parseFloat(numeric) * 60;
        if (!Number.isNaN(normalized)) {
          result.duration = { comparison, minutes: normalized };
        }
      }
      return;
    }
    if (cleaned.startsWith("has:")) {
      result.hasScreen = cleaned.slice(4) === "screen";
      return;
    }

    result.terms.push(cleaned.toLowerCase());
  });

  return result;
}

export function matchesSearchQuery(recording: Recording, query: SearchQuery) {
  if (query.tags.length > 0 && !query.tags.every((tag) => recording.tags.some((value) => value.toLowerCase().includes(tag.toLowerCase())))) {
    return false;
  }
  if (query.sources.length > 0 && !query.sources.includes(recording.source)) {
    return false;
  }
  if (query.speakers.length > 0) {
    const speakers = new Set(recording.transcript.map((segment) => segment.speaker.toLowerCase()));
    if (!query.speakers.every((speaker) => Array.from(speakers).some((value) => value.includes(speaker.toLowerCase())))) {
      return false;
    }
  }
  if (query.before && new Date(recording.createdAt) >= query.before) {
    return false;
  }
  if (query.after && new Date(recording.createdAt) <= query.after) {
    return false;
  }
  if (query.duration) {
    const minutes = recording.durationSeconds / 60;
    const { comparison, minutes: threshold } = query.duration;
    if (comparison === ">" && !(minutes > threshold)) return false;
    if (comparison === ">=" && !(minutes >= threshold)) return false;
    if (comparison === "<" && !(minutes < threshold)) return false;
    if (comparison === "<=" && !(minutes <= threshold)) return false;
    if (comparison === "=" && Math.round(minutes) !== Math.round(threshold)) return false;
  }
  if (query.hasScreen && recording.source !== "screen" && recording.kind !== "system") {
    return false;
  }

  if (query.terms.length === 0) {
    return true;
  }

  const haystack = [
    recording.title,
    recording.summary,
    recording.tags.join(" "),
    recording.notes.map((note) => note.body).join(" "),
    recording.transcript.map((segment) => segment.text).join(" ")
  ]
    .join(" ")
    .toLowerCase();

  return query.terms.every((term) => haystack.includes(term));
}

export function highlightMatches(text: string, terms: string[]) {
  if (terms.length === 0) return text;
  const escaped = terms.map((term) => term.replace(/[.*+?^${}()|[\]\\]/g, "\\$&"));
  const regex = new RegExp(`(${escaped.join("|")})`, "gi");
  return text.replace(regex, (match) => `[[${match}]]`);
}

export function extractBestSnippet(recording: Recording, terms: string[]) {
  if (terms.length === 0) {
    return { snippet: recording.summary, atMs: 0 };
  }
  const term = terms[0];
  const segment = recording.transcript.find((item) => item.text.toLowerCase().includes(term));
  if (segment) {
    return {
      snippet: highlightMatches(segment.text, terms),
      atMs: segment.startMs
    };
  }
  return {
    snippet: highlightMatches(recording.summary, terms),
    atMs: 0
  };
}
