import { mockRecordings } from "@/lib/mock-data";
import { parseSearchQuery, matchesSearchQuery, extractBestSnippet } from "@/lib/search";
import { formatDate, formatMilliseconds } from "@/lib/utils";
import Link from "next/link";
import { Search, Sparkles } from "lucide-react";

export default function SearchPage({ searchParams }: { searchParams: { q?: string } }) {
  const query = searchParams.q ?? "";
  const parsed = parseSearchQuery(query);
  const results = query
    ? mockRecordings
        .filter((recording) => matchesSearchQuery(recording, parsed))
        .slice(0, 50)
    : [];

  return (
    <div className="space-y-8">
      <header className="rounded-3xl border border-white/5 bg-surface/80 p-8 shadow-subtle">
        <h1 className="text-2xl font-semibold text-white">Поиск</h1>
        <p className="mt-2 text-sm text-white/60">
          Используйте ⌘K для быстрого доступа или введите запрос с операторами: <code className="rounded bg-white/10 px-1">tag:</code>, <code className="rounded bg-white/10 px-1">speaker:</code>, <code className="rounded bg-white/10 px-1">before:</code>, <code className="rounded bg-white/10 px-1">duration:&gt;30m</code>.
        </p>
        <form className="mt-4 flex items-center gap-3">
          <div className="relative flex-1">
            <Search className="pointer-events-none absolute left-4 top-1/2 h-4 w-4 -translate-y-1/2 text-white/40" />
            <input
              name="q"
              defaultValue={query}
              placeholder="Например: tag:questions source:zoom speaker:alice"
              className="h-12 w-full rounded-full border border-white/10 bg-white/5 pl-12 pr-4 text-sm text-white placeholder:text-white/40 focus:border-accent/60 focus:outline-none"
            />
          </div>
          <button className="rounded-full bg-accent px-5 py-2 text-sm font-semibold text-black">Искать</button>
        </form>
      </header>
      <section className="space-y-3">
        <h2 className="text-sm font-semibold uppercase tracking-wide text-white/50">Результаты</h2>
        {query === "" && (
          <div className="rounded-2xl border border-dashed border-white/10 bg-white/5 p-8 text-sm text-white/60">
            Введите запрос или нажмите <kbd className="rounded bg-white/10 px-2">⌘K</kbd>, чтобы открыть глобальное меню.
          </div>
        )}
        {query !== "" && results.length === 0 && (
          <div className="rounded-2xl border border-dashed border-white/10 bg-white/5 p-8 text-sm text-white/60">
            Ничего не найдено. Попробуйте изменить теги или период.
          </div>
        )}
        <div className="space-y-4">
          {results.map((recording) => {
            const snippet = extractBestSnippet(recording, parsed.terms);
            return (
              <Link
                key={recording.id}
                href={`/recordings/${recording.id}`}
                className="block rounded-2xl border border-white/5 bg-white/5 p-5 transition hover:border-accent/40 hover:bg-accent/5"
              >
                <div className="flex items-center justify-between text-sm text-white/60">
                  <span>{formatDate(new Date(recording.createdAt))}</span>
                  <span>{recording.source.toUpperCase()}</span>
                </div>
                <h3 className="mt-2 text-lg font-semibold text-white">{recording.title}</h3>
                <p className="mt-2 text-sm text-white/70">{snippet.snippet.replace(/\[\[|\]\]/g, "")}</p>
                {snippet.atMs > 0 && (
                  <span className="mt-3 inline-flex items-center gap-2 text-xs text-accent">
                    <Sparkles className="h-3.5 w-3.5" /> Перейти к {formatMilliseconds(snippet.atMs)}
                  </span>
                )}
              </Link>
            );
          })}
        </div>
      </section>
    </div>
  );
}
