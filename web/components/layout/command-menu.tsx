"use client";

import { Dialog, Transition } from "@headlessui/react";
import { Command } from "cmdk";
import Link from "next/link";
import { Fragment, useEffect, useMemo, useState, type ReactNode } from "react";
import { Clock, CornerDownLeft, Search } from "lucide-react";
import { mockRecordings } from "@/lib/mock-data";
import { formatMilliseconds } from "@/lib/utils";
import { extractBestSnippet, matchesSearchQuery, parseSearchQuery } from "@/lib/search";

function buildHighlightedNodes(text: string) {
  const parts = text.split(/(\[\[|\]\])/);
  if (parts.length === 1) {
    return text;
  }
  const nodes: ReactNode[] = [];
  let highlightMode = false;
  parts.forEach((part, index) => {
    if (part === "[[") {
      highlightMode = true;
      return;
    }
    if (part === "]]") {
      highlightMode = false;
      return;
    }
    if (!part) return;
    nodes.push(
      highlightMode ? (
        <mark key={`${part}-${index}`} className="rounded bg-accent/20 px-1 text-accent">
          {part}
        </mark>
      ) : (
        <Fragment key={`${part}-${index}`}>{part}</Fragment>
      )
    );
  });
  return nodes;
}

export function CommandMenu({
  open,
  onOpenChange,
  onSelectRecording
}: {
  open: boolean;
  onOpenChange: (open: boolean) => void;
  onSelectRecording: (id: string) => void;
}) {
  const [input, setInput] = useState("");

  useEffect(() => {
    function onKeyDown(event: KeyboardEvent) {
      if ((event.metaKey || event.ctrlKey) && event.key.toLowerCase() === "k") {
        event.preventDefault();
        onOpenChange(!open);
      }
      if (event.key === "Escape") {
        onOpenChange(false);
      }
    }

    window.addEventListener("keydown", onKeyDown);
    return () => window.removeEventListener("keydown", onKeyDown);
  }, [onOpenChange, open]);

  const parsed = useMemo(() => parseSearchQuery(input), [input]);

  const results = useMemo(() => {
    const matches = mockRecordings.filter((recording) => matchesSearchQuery(recording, parsed)).slice(0, 50);
    return matches.map((recording) => {
      const snippetInfo = extractBestSnippet(recording, parsed.terms);
      return {
        recording,
        snippet: snippetInfo.snippet,
        atMs: snippetInfo.atMs
      };
    });
  }, [parsed]);

  useEffect(() => {
    if (!open) {
      setInput("");
    }
  }, [open]);

  return (
    <Transition appear show={open} as={Fragment}>
      <Dialog as="div" className="relative z-40" onClose={onOpenChange}>
        <Transition.Child
          as={Fragment}
          enter="ease-out duration-150"
          enterFrom="opacity-0"
          enterTo="opacity-100"
          leave="ease-in duration-100"
          leaveFrom="opacity-100"
          leaveTo="opacity-0"
        >
          <div className="fixed inset-0 bg-black/50" />
        </Transition.Child>
        <div className="fixed inset-0 overflow-y-auto">
          <div className="flex min-h-full items-start justify-center p-4">
            <Transition.Child
              as={Fragment}
              enter="ease-out duration-150"
              enterFrom="opacity-0 scale-95"
              enterTo="opacity-100 scale-100"
              leave="ease-in duration-100"
              leaveFrom="opacity-100 scale-100"
              leaveTo="opacity-0 scale-95"
            >
              <Dialog.Panel className="w-full max-w-2xl overflow-hidden rounded-2xl border border-white/10 bg-surface shadow-subtle">
                <Command className="grid gap-2">
                  <div className="relative">
                    <Search className="pointer-events-none absolute left-4 top-3 h-4 w-4 text-white/40" />
                    <Command.Input
                      value={input}
                      onValueChange={setInput}
                      placeholder="Поиск: tag:questions speaker:alice before:2025-10-01"
                      className="w-full border-b border-white/5 bg-transparent py-3 pl-12 pr-4 text-sm text-white placeholder:text-white/40 focus:outline-none"
                    />
                  </div>
                  {input.length === 0 && (
                    <div className="flex flex-wrap gap-2 px-4 pb-3 text-xs text-white/40">
                      <span>Подсказки:</span>
                      <span className="rounded-full bg-white/5 px-2 py-1">tag:вопросы</span>
                      <span className="rounded-full bg-white/5 px-2 py-1">speaker:me</span>
                      <span className="rounded-full bg-white/5 px-2 py-1">duration:&gt;30m</span>
                      <span className="rounded-full bg-white/5 px-2 py-1">source:zoom</span>
                    </div>
                  )}
                  <Command.List className="max-h-96 overflow-y-auto">
                    {results.length === 0 ? (
                      <Command.Empty className="px-6 py-10 text-center text-sm text-white/50">
                        Нет совпадений. Попробуйте другие теги или даты.
                      </Command.Empty>
                    ) : (
                      results.map(({ recording, snippet, atMs }) => (
                        <Command.Item
                          key={recording.id}
                          value={recording.id}
                          onSelect={() => {
                            onSelectRecording(recording.id);
                            onOpenChange(false);
                          }}
                          className="group grid gap-2 border-b border-white/5 px-6 py-4 text-left text-sm text-white/80 last:border-none hover:bg-white/5 data-[selected=true]:bg-accent/10"
                        >
                          <Link href={`/recordings/${recording.id}`} className="grid gap-2" onClick={() => onOpenChange(false)}>
                            <div className="flex items-center justify-between">
                              <div className="flex items-center gap-2 text-white">
                                <Search className="h-4 w-4 text-accent" />
                                <span className="font-medium">{recording.title}</span>
                              </div>
                              <div className="flex items-center gap-2 text-xs text-white/50">
                                <span>{recording.source.toUpperCase()}</span>
                                <span>·</span>
                                <span>{new Date(recording.createdAt).toLocaleDateString()}</span>
                              </div>
                            </div>
                            <p className="line-clamp-2 text-sm text-white/70">{buildHighlightedNodes(snippet)}</p>
                            {atMs > 0 && (
                              <span className="inline-flex items-center gap-1 text-xs text-white/50">
                                <Clock className="h-3.5 w-3.5" />
                                Переход к {formatMilliseconds(atMs)}
                              </span>
                            )}
                          </Link>
                        </Command.Item>
                      ))
                    )}
                  </Command.List>
                  <div className="flex items-center justify-between border-t border-white/5 px-6 py-3 text-xs text-white/40">
                    <div className="flex items-center gap-2">
                      <CornerDownLeft className="h-3.5 w-3.5" />
                      Enter — открыть запись, Shift+Enter — новая вкладка
                    </div>
                    <div className="flex gap-2">
                      {["tag", "before", "after", "duration", "has"].map((token) => (
                        <span key={token} className="rounded-full bg-white/5 px-2 py-1">{token}:…</span>
                      ))}
                    </div>
                  </div>
                </Command>
              </Dialog.Panel>
            </Transition.Child>
          </div>
        </div>
      </Dialog>
    </Transition>
  );
}
