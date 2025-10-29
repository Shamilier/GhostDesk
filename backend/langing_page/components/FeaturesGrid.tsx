"use client";

import { motion } from "framer-motion";
import { AudioLines, Ear, Mic, MonitorSmartphone, ShieldCheck, Sparkles } from "lucide-react";
import { GlassCard } from "./GlassCard";
import { SectionHeading } from "./SectionHeading";

const FEATURES = [
  {
    icon: Ear,
    tag: "Звук",
    title: "Слышит системный звук, как и вы",
    description: "Ghost AI забирает аудио из Zoom, браузера, любого приложения без дополнительной настройки.",
    stat: "98%",
    statLabel: "точность распознавания"
  },
  {
    icon: Mic,
    tag: "Голос",
    title: "Понимает ваш темп и стиль речи",
    description:
      "Подстраивает подсказки под тон общения, выделяет ключевые фразы и следит, чтобы вы не забыли про follow-up.",
    stat: "120 мс",
    statLabel: "задержка реакции"
  },
  {
    icon: MonitorSmartphone,
    tag: "Экран",
    title: "Видит, что на экране, и помогает в моменте",
    description:
      "Ghost AI анализирует активное окно, чтобы выдавать релевантные шаблоны ответов и шаги рядом с курсором.",
    stat: "Context",
    statLabel: "поверх любых приложений"
  },
  {
    icon: AudioLines,
    tag: "Транскрибация",
    title: "Текст, тайм-коды и говорящие — сразу",
    description:
      "Появляется динамическая стенограмма, синхронизированная с голосами. По окончании звонка всё уже готово в архиве.",
    stat: "Live",
    statLabel: "обновляется в реальном времени"
  },
  {
    icon: Sparkles,
    tag: "AI подсказки",
    title: "Подсказывает, что сказать, показать, уточнить",
    description:
      "Готовые фразы, действия и инсайты появляются мягко, чтобы вы вели диалог уверенно и не переключались.",
    stat: "+32%",
    statLabel: "рост конверсии в демо"
  },
  {
    icon: ShieldCheck,
    tag: "Приватность",
    title: "Вы управляете тем, что Ghost AI слышит",
    description:
      "Выбирайте источники, включайте локальные фильтры, отключайте запись в один клик. Ghost AI хранит данные шифрованными.",
    stat: "Ctrl",
    statLabel: "гибкие политики доступа"
  }
];

const GRID_VARIANTS = {
  hidden: {},
  visible: {
    transition: { staggerChildren: 0.08 }
  }
};

export function FeaturesGrid() {
  return (
    <section id="features" className="relative mx-auto mt-28 w-full max-w-6xl px-4 sm:px-6">
      <SectionHeading
        eyebrow="Возможности"
        title={
          <>
            Невидимый ассистент
            <span className="text-white/70">, который работает за вас</span>
          </>
        }
        description="Ghost AI объединяет звук, голос, экран и AI-подсказки в единый слой. Карточки реагируют на курсор, показывая, как каждая функция адаптируется под ваш сценарий."
      />
      <motion.div
        className="mt-16 grid grid-cols-1 gap-6 lg:grid-cols-3"
        initial="hidden"
        whileInView="visible"
        viewport={{ once: true, amount: 0.35 }}
        variants={GRID_VARIANTS}
      >
        {FEATURES.map((feature, index) => {
          const Icon = feature.icon;
          return (
            <GlassCard key={feature.title} glow className="h-full">
              <motion.div
                className="flex h-full flex-col justify-between gap-6"
                variants={{ hidden: { opacity: 0, y: 18 }, visible: { opacity: 1, y: 0 } }}
                transition={{ delay: index * 0.03, duration: 0.45, ease: [0.4, 0, 0.2, 1] }}
              >
                <div className="space-y-6">
                  <div className="flex items-center justify-between">
                    <span className="inline-flex items-center gap-2 rounded-full border border-white/10 bg-white/10 px-3 py-1 text-[0.65rem] uppercase tracking-[0.32em] text-white/60">
                      {feature.tag}
                    </span>
                    <span className="inline-flex h-11 w-11 items-center justify-center rounded-2xl border border-white/10 bg-white/5 text-white">
                      <Icon className="h-5 w-5" />
                    </span>
                  </div>
                  <div className="space-y-3">
                    <h3 className="text-lg font-semibold text-white">{feature.title}</h3>
                    <p className="text-sm leading-relaxed text-white/75">{feature.description}</p>
                  </div>
                </div>
                <div className="flex items-center justify-between rounded-2xl border border-white/10 bg-white/5 px-4 py-3 text-left">
                  <span className="text-2xl font-semibold text-white">{feature.stat}</span>
                  <span className="text-xs uppercase tracking-[0.3em] text-white/40">{feature.statLabel}</span>
                </div>
              </motion.div>
            </GlassCard>
          );
        })}
      </motion.div>
    </section>
  );
}
