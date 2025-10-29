"use client";

import { AnimatePresence, motion, useReducedMotion } from "framer-motion";
import { useEffect, useState } from "react";
import { GlassCard } from "./GlassCard";

const TESTIMONIALS = [
  {
    quote:
      "Ghost AI стал вторым мозгом на собеседованиях. Подсказки с примерными ответами и тайм-коды экономят часы подготовки.",
    name: "Анна Морозова",
    role: "Head of Operations, Nimbly",
    metric: "-47% времени на разбор звонков"
  },
  {
    quote:
      "Команде продаж стало легче вести диалоги: Ghost AI подсказывает, когда углубиться в боли клиента и что записать в CRM.",
    name: "Вадим Сафронов",
    role: "Product Lead, Quantum",
    metric: "+32% закрытых задач в спринте"
  },
  {
    quote:
      "Лекции перестали теряться. Через пару минут после созвона есть транскрипт, конспект и подборка инсайтов для студентов.",
    name: "Мария Крылова",
    role: "Founder, iTeach",
    metric: "NPS 73 вместо 41"
  }
];

export function Testimonials() {
  const [index, setIndex] = useState(0);
  const shouldReduceMotion = useReducedMotion();

  useEffect(() => {
    if (shouldReduceMotion) return;
    const id = window.setInterval(() => {
      setIndex(prev => (prev + 1) % TESTIMONIALS.length);
    }, 7000);

    return () => window.clearInterval(id);
  }, [shouldReduceMotion]);

  const active = TESTIMONIALS[index];

  return (
    <section className="relative mx-auto mt-28 w-full max-w-5xl px-4 sm:px-6">
      <GlassCard className="overflow-hidden p-0">
        <div className="grid gap-0 md:grid-cols-[1.1fr,0.9fr]">
          <div className="relative border-b border-white/10 p-8 md:border-b-0 md:border-r">
            <div className="absolute inset-0 bg-gradient-to-br from-white/10 via-transparent to-white/5 opacity-40" aria-hidden />
            <div className="relative z-10">
              <span className="text-xs font-semibold uppercase tracking-[0.32em] text-white/50">Отзывы</span>
              <AnimatePresence mode="wait">
                <motion.blockquote
                  key={active.quote}
                  initial={{ opacity: 0, y: 12 }}
                  animate={{ opacity: 1, y: 0 }}
                  exit={{ opacity: 0, y: -12 }}
                  transition={{ duration: 0.5, ease: [0.4, 0, 0.2, 1] }}
                  className="mt-6 text-lg text-white/85 sm:text-xl"
                >
                  “{active.quote}”
                </motion.blockquote>
              </AnimatePresence>
            </div>
          </div>
          <div
            className="relative flex flex-col justify-between gap-6 p-8"
            onMouseEnter={() => setIndex(index)}
          >
            <div className="space-y-6">
              {TESTIMONIALS.map((testimonial, i) => (
                <button
                  key={testimonial.name}
                  onMouseEnter={() => setIndex(i)}
                  onFocus={() => setIndex(i)}
                  className={`group flex w-full flex-col items-start gap-1 rounded-2xl border border-transparent px-4 py-3 text-left transition ${
                    index === i ? "border-white/30 bg-white/10" : "hover:border-white/20 hover:bg-white/5"
                  }`}
                >
                  <span className="text-sm font-medium text-white/80 group-hover:text-white">{testimonial.name}</span>
                  <span className="text-xs uppercase tracking-[0.2em] text-white/40">{testimonial.role}</span>
                </button>
              ))}
            </div>
            <AnimatePresence mode="wait">
              <motion.div
                key={active.metric}
                initial={{ opacity: 0, y: 12 }}
                animate={{ opacity: 1, y: 0 }}
                exit={{ opacity: 0, y: -12 }}
                transition={{ duration: 0.45, ease: [0.4, 0, 0.2, 1] }}
                className="rounded-2xl border border-white/10 bg-white/5 px-4 py-3 text-xs uppercase tracking-[0.28em] text-white/60"
              >
                {active.metric}
              </motion.div>
            </AnimatePresence>
          </div>
        </div>
      </GlassCard>
    </section>
  );
}
