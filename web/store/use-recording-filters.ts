"use client";

import { create } from "zustand";
import type { ProcessingStatus, RecordingKind, RecordingSource } from "@/lib/types";

export interface DateRangeFilter {
  from?: string;
  to?: string;
}

interface FilterState {
  query: string;
  tags: string[];
  sources: RecordingSource[];
  kinds: RecordingKind[];
  statuses: ProcessingStatus[];
  participants: string[];
  pinnedOnly: boolean;
  dateRange?: DateRangeFilter;
  setQuery: (value: string) => void;
  toggleTag: (tag: string) => void;
  toggleSource: (source: RecordingSource) => void;
  toggleKind: (kind: RecordingKind) => void;
  toggleStatus: (status: ProcessingStatus) => void;
  toggleParticipant: (participant: string) => void;
  setPinnedOnly: (value: boolean) => void;
  setDateRange: (range?: DateRangeFilter) => void;
  reset: () => void;
}

const initialState = {
  query: "",
  tags: [] as string[],
  sources: [] as RecordingSource[],
  kinds: [] as RecordingKind[],
  statuses: [] as ProcessingStatus[],
  participants: [] as string[],
  pinnedOnly: false,
  dateRange: undefined as DateRangeFilter | undefined
};

export const useRecordingFilters = create<FilterState>((set) => ({
  ...initialState,
  setQuery: (query) => set({ query }),
  toggleTag: (tag) =>
    set((state) => ({
      tags: state.tags.includes(tag) ? state.tags.filter((t) => t !== tag) : [...state.tags, tag]
    })),
  toggleSource: (source) =>
    set((state) => ({
      sources: state.sources.includes(source)
        ? state.sources.filter((s) => s !== source)
        : [...state.sources, source]
    })),
  toggleKind: (kind) =>
    set((state) => ({
      kinds: state.kinds.includes(kind)
        ? state.kinds.filter((k) => k !== kind)
        : [...state.kinds, kind]
    })),
  toggleStatus: (status) =>
    set((state) => ({
      statuses: state.statuses.includes(status)
        ? state.statuses.filter((s) => s !== status)
        : [...state.statuses, status]
    })),
  toggleParticipant: (participant) =>
    set((state) => ({
      participants: state.participants.includes(participant)
        ? state.participants.filter((p) => p !== participant)
        : [...state.participants, participant]
    })),
  setPinnedOnly: (pinnedOnly) => set({ pinnedOnly }),
  setDateRange: (dateRange) => set({ dateRange }),
  reset: () => set(initialState)
}));
