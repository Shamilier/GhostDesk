import { mockCollections, mockRecordings } from "@/lib/mock-data";
import { formatDate, formatDuration } from "@/lib/utils";
import Link from "next/link";
import { FolderOpen, ListChecks } from "lucide-react";

export default function CollectionsPage() {
  const grouped = mockCollections.map((collection) => ({
    ...collection,
    recordings: mockRecordings.slice(0, collection.count)
  }));

  return (
    <div className="space-y-8">
      <header className="rounded-3xl border border-white/5 bg-surface/80 p-8 shadow-subtle">
        <h1 className="text-2xl font-semibold text-white">Коллекции</h1>
        <p className="mt-2 text-sm text-white/60">Группируйте записи вручную и через смарт-правила.</p>
      </header>
      <section className="grid gap-6 lg:grid-cols-2">
        {grouped.map((collection) => (
          <div key={collection.id} className="space-y-4 rounded-3xl border border-white/5 bg-white/5 p-6">
            <div className="flex items-center justify-between">
              <div>
                <h2 className="flex items-center gap-2 text-lg font-semibold text-white">
                  {collection.type === "smart" ? <ListChecks className="h-4 w-4 text-accent" /> : <FolderOpen className="h-4 w-4 text-accent" />}
                  {collection.name}
                </h2>
                {collection.description && <p className="text-sm text-white/60">{collection.description}</p>}
              </div>
              <span className="rounded-full bg-white/10 px-3 py-1 text-xs text-white/60">{collection.count} записей</span>
            </div>
            <div className="space-y-2 text-sm text-white/70">
              {collection.recordings.slice(0, 4).map((recording) => (
                <Link
                  key={recording.id}
                  href={`/recordings/${recording.id}`}
                  className="flex items-center justify-between rounded-xl border border-white/10 bg-black/20 px-4 py-3 transition hover:border-accent/40 hover:text-white"
                >
                  <span>{recording.title}</span>
                  <span className="text-xs text-white/50">{formatDate(new Date(recording.createdAt))} · {formatDuration(recording.durationSeconds)}</span>
                </Link>
              ))}
            </div>
          </div>
        ))}
      </section>
    </div>
  );
}
