import { RecordingList } from "@/components/recordings/recording-list";
import { Button } from "@/components/ui/button";
import { mockRecordings } from "@/lib/mock-data";
import { formatDate } from "@/lib/utils";
import { ArrowRight, Inbox, Sparkles } from "lucide-react";

export default function DashboardPage() {
  const lastProcessed = mockRecordings[0];
  return (
    <div className="space-y-8">
      <section className="rounded-3xl border border-white/5 bg-gradient-to-r from-surface via-surface to-surface/70 p-8 shadow-subtle">
        <div className="flex flex-wrap items-center justify-between gap-6">
          <div className="max-w-2xl space-y-3">
            <p className="inline-flex items-center gap-2 rounded-full bg-accent/10 px-3 py-1 text-xs font-semibold uppercase tracking-wide text-accent">
              <Sparkles className="h-3.5 w-3.5" /> GhostDesk Insights
            </p>
            <h1 className="text-3xl font-semibold leading-tight text-white">
              История встреч, лекций и экранов — с умными тегами, главами и заметками.
            </h1>
            <p className="text-sm text-white/70">
              Overlay на Mac остаётся инструментом захвата, а веб — место, где можно анализировать и делиться. Пробуйте глобальный поиск ⌘K и jump-листы по транскрипту.
            </p>
            <div className="flex flex-wrap gap-3 text-xs text-white/60">
              <span>Последняя запись: {formatDate(new Date(lastProcessed.createdAt))}</span>
              <span>·</span>
              <span>Всего минут: {(mockRecordings.reduce((acc, item) => acc + item.durationSeconds, 0) / 60).toFixed(0)}</span>
              <span>·</span>
              <span>Сгенерированных инсайтов: {mockRecordings.length}</span>
            </div>
          </div>
          <div className="flex flex-col gap-3 rounded-2xl border border-white/5 bg-white/5 p-4 text-sm text-white/70">
            <div className="flex items-center gap-2 text-white">
              <Inbox className="h-5 w-5 text-accent" />
              Очередь обработки
            </div>
            <p>3 записи в статусе «Обработка» · уведомление придёт в in-app и по email.</p>
            <Button variant="ghost" size="sm" className="self-start text-xs text-white/60">
              Смотреть все статусы
            </Button>
          </div>
        </div>
      </section>
      <RecordingList />
      <section className="grid gap-4 rounded-3xl border border-white/5 bg-surface/80 p-6 text-sm text-white/70 lg:grid-cols-3">
        <div className="space-y-2">
          <h2 className="text-base font-semibold text-white">Онбординг команды</h2>
          <p>Пригласите коллег домена, чтобы делиться заметками и упоминать людей прямо в транскрипте.</p>
          <Button variant="ghost" size="sm" className="gap-2 text-xs text-white/80">
            <ArrowRight className="h-4 w-4" /> Настроить workspace
          </Button>
        </div>
        <div className="space-y-2">
          <h2 className="text-base font-semibold text-white">Подключите overlay</h2>
          <p>Баннер с deep-link ghostdesk://auth?token=… поможет авторизовать десктопный клиент за секунды.</p>
          <Button variant="ghost" size="sm" className="gap-2 text-xs text-white/80">
            <ArrowRight className="h-4 w-4" /> Скопировать ссылку
          </Button>
        </div>
        <div className="space-y-2">
          <h2 className="text-base font-semibold text-white">Экспорт в Notion и Slack</h2>
          <p>Настройте вебхуки, чтобы отправлять TL;DR и action items прямо в рабочие каналы.</p>
          <Button variant="ghost" size="sm" className="gap-2 text-xs text-white/80">
            <ArrowRight className="h-4 w-4" /> Настроить интеграции
          </Button>
        </div>
      </section>
    </div>
  );
}
