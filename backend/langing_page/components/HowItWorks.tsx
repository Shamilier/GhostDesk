"use client";

import { motion } from "framer-motion";
import { Cable, Laptop2, MessagesSquare, PenTool } from "lucide-react";
import { GlassCard } from "./GlassCard";
import { SectionHeading } from "./SectionHeading";

const STEPS = [
  {
    title: "Подключите источники",
    description: "Выберите системный звук, микрофон и экран. Ghost AI подстраивается под ваш сетап за 30 секунд.",
    icon: Cable,
    result: "Готовый звуковой контур"
  },
  {
    title: "Во время разговора",
    description:
      "Ghost AI транскрибирует и подсказывает в реальном времени. Подсказки появляются рядом с курсором и не перекрывают интерфейсы.",
    icon: MessagesSquare,
    result: "Подсказки, заметки и тайм-коды"
  },
  {
    title: "После звонка",
    description:
      "AI собирает итоги, задачи, цитаты и распределяет их по папкам. Вы выбираете, что отправить в CRM или командный чат.",
    icon: PenTool,
    result: "Конспект + action items"
  },
  {
    title: "В архиве",
    description:
      "Поиск по людям, темам и цитатам. Можно запросить AI-аналитику, построить дайджест или выгрузить данные в Notion.",
    icon: Laptop2,
    result: "Глубокие инсайты и память"
  }
];

const SUPPORTING_POINTS = [
  {
    heading: "Прозрачный контроль",
    copy: "Вы сами решаете, что записывать. Ghost AI уважает приватные окна, а локальные фильтры отключают запись в один клик."
  },
  {
    heading: "Эффект присутствия",
    copy: "Подсказки появляются мягко, без всплывающих окон и навязчивых вспышек. Вы концентрируетесь на разговоре."
  }
];

export function HowItWorks() {
  return (
    <section id="how" className="relative mx-auto mt-32 w-full max-w-6xl px-4 sm:px-6">
      <div className="grid gap-16 lg:grid-cols-[1.02fr,0.98fr] lg:items-start">
        <div className="space-y-10">
          <SectionHeading
            eyebrow="Как это работает"
            title={
              <>
                Один запуск — и Ghost AI ведёт вас через весь цикл встречи
              </>
            }
            description="Весь путь — от подключения до архивирования — происходит в фоне. Ghost AI остаётся невидимым, но помогает на каждом шаге."
            align="left"
          />
          <div className="grid gap-5">
            {SUPPORTING_POINTS.map((point, index) => (
              <motion.div
                key={point.heading}
                className="rounded-3xl border border-white/10 bg-white/5 p-6 text-left"
                initial={{ opacity: 0, y: 18 }}
                whileInView={{ opacity: 1, y: 0 }}
                viewport={{ once: true, amount: 0.3 }}
                transition={{ delay: index * 0.06, duration: 0.5, ease: [0.4, 0, 0.2, 1] }}
              >
                <h3 className="text-base font-semibold text-white sm:text-lg">{point.heading}</h3>
                <p className="mt-2 text-sm leading-relaxed text-white/75">{point.copy}</p>
              </motion.div>
            ))}
          </div>
          <GlassCard className="relative overflow-hidden">
            <div className="relative z-10 space-y-4 text-left">
              <span className="text-xs uppercase tracking-[0.32em] text-white/40">Что видит команда</span>
              <h3 className="text-xl font-semibold text-white">Общий журнал Ghost AI</h3>
              <p className="text-sm text-white/75">
                Каждая встреча сохраняется в единую ленту: тайм-коды, решения, action items и заметки. Можно фильтровать по людям и темам.
              </p>
              <div className="grid gap-3 text-sm text-white/70">
                <div className="flex items-center justify-between rounded-2xl border border-white/10 bg-white/5 px-4 py-3">
                  <span>UX Interview — 12:00</span>
                  <span className="text-xs uppercase tracking-[0.3em] text-white/40">+4 инсайта</span>
                </div>
                <div className="flex items-center justify-between rounded-2xl border border-white/10 bg-white/5 px-4 py-3">
                  <span>Sales demo — 15:30</span>
                  <span className="text-xs uppercase tracking-[0.3em] text-white/40">CRM sync</span>
                </div>
              </div>
            </div>
          </GlassCard>
        </div>
        <div className="relative pl-10">
          <div className="absolute left-4 top-0 h-full w-px bg-gradient-to-b from-white/40 via-white/10 to-transparent" aria-hidden />
          <div className="space-y-8">
            {STEPS.map((step, index) => {
              const Icon = step.icon;
              return (
                <motion.div
                  key={step.title}
                  className="relative pl-10"
                  initial={{ opacity: 0, y: 24 }}
                  whileInView={{ opacity: 1, y: 0 }}
                  viewport={{ once: true, amount: 0.35 }}
                  transition={{ delay: index * 0.08, duration: 0.55, ease: [0.4, 0, 0.2, 1] }}
                >
                  <div className="absolute left-0 top-2 flex h-10 w-10 items-center justify-center rounded-full border border-white/15 bg-white/10 text-white">
                    <Icon className="h-5 w-5" />
                  </div>
                  <GlassCard className="ml-2 border-white/15 bg-white/5">
                    <div className="space-y-4">
                      <div className="flex items-center justify-between">
                        <span className="text-xs uppercase tracking-[0.32em] text-white/40">Шаг {index + 1}</span>
                        <span className="rounded-full border border-white/10 bg-white/10 px-3 py-1 text-[0.6rem] uppercase tracking-[0.28em] text-white/60">
                          {step.result}
                        </span>
                      </div>
                      <h3 className="text-lg font-semibold text-white">{step.title}</h3>
                      <p className="text-sm leading-relaxed text-white/75">{step.description}</p>
                    </div>
                  </GlassCard>
                </motion.div>
              );
            })}
          </div>
        </div>
      </div>
    </section>
  );
}
