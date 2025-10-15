"use client";

import { Dialog, Transition } from "@headlessui/react";
import { Fragment } from "react";
import { Button } from "@/components/ui/button";
import { Cloud, FileAudio, LinkIcon, UploadCloud } from "lucide-react";

const sources = [
  {
    title: "Загрузить файл",
    description: ".mp4, .mov, .m4a, .mp3",
    icon: UploadCloud
  },
  {
    title: "Подключить Zoom",
    description: "OAuth + автоматический импорт",
    icon: Cloud
  },
  {
    title: "Вставить ссылку",
    description: "Meet, Teams, YouTube",
    icon: LinkIcon
  },
  {
    title: "Системный звук",
    description: "Скринкасты и демо",
    icon: FileAudio
  }
];

export function UploadDialog({ open, onOpenChange }: { open: boolean; onOpenChange: (open: boolean) => void }) {
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
          <div className="flex min-h-full items-center justify-center p-4">
            <Transition.Child
              as={Fragment}
              enter="ease-out duration-150"
              enterFrom="opacity-0 scale-95"
              enterTo="opacity-100 scale-100"
              leave="ease-in duration-100"
              leaveFrom="opacity-100 scale-100"
              leaveTo="opacity-0 scale-95"
            >
              <Dialog.Panel className="w-full max-w-xl space-y-6 rounded-2xl border border-white/10 bg-surface p-8 shadow-subtle">
                <div>
                  <Dialog.Title className="text-lg font-semibold text-white">Импорт записи</Dialog.Title>
                  <Dialog.Description className="mt-1 text-sm text-white/60">
                    Поддерживаем локальные файлы и интеграции. Обработка до 5 сек для записи 1 час (PDF — асинхронно).
                  </Dialog.Description>
                </div>
                <div className="grid gap-3 sm:grid-cols-2">
                  {sources.map((source) => {
                    const Icon = source.icon;
                    return (
                      <button
                        key={source.title}
                        className="flex h-full flex-col gap-2 rounded-2xl border border-white/5 bg-white/5 p-4 text-left transition hover:border-accent/50 hover:bg-accent/5"
                      >
                        <span className="flex h-10 w-10 items-center justify-center rounded-full bg-accent/10 text-accent">
                          <Icon className="h-5 w-5" />
                        </span>
                        <div>
                          <p className="font-medium text-white">{source.title}</p>
                          <p className="text-sm text-white/60">{source.description}</p>
                        </div>
                      </button>
                    );
                  })}
                </div>
                <div className="flex flex-col gap-3 rounded-xl border border-white/5 bg-white/5 p-4">
                  <p className="text-sm text-white/70">Частичный импорт через overlay: обработка идёт в реальном времени. Deep-link в веб — ghostdesk://open?id=…</p>
                  <Button variant="ghost" className="self-start text-xs text-white/60" onClick={() => onOpenChange(false)}>
                    Закрыть
                  </Button>
                </div>
              </Dialog.Panel>
            </Transition.Child>
          </div>
        </div>
      </Dialog>
    </Transition>
  );
}
