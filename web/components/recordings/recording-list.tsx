"use client";

import { useMemo, useState } from "react";
import { FilterBar } from "@/components/recordings/filter-bar";
import { RecordingCard } from "@/components/recordings/recording-card";
import { Button } from "@/components/ui/button";
import { mockRecordings } from "@/lib/mock-data";
import { parseSearchQuery, matchesSearchQuery } from "@/lib/search";
import { useRecordingFilters } from "@/store/use-recording-filters";

const PAGE_SIZE = 24;

export function RecordingList() {
  const { query, tags, sources, statuses, kinds, participants, pinnedOnly, dateRange } = useRecordingFilters();
  const [visibleCount, setVisibleCount] = useState(PAGE_SIZE);

  const parsed = useMemo(() => parseSearchQuery(query), [query]);

  const filtered = useMemo(() => {
    return mockRecordings
      .filter((recording) => matchesSearchQuery(recording, parsed))
      .filter((recording) => {
        if (tags.length > 0 && !tags.every((tag) => recording.tags.includes(tag))) {
          return false;
        }
        if (sources.length > 0 && !sources.includes(recording.source)) {
          return false;
        }
        if (statuses.length > 0 && !statuses.includes(recording.status)) {
          return false;
        }
        if (kinds.length > 0 && !kinds.includes(recording.kind)) {
          return false;
        }
        if (participants.length > 0 && !participants.every((participant) => recording.participants.includes(participant))) {
          return false;
        }
        if (pinnedOnly && !recording.pinned) {
          return false;
        }
        if (dateRange?.from && new Date(recording.createdAt) < new Date(dateRange.from)) {
          return false;
        }
        if (dateRange?.to && new Date(recording.createdAt) > new Date(dateRange.to)) {
          return false;
        }
        return true;
      })
      .sort((a, b) => new Date(b.createdAt).getTime() - new Date(a.createdAt).getTime());
  }, [dateRange?.from, dateRange?.to, kinds, participants, parsed, pinnedOnly, sources, statuses, tags]);

  const visibleRecordings = filtered.slice(0, visibleCount);

  return (
    <div className="space-y-6">
      <FilterBar />
      <div className="flex items-center justify-between text-sm text-white/60">
        <span>Найдено записей: {filtered.length}</span>
        <span>
          Фильтры: {tags.length} тегов · {sources.length} источников · {participants.length} участников
        </span>
      </div>
      <div className="grid gap-4">
        {visibleRecordings.map((recording) => (
          <RecordingCard key={recording.id} recording={recording} />
        ))}
        {visibleRecordings.length === 0 && (
          <div className="rounded-2xl border border-dashed border-white/10 bg-white/5 p-12 text-center text-white/60">
            Записей не найдено. Загрузите первую запись или измените фильтры.
          </div>
        )}
      </div>
      {visibleCount < filtered.length && (
        <div className="flex justify-center">
          <Button variant="ghost" size="lg" className="text-white/80" onClick={() => setVisibleCount((count) => count + PAGE_SIZE)}>
            Загрузить ещё {Math.min(PAGE_SIZE, filtered.length - visibleCount)}
          </Button>
        </div>
      )}
    </div>
  );
}
