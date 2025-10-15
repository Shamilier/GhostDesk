import { Button } from "@/components/ui/button";
import { mockCollections } from "@/lib/mock-data";
import { Shield, Globe2, Bell, Key, Link as LinkIcon } from "lucide-react";

export default function SettingsPage() {
  return (
    <div className="space-y-8">
      <header className="rounded-3xl border border-white/5 bg-surface/80 p-8 shadow-subtle">
        <h1 className="text-2xl font-semibold text-white">Настройки</h1>
        <p className="mt-2 text-sm text-white/60">Управляйте профилем, рабочим пространством и интеграциями.</p>
      </header>
      <section className="grid gap-6 lg:grid-cols-2">
        <div className="space-y-4 rounded-3xl border border-white/5 bg-white/5 p-6">
          <h2 className="text-lg font-semibold text-white">Профиль</h2>
          <div className="space-y-3 text-sm text-white/70">
            <label className="grid gap-1">
              <span>Имя</span>
              <input className="rounded-xl border border-white/10 bg-white/5 px-3 py-2 text-sm text-white focus:border-accent/50 focus:outline-none" defaultValue="Алексей Петров" />
            </label>
            <label className="grid gap-1">
              <span>Часовой пояс</span>
              <select className="rounded-xl border border-white/10 bg-white/5 px-3 py-2 text-sm text-white focus:border-accent/50 focus:outline-none">
                <option>UTC+3 (Москва)</option>
                <option>UTC+1 (Берлин)</option>
              </select>
            </label>
            <Button variant="primary" size="sm" className="text-sm">Сохранить</Button>
          </div>
        </div>
        <div className="space-y-4 rounded-3xl border border-white/5 bg-white/5 p-6">
          <h2 className="flex items-center gap-2 text-lg font-semibold text-white">
            <Shield className="h-4 w-4 text-accent" /> Workspace
          </h2>
          <p className="text-sm text-white/70">Доменные правила, квоты хранения и политика удаления.</p>
          <ul className="space-y-2 text-sm text-white/70">
            {mockCollections.map((collection) => (
              <li key={collection.id} className="flex items-center justify-between rounded-xl border border-white/10 bg-black/20 px-4 py-3">
                <span>{collection.name}</span>
                <span className="text-xs text-white/40">{collection.count} записей</span>
              </li>
            ))}
          </ul>
          <Button variant="ghost" size="sm" className="gap-2 text-xs text-white/80">
            <Key className="h-4 w-4" /> Управление доступом
          </Button>
        </div>
        <div className="space-y-4 rounded-3xl border border-white/5 bg-white/5 p-6">
          <h2 className="flex items-center gap-2 text-lg font-semibold text-white">
            <Bell className="h-4 w-4 text-accent" /> Уведомления
          </h2>
          <div className="space-y-3 text-sm text-white/70">
            {[
              "Обработка завершена",
              "Готово резюме",
              "Оставлена новая заметка"
            ].map((label) => (
              <label key={label} className="flex items-center justify-between rounded-xl border border-white/10 bg-black/20 px-4 py-3">
                <span>{label}</span>
                <input type="checkbox" defaultChecked className="h-4 w-4 accent-accent" />
              </label>
            ))}
          </div>
        </div>
        <div className="space-y-4 rounded-3xl border border-white/5 bg-white/5 p-6">
          <h2 className="flex items-center gap-2 text-lg font-semibold text-white">
            <Globe2 className="h-4 w-4 text-accent" /> Интеграции
          </h2>
          <p className="text-sm text-white/70">Настройте webhooks и API-ключи для Notion, Slack и календаря.</p>
          <div className="space-y-3 text-sm text-white/80">
            {[
              { name: "Notion", status: "Подключено" },
              { name: "Slack", status: "Ожидает настройку" },
              { name: "Webhook", status: "Активен" }
            ].map((integration) => (
              <div key={integration.name} className="flex items-center justify-between rounded-xl border border-white/10 bg-black/20 px-4 py-3">
                <span>{integration.name}</span>
                <span className="text-xs text-white/50">{integration.status}</span>
              </div>
            ))}
          </div>
          <Button variant="ghost" size="sm" className="gap-2 text-xs text-white/80">
            <LinkIcon className="h-4 w-4" /> Добавить вебхук
          </Button>
        </div>
      </section>
    </div>
  );
}
