"use client";

import { useState } from "react";
import { Button } from "@/components/ui/button";
import { CommandMenu } from "@/components/layout/command-menu";
import { Sidebar } from "@/components/layout/sidebar";
import { UploadDialog } from "@/components/panels/upload-dialog";
import { cn } from "@/lib/utils";
import { Bell, Menu, Search, UploadCloud } from "lucide-react";

export default function AppShell({ children }: { children: React.ReactNode }) {
  const [isCommandOpen, setIsCommandOpen] = useState(false);
  const [isUploadOpen, setIsUploadOpen] = useState(false);

  return (
    <div className="flex min-h-screen bg-background">
      <Sidebar onOpenUpload={() => setIsUploadOpen(true)} />
      <div className="flex flex-1 flex-col">
        <header className="sticky top-0 z-20 border-b border-white/5 bg-background/80 backdrop-blur">
          <div className="flex items-center justify-between px-4 py-4 lg:px-8">
            <div className="flex items-center gap-3">
              <button
                className="flex h-10 w-10 items-center justify-center rounded-full border border-white/10 text-white/60 hover:text-white focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-accent lg:hidden"
                onClick={() => setIsCommandOpen(true)}
                aria-label="Открыть поиск"
              >
                <Menu className="h-5 w-5" />
              </button>
              <button
                onClick={() => setIsCommandOpen(true)}
                className="hidden items-center gap-3 rounded-full border border-white/10 bg-white/5 px-4 py-2 text-sm text-white/70 transition hover:border-accent/40 hover:text-white focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-accent lg:flex"
              >
                <Search className="h-4 w-4" />
                <span>Поиск по всей базе</span>
                <kbd className="rounded border border-white/10 bg-white/5 px-2 py-0.5 text-xs text-white/50">⌘K</kbd>
              </button>
            </div>
            <div className="flex items-center gap-3">
              <Button
                variant="ghost"
                className="hidden items-center gap-2 text-sm text-white/80 lg:inline-flex"
                onClick={() => setIsUploadOpen(true)}
              >
                <UploadCloud className="h-4 w-4" /> Импорт
              </Button>
              <button
                className="relative flex h-10 w-10 items-center justify-center rounded-full border border-white/10 text-white/70 transition hover:border-white/30 hover:text-white focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-accent"
                aria-label="Уведомления"
              >
                <Bell className="h-5 w-5" />
                <span className="absolute right-2 top-2 h-2 w-2 rounded-full bg-accent"></span>
              </button>
            </div>
          </div>
        </header>
        <main className={cn("flex-1", "px-4 pb-12 pt-6 lg:px-8")}>{children}</main>
      </div>
      <CommandMenu open={isCommandOpen} onOpenChange={setIsCommandOpen} onSelectRecording={() => setIsCommandOpen(false)} />
      <UploadDialog open={isUploadOpen} onOpenChange={setIsUploadOpen} />
    </div>
  );
}
