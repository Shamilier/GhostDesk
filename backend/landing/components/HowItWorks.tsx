"use client";

import { motion } from "framer-motion";
import { Cable, Laptop2, MessagesSquare, PenTool } from "lucide-react";
import { GlassCard } from "./GlassCard";
import { SectionHeading } from "./SectionHeading";

const STEPS = [
  {
    title: "Подключите источники",
    description: "Системный звук, микрофон, экран — один клик, и GhostDesk в курсе контекста.",
    icon: Cable
  },
  {
    title: "В разговоре",
    description: "GhostDesk транскрибирует и подсказывает в реальном времени прямо поверх вашего экрана.",
    icon: MessagesSquare
  },
  {
    title: "После звонка",
    description: "Авто-итоги, заметки, задачи и тайм-коды без ручной рутины.",
    icon: PenTool
  },
  {
    title: "В архиве",
    description: "Умный поиск, темы, участники и AI-анализ по запросу.",
    icon: Laptop2
  }
];

const SUPPORTING_POINTS = [
  {
    title: "Прозрачный контроль",
    copy: "Выбирайте, какие приложения слушать и что сохранять. Личные разговоры остаются личными.",
    accent: "Гибкие фильтры позволяют отключить запись в один клик."
  },
  {
    title: "Эффект присутствия",
    copy: "Подсказки появляются рядом с курсором и не перекрывают важный контент.",
    accent: "Ключевые формулировки выделены крупным шрифтом, чтобы вы не искали их глазами."
  },
  {
    title: "Память, которой можно доверять",
    copy: "После встречи доступен структурированный отчёт с задачами и цитатами.",
    accent: "Экспортируйте его в CRM или отправьте в командный чат за секунды."
  }
];

export function HowItWorks() {
  return (
    <section id="how" className="relative mx-auto mt-32 w-full max-w-6xl px-4 sm:px-6">
      <div className="grid gap-16 lg:grid-cols-[1.05fr,1fr] lg:items-start">
        <div className="space-y-10">
          <SectionHeading
            eyebrow="Как это работает"
            title={
              <>
                Включите GhostDesk один раз — и ведите диалог <span className="text-white/80">вместе с AI</span>
              </>
            }
            description="От подключения до архивирования — GhostDesk остаётся невидимым, но помогает на каждом шаге. Каждый этап оформлен отдельным блоком, поэтому вы всегда понимаете, что происходит."
            align="left"
          />
          <div className="grid gap-5">
            {SUPPORTING_POINTS.map((point, index) => (
              <motion.div
                key={point.title}
                className="rounded-3xl border border-white/10 bg-white/5 p-6 text-left"
                initial={{ opacity: 0, y: 20 }}
                whileInView={{ opacity: 1, y: 0 }}
                viewport={{ once: true, amount: 0.3 }}
                transition={{ delay: index * 0.06, duration: 0.5, ease: [0.4, 0, 0.2, 1] }}
              >
                <h3 className="text-base font-semibold text-white sm:text-lg">{point.title}</h3>
                <p className="mt-2 text-sm leading-relaxed text-white/70">{point.copy}</p>
                <p className="mt-3 text-sm font-medium text-white">{point.accent}</p>
              </motion.div>
            ))}
          </div>
        </div>
        <div className="grid grid-cols-1 gap-4 sm:grid-cols-2">
          {STEPS.map((step, index) => {
            const Icon = step.icon;
            return (
              <GlassCard key={step.title} className="h-full">
                <motion.div
                  className="flex h-full flex-col gap-4"
                  initial={{ opacity: 0, y: 16 }}
                  whileInView={{ opacity: 1, y: 0 }}
                  viewport={{ once: true, amount: 0.35 }}
                  transition={{ delay: index * 0.06, duration: 0.5, ease: [0.4, 0, 0.2, 1] }}
                >
                  <span className="inline-flex h-10 w-10 items-center justify-center rounded-full bg-white/10 text-white">
                    <Icon className="h-5 w-5" />
                  </span>
                  <div className="text-xs uppercase tracking-[0.3em] text-white/40">Шаг {index + 1}</div>
                  <div className="space-y-3">
                    <h3 className="text-lg font-semibold text-white">{step.title}</h3>
                    <p className="text-sm leading-relaxed text-white/70">{step.description}</p>
                  </div>
                </motion.div>
              </GlassCard>
            );
          })}
        </div>
      </div>
    </section>
  );
}
