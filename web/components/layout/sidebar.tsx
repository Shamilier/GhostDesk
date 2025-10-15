"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";
import { cn } from "@/lib/utils";
import { Button } from "@/components/ui/button";
import { CalendarRange, Clock3, Folder, History, Search, Settings, UploadCloud } from "lucide-react";
import { mockCollections } from "@/lib/mock-data";

const navItems = [
  { href: "/", label: "История", icon: History },
  { href: "/collections", label: "Коллекции", icon: Folder },
  { href: "/search", label: "Поиск", icon: Search },
  { href: "/settings", label: "Настройки", icon: Settings }
];

export function Sidebar({ onOpenUpload }: { onOpenUpload: () => void }) {
  const pathname = usePathname();

  return (
    <aside className="hidden lg:flex w-72 flex-col border-r border-white/5 bg-surface/60 backdrop-blur-xl">
      <div className="flex items-center justify-between px-6 py-6">
        <div>
          <p className="text-sm font-semibold text-white/60">GhostDesk</p>
          <h1 className="text-xl font-semibold text-white">Второй мозг</h1>
        </div>
        <span className="flex h-10 w-10 items-center justify-center rounded-full bg-accent/20 text-accent">
          <Clock3 className="h-5 w-5" />
        </span>
      </div>
      <div className="px-6">
        <Button variant="primary" size="lg" className="w-full" onClick={onOpenUpload}>
          <UploadCloud className="mr-2 h-4 w-4" /> Загрузить запись
        </Button>
      </div>
      <nav className="mt-8 flex-1 space-y-1 px-4">
        {navItems.map((item) => {
          const isActive = pathname === item.href || (item.href !== "/" && pathname.startsWith(item.href));
          const Icon = item.icon;
          return (
            <Link
              key={item.href}
              href={item.href}
              className={cn(
                "flex items-center gap-3 rounded-xl px-4 py-3 text-sm font-medium transition",
                isActive ? "bg-accent/10 text-accent" : "text-white/70 hover:bg-white/5 hover:text-white"
              )}
            >
              <Icon className="h-4 w-4" />
              {item.label}
            </Link>
          );
        })}
      </nav>
      <div className="border-t border-white/5 px-6 py-6">
        <h2 className="text-xs font-semibold uppercase tracking-wide text-white/40">Коллекции</h2>
        <div className="mt-3 space-y-2">
          {mockCollections.map((collection) => (
            <div key={collection.id} className="flex items-center justify-between rounded-lg border border-white/5 bg-white/5 px-3 py-2 text-sm text-white/70">
              <div>
                <p className="font-medium text-white/80">{collection.name}</p>
                <p className="text-xs text-white/50">
                  {collection.type === "smart" ? (
                    <span className="inline-flex items-center gap-1">
                      <CalendarRange className="h-3 w-3" /> Смарт
                    </span>
                  ) : (
                    "Папка"
                  )}
                </p>
              </div>
              <span className="text-xs font-semibold text-white/40">{collection.count}</span>
            </div>
          ))}
        </div>
      </div>
    </aside>
  );
}
