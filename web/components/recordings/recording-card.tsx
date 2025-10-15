"use client";

import Link from "next/link";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { formatDate, formatDuration } from "@/lib/utils";
import type { Recording } from "@/lib/types";
import {
  ArrowUpRight,
  Download,
  Link2,
  MoreHorizontal,
  Pin,
  Play,
  Trash2
} from "lucide-react";

export function RecordingCard({ recording }: { recording: Recording }) {
  return (
    <article className="group grid grid-cols-[180px_1fr] gap-6 rounded-2xl border border-white/5 bg-surface/70 p-5 shadow-subtle transition hover:border-accent/40 hover:bg-surface">
      <div className="relative overflow-hidden rounded-xl">
        <img src={recording.thumbnailUrl} alt={recording.title} className="h-full w-full object-cover" />
        <span className="absolute left-3 top-3 inline-flex items-center gap-1 rounded-full bg-black/60 px-2 py-1 text-xs font-medium text-white/80">
          {recording.source.toUpperCase()}
        </span>
        <span className="absolute bottom-3 right-3 rounded-full bg-black/70 px-2 py-1 text-xs font-mono text-white">
          {formatDuration(recording.durationSeconds)}
        </span>
      </div>
      <div className="flex flex-col gap-4">
        <header className="flex flex-wrap items-start justify-between gap-3">
          <div className="space-y-1">
            <Link href={`/recordings/${recording.id}`} className="flex items-center gap-2 text-lg font-semibold text-white">
              <Play className="h-4 w-4 text-accent opacity-0 transition group-hover:opacity-100" />
              {recording.title}
            </Link>
            <p className="text-sm text-white/60">
              {formatDate(new Date(recording.createdAt))} · {recording.kind.toUpperCase()} · {recording.participants.join(", ")}
            </p>
          </div>
          <div className="flex items-center gap-2">
            <Button variant="ghost" size="sm" className="text-xs text-white/70">
              <Pin className="mr-1 h-3.5 w-3.5" />
              {recording.pinned ? "Открепить" : "Закрепить"}
            </Button>
            <button className="flex h-8 w-8 items-center justify-center rounded-full border border-white/10 text-white/60 hover:text-white">
              <MoreHorizontal className="h-4 w-4" />
            </button>
          </div>
        </header>
        <p className="line-clamp-2 text-sm text-white/70">{recording.summary}</p>
        <div className="flex flex-wrap gap-2">
          {recording.tags.map((tag, index) => (
            <Badge key={tag} index={index}>
              {tag}
            </Badge>
          ))}
        </div>
        <div className="flex flex-wrap items-center gap-3 text-xs text-white/50">
          <span>Состояние: {recording.status === "ready" ? "Готово" : "Обработка"}</span>
          <span>·</span>
          <span>Размер: {(recording.sizeBytes / (1024 * 1024)).toFixed(1)} МБ</span>
          <span>·</span>
          <span>Заметок: {recording.notes.length}</span>
        </div>
        <div className="flex flex-wrap gap-2">
          <Button asChild variant="primary" size="sm">
            <Link href={`/recordings/${recording.id}`} className="flex items-center gap-1">
              <ArrowUpRight className="h-3.5 w-3.5" /> Открыть
            </Link>
          </Button>
          <Button variant="ghost" size="sm" className="flex items-center gap-1 text-xs text-white/70">
            <Link2 className="h-3.5 w-3.5" /> Поделиться
          </Button>
          <Button variant="ghost" size="sm" className="flex items-center gap-1 text-xs text-white/70">
            <Download className="h-3.5 w-3.5" /> Экспорт
          </Button>
          <Button variant="ghost" size="sm" className="flex items-center gap-1 text-xs text-danger">
            <Trash2 className="h-3.5 w-3.5" /> В корзину
          </Button>
        </div>
      </div>
    </article>
  );
}
