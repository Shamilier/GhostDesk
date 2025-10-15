"use client";

import { useMemo, useRef, useState } from "react";
import Link from "next/link";
import { notFound } from "next/navigation";
import { Button } from "@/components/ui/button";
import { Badge } from "@/components/ui/badge";
import { mockRecordings } from "@/lib/mock-data";
import { formatDate, formatDuration, formatMilliseconds } from "@/lib/utils";
import { extractBestSnippet, parseSearchQuery } from "@/lib/search";
import {
  ArrowLeft,
  Download,
  ExternalLink,
  FileText,
  Highlighter,
  Search,
  Share2,
  Tag,
  Users
} from "lucide-react";

export default function RecordingPage({ params }: { params: { id: string } }) {
  const recording = mockRecordings.find((item) => item.id === params.id);
  if (!recording) {
    notFound();
  }

  const currentRecording = recording!;
  const videoRef = useRef<HTMLVideoElement | null>(null);
  const [activeSegmentId, setActiveSegmentId] = useState(currentRecording.transcript[0]?.id);
  const [transcriptQuery, setTranscriptQuery] = useState("");
  const [speed, setSpeed] = useState(1);

  const filteredSegments = useMemo(() => {
    if (!transcriptQuery) return currentRecording.transcript;
    const query = transcriptQuery.toLowerCase();
    return currentRecording.transcript.filter((segment) => segment.text.toLowerCase().includes(query));
  }, [currentRecording.transcript, transcriptQuery]);

  const queryParsed = useMemo(() => parseSearchQuery(transcriptQuery), [transcriptQuery]);

  function handleSeek(segmentStart: number, segmentId: string) {
    if (videoRef.current) {
      videoRef.current.currentTime = segmentStart / 1000;
      videoRef.current.play();
      setActiveSegmentId(segmentId);
    }
  }

  function onTimeUpdate() {
    const current = videoRef.current?.currentTime ?? 0;
    const segment = currentRecording.transcript.find(
      (item) => current * 1000 >= item.startMs && current * 1000 < item.endMs
    );
    if (segment && segment.id !== activeSegmentId) {
      setActiveSegmentId(segment.id);
    }
  }

  const exportOptions = [
    { label: "Markdown", description: "Инсайты + главы + заметки", format: "md" },
    { label: "PDF", description: "Подходит для внешних рассылок", format: "pdf" },
    { label: "SRT / VTT", description: "Субтитры для плееров", format: "srt" }
  ];

  const snippetFromSearch = transcriptQuery
    ? extractBestSnippet(currentRecording, queryParsed.terms)
    : null;

  return (
    <div className="space-y-8">
      <div className="flex flex-wrap items-center justify-between gap-4">
        <Link href="/" className="inline-flex items-center gap-2 text-sm text-white/60 hover:text-white">
          <ArrowLeft className="h-4 w-4" /> Вернуться к истории
        </Link>
        <div className="flex flex-wrap gap-2">
          <Button variant="ghost" size="sm" className="gap-1 text-xs text-white/80">
            <Share2 className="h-3.5 w-3.5" /> Поделиться
          </Button>
          <Button variant="ghost" size="sm" className="gap-1 text-xs text-white/80">
            <Download className="h-3.5 w-3.5" /> Экспорт
          </Button>
        </div>
      </div>
      <header className="flex flex-col gap-6 rounded-3xl border border-white/5 bg-surface/80 p-6 shadow-subtle">
        <div className="flex flex-wrap items-start justify-between gap-4">
          <div className="space-y-2">
            <h1 className="text-2xl font-semibold text-white">{currentRecording.title}</h1>
            <p className="text-sm text-white/60">
              {formatDate(new Date(currentRecording.createdAt))} · {currentRecording.source.toUpperCase()} · {formatDuration(currentRecording.durationSeconds)}
            </p>
            <div className="flex flex-wrap gap-2">
              {currentRecording.tags.map((tag, index) => (
                <Badge key={tag} index={index}>
                  {tag}
                </Badge>
              ))}
            </div>
          </div>
          <div className="rounded-2xl border border-white/5 bg-white/5 p-4 text-xs text-white/70">
            <div className="flex items-center gap-2">
              <Users className="h-3.5 w-3.5 text-accent" />
              Участники
            </div>
            <p className="mt-1 text-sm text-white/80">{currentRecording.participants.join(", ")}</p>
            <div className="mt-3 flex flex-wrap gap-2 text-xs text-white/50">
              <span>Слова: {currentRecording.transcript.reduce((acc, segment) => acc + (segment.words?.length ?? 0), 0)}</span>
              <span>·</span>
              <span>Размер: {(currentRecording.sizeBytes / (1024 * 1024)).toFixed(1)} МБ</span>
            </div>
          </div>
        </div>
        <div className="grid gap-6 lg:grid-cols-[2fr_1fr]">
          <div className="space-y-4">
            <div className="overflow-hidden rounded-2xl border border-white/10 bg-black/60">
              <video
                ref={videoRef}
                controls
                onTimeUpdate={onTimeUpdate}
                className="aspect-video w-full"
                poster={currentRecording.thumbnailUrl}
                src="https://storage.googleapis.com/coverr-main/mp4/Mt_Baker.mp4"
              />
            </div>
            <div className="flex flex-wrap items-center gap-3 text-xs text-white/60">
              <span>Скорость:</span>
              {[0.75, 1, 1.25, 1.5, 2].map((value) => (
                <button
                  key={value}
                  onClick={() => {
                    setSpeed(value);
                    if (videoRef.current) {
                      videoRef.current.playbackRate = value;
                    }
                  }}
                  className={`rounded-full border px-3 py-1 ${
                    speed === value ? "border-accent/50 bg-accent/10 text-accent" : "border-white/10 bg-white/5"
                  }`}
                >
                  {value}×
                </button>
              ))}
              <span className="ml-auto flex items-center gap-2 text-white/50">
                <Tag className="h-3.5 w-3.5" /> Авто-теги · ручное редактирование доступно
              </span>
            </div>
          </div>
          <aside className="space-y-4 rounded-2xl border border-white/5 bg-white/5 p-4 text-sm text-white/70">
            <div className="space-y-2">
              <h2 className="text-base font-semibold text-white">TL;DR</h2>
              <p>{currentRecording.insights.summary}</p>
            </div>
            <div className="space-y-2">
              <h3 className="text-sm font-semibold text-white">Action items</h3>
              <ul className="space-y-1 text-sm text-white/80">
                {currentRecording.insights.actionItems.map((item) => (
                  <li key={item} className="flex items-start gap-2">
                    <span className="mt-1 h-1.5 w-1.5 rounded-full bg-accent" />
                    {item}
                  </li>
                ))}
              </ul>
            </div>
            <div className="space-y-2">
              <h3 className="text-sm font-semibold text-white">Главы</h3>
              <ul className="space-y-2 text-sm text-white/80">
                {currentRecording.insights.chapters.map((chapter) => (
                <li key={chapter.title} className="flex items-center justify-between">
                  <button
                    onClick={() => handleSeek(chapter.startMs, chapter.title)}
                    className="text-left text-white/80 hover:text-white"
                  >
                    {chapter.title}
                  </button>
                  <span className="font-mono text-xs text-white/50">{formatMilliseconds(chapter.startMs)}</span>
                </li>
              ))}
              </ul>
            </div>
            <div className="space-y-2">
              <h3 className="text-sm font-semibold text-white">Highlights</h3>
              <ul className="space-y-2 text-sm text-white/80">
                {currentRecording.insights.highlights.map((highlight) => (
                  <li key={highlight.quote} className="rounded-xl border border-white/5 bg-black/30 p-3">
                    <p className="text-white">“{highlight.quote}”</p>
                    <button
                      onClick={() => handleSeek(highlight.atMs, highlight.quote)}
                      className="mt-2 inline-flex items-center gap-2 text-xs text-accent"
                    >
                      <Highlighter className="h-3.5 w-3.5" /> {formatMilliseconds(highlight.atMs)}
                    </button>
                  </li>
                ))}
              </ul>
            </div>
            <div className="space-y-3">
              <h3 className="text-sm font-semibold text-white">Экспорт</h3>
              {exportOptions.map((option) => (
                <button
                  key={option.format}
                  className="flex w-full items-center justify-between rounded-xl border border-white/10 bg-white/5 px-4 py-3 text-left text-sm text-white/80 transition hover:border-accent/50 hover:text-white"
                >
                  <span>
                    <span className="font-medium text-white">{option.label}</span>
                    <p className="text-xs text-white/50">{option.description}</p>
                  </span>
                  <FileText className="h-4 w-4 text-accent" />
                </button>
              ))}
            </div>
          </aside>
        </div>
      </header>
      <section className="grid gap-6 lg:grid-cols-[2fr_1fr]">
        <div className="rounded-3xl border border-white/5 bg-surface/80 p-6 shadow-subtle">
          <div className="flex items-center gap-3">
            <div className="relative flex-1">
              <Search className="pointer-events-none absolute left-4 top-1/2 h-4 w-4 -translate-y-1/2 text-white/40" />
              <input
                value={transcriptQuery}
                onChange={(event) => setTranscriptQuery(event.target.value)}
                placeholder="Поиск внутри записи: speaker:me tag:решения"
                className="h-10 w-full rounded-full border border-white/10 bg-white/5 pl-12 pr-4 text-sm text-white placeholder:text-white/40 focus:border-accent/60 focus:outline-none"
              />
            </div>
            {snippetFromSearch && (
              <span className="hidden rounded-full bg-accent/10 px-3 py-1 text-xs text-accent lg:inline-flex">
                Jump к {formatMilliseconds(snippetFromSearch.atMs)}
              </span>
            )}
          </div>
          <div className="mt-6 space-y-2">
            {filteredSegments.map((segment) => (
              <button
                key={segment.id}
                onClick={() => handleSeek(segment.startMs, segment.id)}
                className={`w-full rounded-2xl border px-4 py-3 text-left transition ${
                  segment.id === activeSegmentId
                    ? "border-accent/60 bg-accent/10 text-white"
                    : "border-white/5 bg-white/5 text-white/70 hover:border-white/20 hover:text-white"
                }`}
              >
                <div className="flex items-center justify-between text-xs text-white/50">
                  <span>{segment.speaker}</span>
                  <span className="font-mono">{formatMilliseconds(segment.startMs)}</span>
                </div>
                <p className="mt-1 text-sm text-white/80">{segment.text}</p>
              </button>
            ))}
          </div>
        </div>
        <aside className="space-y-4 rounded-3xl border border-white/5 bg-surface/80 p-6 shadow-subtle">
          <div className="space-y-2">
            <h3 className="text-base font-semibold text-white">Заметки</h3>
            <ul className="space-y-3 text-sm text-white/80">
              {currentRecording.notes.map((note) => (
                <li key={note.id} className="rounded-2xl border border-white/10 bg-white/5 p-4">
                  <div className="flex items-center justify-between text-xs text-white/50">
                    <span>{note.author}</span>
                    <span>{note.createdAt.slice(0, 10)}</span>
                  </div>
                  <p className="mt-2 text-white/80">{note.body}</p>
                  {note.atMs && (
                    <button onClick={() => handleSeek(note.atMs!, note.id)} className="mt-3 inline-flex items-center gap-2 text-xs text-accent">
                      <ExternalLink className="h-3.5 w-3.5" /> {formatMilliseconds(note.atMs)}
                    </button>
                  )}
                  {note.isPrivate && <span className="mt-2 inline-flex rounded-full bg-black/40 px-2 py-1 text-[10px] text-white/60">Личная</span>}
                </li>
              ))}
            </ul>
          </div>
          <div className="rounded-2xl border border-dashed border-white/10 bg-white/5 p-4 text-sm text-white/60">
            <p>Командные заметки поддерживают упоминания (@name) и реакции. Уведомления приходят по почте.</p>
            <Button variant="ghost" size="sm" className="mt-3 gap-2 text-xs text-white/80">
              <Highlighter className="h-4 w-4" /> Добавить заметку
            </Button>
          </div>
        </aside>
      </section>
    </div>
  );
}
