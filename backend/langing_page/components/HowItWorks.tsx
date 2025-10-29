"use client";

import { motion } from "framer-motion";
import { ClipboardCheck, Keyboard, Mic } from "lucide-react";
import { GlassCard } from "./GlassCard";
import { SectionHeading } from "./SectionHeading";

const STEPS = [
  {
    title: "Запустите Ghost AI",
    description: "Откройте macOS-клиент и выберите, что слушать: системный звук, микрофон, отдельные приложения.",
    icon: Mic
  },
  {
    title: "Используйте хоткеи",
    description: "Подсказки появляются рядом с курсором. Спросите Ghost AI о фактах, шаблонах ответов или содержимом экрана.",
    icon: Keyboard
  },
  {
    title: "Сохраните важное",
    description: "Заметки и action items собираются автоматически. Экспорт в почту, мессенджер или CRM — в один клик.",
    icon: ClipboardCheck
  }
];

const NOTES = [
  {
    title: "Не мешает",
    body: "Ghost AI занимает 12% экрана и исчезает, когда вы его не трогаете."
  },
  {
    title: "Работает оффлайн",
    body: "Распознавание и подсказки запускаются локально, поэтому соединение не прерывает разговор."
  },
  {
    title: "Готов к пост-анализу",
    body: "Скоро появится расшифровка и AI-отчёты по записи. Всё в том же минимальном интерфейсе."
  }
];

export function HowItWorks() {
  return (
    <section id="workflow" className="relative mx-auto mt-32 w-full max-w-6xl px-4 sm:px-6">
      <SectionHeading
        eyebrow="Как работает"
        title="Три шага, чтобы Ghost AI был рядом на каждом звонке"
        description="Интерфейс остаётся минимальным: включите слушание, вызовите подсказку, сохраните итоги. Остальное Ghost AI берёт на себя."
        align="left"
      />
      <div className="mt-16 grid gap-12 lg:grid-cols-[1.1fr,0.9fr] lg:items-start">
        <div className="grid gap-4 sm:grid-cols-2">
          {STEPS.map((step, index) => {
            const Icon = step.icon;
            return (
              <GlassCard key={step.title} className="h-full">
                <motion.div
                  className="flex h-full flex-col gap-4"
                  initial={{ opacity: 0, y: 18 }}
                  whileInView={{ opacity: 1, y: 0 }}
                  viewport={{ once: true, amount: 0.3 }}
                  transition={{ delay: index * 0.05, duration: 0.45, ease: [0.4, 0, 0.2, 1] }}
                >
                  <span className="inline-flex h-10 w-10 items-center justify-center rounded-2xl bg-white/10 text-white">
                    <Icon className="h-5 w-5" />
                  </span>
                  <span className="text-xs uppercase tracking-[0.32em] text-white/40">Шаг {index + 1}</span>
                  <h3 className="text-lg font-semibold text-white">{step.title}</h3>
                  <p className="text-sm leading-relaxed text-white/65">{step.description}</p>
                </motion.div>
              </GlassCard>
            );
          })}
        </div>
        <div className="space-y-4">
          {NOTES.map((note, index) => (
            <motion.div
              key={note.title}
              className="rounded-3xl border border-white/10 bg-white/5 p-6 text-left"
              initial={{ opacity: 0, y: 18 }}
              whileInView={{ opacity: 1, y: 0 }}
              viewport={{ once: true, amount: 0.3 }}
              transition={{ delay: index * 0.05, duration: 0.45, ease: [0.4, 0, 0.2, 1] }}
            >
              <h3 className="text-base font-semibold text-white sm:text-lg">{note.title}</h3>
              <p className="mt-2 text-sm text-white/65">{note.body}</p>
            </motion.div>
          ))}
        </div>
      </div>
    </section>
  );
}
