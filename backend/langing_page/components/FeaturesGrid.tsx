"use client";

import { motion } from "framer-motion";
import {
  AudioLines,
  Ear,
  Mic,
  MonitorSmartphone,
  Sparkles,
  Workflow
} from "lucide-react";
import { GlassCard } from "./GlassCard";
import { SectionHeading } from "./SectionHeading";

const FEATURES = [
  {
    title: "Прослушивание системного звука",
    highlight: "Слышит то, что слышите вы",
    description: "софта, браузера, звонков и любых вкладок.",
    icon: Ear
  },
  {
    title: "Микрофон и речевые подсказки",
    highlight: "Понимает ваш голос",
    description: "и шепчет релевантные фразы на лету.",
    icon: Mic
  },
  {
    title: "Захват экрана",
    highlight: "Видит контекст окна",
    description: "и помогает решать задачи «с экрана».",
    icon: MonitorSmartphone
  },
  {
    title: "Реал-тайм транскрибация",
    highlight: "Текст беседы с тайм-кодами",
    description: "и говорящими — сразу, без ожидания.",
    icon: AudioLines
  },
  {
    title: "AI-подсказки и шаблоны ответов",
    highlight: "Интервью, собеседования, продажи",
    description: "— уверенные формулировки в один клик.",
    icon: Sparkles
  },
  {
    title: "Пост-анализ и архив встреч",
    highlight: "Итоги, экшены, темы",
    description: "поиск по людям и вопросам. Глубокий AI-разбор по запросу.",
    icon: Workflow
  }
];

export function FeaturesGrid() {
  return (
    <section id="features" className="relative mx-auto mt-28 w-full max-w-6xl px-4 sm:px-6">
      <SectionHeading
        eyebrow="Возможности"
        title="Все, что нужно для ясных разговоров"
        description="Ghost AI объединяет звук, экран и AI-подсказки в один невидимый слой. Каждый блок — отдельный инструмент, который работает автономно и не перегружает ваш экран."
      />
      <div className="mt-16 grid grid-cols-1 gap-6 md:grid-cols-2 xl:grid-cols-3">
        {FEATURES.map((feature, index) => {
          const Icon = feature.icon;
          return (
            <GlassCard key={feature.title} glow className="h-full">
              <motion.div
                className="flex h-full flex-col gap-6"
                initial={{ opacity: 0, y: 20 }}
                whileInView={{ opacity: 1, y: 0 }}
                viewport={{ once: true, amount: 0.4 }}
                transition={{ delay: index * 0.05, duration: 0.5, ease: [0.4, 0, 0.2, 1] }}
              >
                <span className="inline-flex h-12 w-12 items-center justify-center rounded-2xl border border-white/10 bg-white/10 text-white">
                  <Icon className="h-5 w-5" />
                </span>
                <div className="space-y-3">
                  <h3 className="text-lg font-semibold text-white">{feature.title}</h3>
                  <p className="text-sm leading-relaxed text-white/70">
                    <span className="font-semibold text-white">{feature.highlight}</span> {feature.description}
                  </p>
                </div>
              </motion.div>
            </GlassCard>
          );
        })}
      </div>
    </section>
  );
}
