"use client";

import { motion } from "framer-motion";
import { CalendarClock, FileText, Laptop } from "lucide-react";
import { GlassCard } from "./GlassCard";
import { SectionHeading } from "./SectionHeading";

const ROADMAP_ITEMS = [
  {
    title: "Пост-анализ встреч",
    description: "Автоматическая расшифровка, цитаты и предложения по задачам на основе записи. Делиться можно в один клик.",
    icon: FileText
  },
  {
    title: "Командные рабочие пространства",
    description: "Общий архив встреч, права доступа и быстрый поиск по темам, людям и компаниям.",
    icon: Laptop
  },
  {
    title: "Поддержка Windows",
    description: "После релиза macOS-версии расширяем Ghost AI на другие платформы, сохраняя тот же минимализм интерфейса.",
    icon: CalendarClock
  }
];

export function Roadmap() {
  return (
    <section id="roadmap" className="relative mx-auto mt-32 w-full max-w-5xl px-4 sm:px-6">
      <SectionHeading
        eyebrow="Скоро"
        title="Ghost AI развивается вместе с вами"
        description="Мы делимся тем, что появится в ближайших обновлениях. Можно присоединиться к раннему доступу и влиять на приоритеты."
      />
      <div className="mt-14 grid grid-cols-1 gap-5 md:grid-cols-3">
        {ROADMAP_ITEMS.map((item, index) => {
          const Icon = item.icon;
          return (
            <GlassCard key={item.title} className="h-full">
              <motion.div
                className="flex h-full flex-col gap-3"
                initial={{ opacity: 0, y: 18 }}
                whileInView={{ opacity: 1, y: 0 }}
                viewport={{ once: true, amount: 0.3 }}
                transition={{ delay: index * 0.05, duration: 0.45, ease: [0.4, 0, 0.2, 1] }}
              >
                <span className="inline-flex h-10 w-10 items-center justify-center rounded-2xl bg-white/10 text-white">
                  <Icon className="h-5 w-5" />
                </span>
                <h3 className="text-lg font-semibold text-white">{item.title}</h3>
                <p className="text-sm text-white/65">{item.description}</p>
              </motion.div>
            </GlassCard>
          );
        })}
      </div>
    </section>
  );
}
