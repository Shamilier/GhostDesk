"use client";

import { ChangeEvent } from "react";
import { FilterPill } from "@/components/ui/filter-pill";
import { Button } from "@/components/ui/button";
import { useRecordingFilters } from "@/store/use-recording-filters";
import { mockRecordings, tags as availableTags, participantsSet } from "@/lib/mock-data";
import type { RecordingKind } from "@/lib/types";
import { Search, Tag } from "lucide-react";

const sources = [
  { label: "Zoom", value: "zoom" },
  { label: "Meet", value: "meet" },
  { label: "Teams", value: "teams" },
  { label: "Локально", value: "local" }
] as const;

const statuses = [
  { label: "Готово", value: "ready" },
  { label: "Обработка", value: "processing" }
] as const;

const kinds: { label: string; value: RecordingKind }[] = [
  { label: "Встречи", value: "meeting" },
  { label: "Лекции", value: "lecture" },
  { label: "Мастер-классы", value: "workshop" }
];

export function FilterBar() {
  const {
    query,
    tags,
    sources: sourceFilters,
    statuses: statusFilters,
    kinds: kindFilters,
    participants,
    pinnedOnly,
    setQuery,
    toggleTag,
    toggleSource,
    toggleStatus,
    toggleKind,
    toggleParticipant,
    setPinnedOnly,
    reset
  } = useRecordingFilters();

  const onSearchChange = (event: ChangeEvent<HTMLInputElement>) => {
    setQuery(event.target.value);
  };

  return (
    <section className="space-y-4 rounded-2xl border border-white/5 bg-surface/70 p-4 shadow-subtle">
      <div className="flex flex-wrap items-center gap-3">
        <div className="relative flex-1 min-w-[220px]">
          <Search className="pointer-events-none absolute left-4 top-1/2 h-4 w-4 -translate-y-1/2 text-white/40" />
          <input
            value={query}
            onChange={onSearchChange}
            placeholder="Поиск по заголовкам, заметкам, tag:…"
            className="h-10 w-full rounded-full border border-white/10 bg-white/5 pl-12 pr-4 text-sm text-white placeholder:text-white/40 focus:border-accent/60 focus:outline-none"
          />
        </div>
        <Button variant="ghost" size="sm" className="text-xs text-white/60" onClick={reset}>
          Сбросить фильтры
        </Button>
        <FilterPill label="Закреплённые" active={pinnedOnly} onClick={() => setPinnedOnly(!pinnedOnly)} />
      </div>
      <div className="flex flex-wrap gap-2">
        {statuses.map((status) => (
          <FilterPill
            key={status.value}
            label={status.label}
            active={statusFilters.includes(status.value)}
            onClick={() => toggleStatus(status.value)}
          />
        ))}
        {sources.map((source) => (
          <FilterPill
            key={source.value}
            label={source.label}
            active={sourceFilters.includes(source.value)}
            onClick={() => toggleSource(source.value)}
          />
        ))}
        {kinds.map((kind) => (
          <FilterPill
            key={kind.value}
            label={kind.label}
            active={kindFilters.includes(kind.value)}
            onClick={() => toggleKind(kind.value)}
          />
        ))}
      </div>
      <div className="space-y-2">
        <p className="text-xs font-semibold uppercase tracking-wide text-white/40">Популярные теги</p>
        <div className="flex flex-wrap gap-2">
          {availableTags.slice(0, 12).map((tag) => (
            <button
              key={tag}
              onClick={() => toggleTag(tag)}
              className={`inline-flex items-center gap-2 rounded-full border px-3 py-1.5 text-xs ${
                tags.includes(tag)
                  ? "border-accent/50 bg-accent/10 text-accent"
                  : "border-white/10 bg-white/5 text-white/60 hover:text-white"
              }`}
            >
              <Tag className="h-3.5 w-3.5" />
              {tag}
              <span className="rounded-full bg-black/40 px-1.5 text-[10px] text-white/60">
                {mockRecordings.filter((recording) => recording.tags.includes(tag)).length}
              </span>
            </button>
          ))}
        </div>
      </div>
      <div className="space-y-2">
        <p className="text-xs font-semibold uppercase tracking-wide text-white/40">Участники</p>
        <div className="flex flex-wrap gap-2">
          {participantsSet.slice(0, 10).map((person) => (
            <FilterPill
              key={person}
              label={person}
              active={participants.includes(person)}
              onClick={() => toggleParticipant(person)}
            />
          ))}
        </div>
      </div>
    </section>
  );
}
