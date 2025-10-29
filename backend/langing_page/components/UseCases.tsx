"use client";

import { motion } from "framer-motion";
import { GraduationCap, Headset, LayoutDashboard, UsersRound } from "lucide-react";
import { GlassCard } from "./GlassCard";
import { SectionHeading } from "./SectionHeading";

const SCENARIOS = [
  {
    title: "Командные звонки",
    description: "Ghost AI подсказывает, какие вопросы задать, и фиксирует договорённости, пока вы ведёте диалог.",
    icon: UsersRound,
    chips: ["Статусы", "Action items", "Follow-up"]
  },
  {
    title: "Продажи и клиентский сервис",
    description: "Работает как подсказчик возражений и источник быстрых фактов — не нужно листать CRM во время разговора.",
    icon: Headset,
    chips: ["Скрипты", "Цифры", "FAQ"]
  },
  {
    title: "Лекции и обучение",
    description: "Запоминает определения и вопросы, создаёт аккуратный конспект и помогает готовиться к экзамену.",
    icon: GraduationCap,
    chips: ["Термины", "Вопросы", "Конспект"]
  },
  {
    title: "Продуктовые демо",
    description: "Во время презентации Ghost AI подсказывает, что показать дальше, и записывает обратную связь.",
    icon: LayoutDashboard,
    chips: ["Аргументы", "Roadmap", "Feedback"]
  }
];

export function UseCases() {
  return (
    <section id="scenarios" className="relative mx-auto mt-32 w-full max-w-6xl px-4 sm:px-6">
      <SectionHeading
        eyebrow="Сценарии"
        title="Ghost AI помогает, когда важно реагировать быстро"
        description="Каждая карточка — реальный сценарий. Никаких перегруженных блоков: только короткие подсказки, которые покажут, как Ghost AI ведёт вас во время разговора."
      />
      <div className="mt-14 grid grid-cols-1 gap-6 md:grid-cols-2">
        {SCENARIOS.map((scenario, index) => {
          const Icon = scenario.icon;
          return (
            <GlassCard key={scenario.title} className="h-full">
              <motion.div
                className="flex h-full flex-col gap-5"
                initial={{ opacity: 0, y: 20 }}
                whileInView={{ opacity: 1, y: 0 }}
                viewport={{ once: true, amount: 0.3 }}
                transition={{ delay: index * 0.05, duration: 0.45, ease: [0.4, 0, 0.2, 1] }}
              >
                <div className="flex items-center justify-between">
                  <span className="inline-flex h-11 w-11 items-center justify-center rounded-2xl bg-white/10 text-white">
                    <Icon className="h-5 w-5" />
                  </span>
                  <div className="flex gap-2">
                    {scenario.chips.map(chip => (
                      <span
                        key={chip}
                        className="rounded-full bg-white/8 px-3 py-1 text-[0.65rem] font-semibold uppercase tracking-[0.28em] text-white/60"
                      >
                        {chip}
                      </span>
                    ))}
                  </div>
                </div>
                <div className="space-y-3 text-left">
                  <h3 className="text-lg font-semibold text-white">{scenario.title}</h3>
                  <p className="text-sm text-white/65">{scenario.description}</p>
                </div>
              </motion.div>
            </GlassCard>
          );
        })}
      </div>
    </section>
  );
}
