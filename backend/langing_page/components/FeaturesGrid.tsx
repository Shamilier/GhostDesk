"use client";

import { motion } from "framer-motion";
import { AudioLines, Command, Ear, Lightbulb, MonitorSmartphone, ShieldCheck } from "lucide-react";
import { GlassCard } from "./GlassCard";
import { SectionHeading } from "./SectionHeading";

const FEATURES = [
  {
    title: "Слышит и понимает контекст",
    description: "Ghost AI подключается к системному звуку и микрофону, чтобы фиксировать ключевые фразы без задержек.",
    icon: Ear
  },
  {
    title: "Режим подсказок поверх экрана",
    description: "Оверлей остаётся полупрозрачным и реагирует на курсор. Нужное — под рукой, остальное не мешает.",
    icon: MonitorSmartphone
  },
  {
    title: "Ответы по хоткеям",
    description: "Задайте вопрос клавишами и получите формулировку или справку по открытой вкладке прямо в окне встречи.",
    icon: Command
  },
  {
    title: "Умные заметки в реальном времени",
    description: "Подсвечиваются договорённости, цифры и вопросы. После звонка заметки сразу готовы к отправке.",
    icon: AudioLines
  },
  {
    title: "Минимальный визуальный шум",
    description: "Тёмные цвета, аккуратные линии, плавные переходы. Ghost AI не перетягивает внимание.",
    icon: Lightbulb
  },
  {
    title: "Контроль приватности",
    description: "Выбирайте, какие приложения слушать, и отключайте запись в один клик. Данные остаются у вас.",
    icon: ShieldCheck
  }
];

export function FeaturesGrid() {
  return (
    <section id="features" className="relative mx-auto mt-28 w-full max-w-6xl px-4 sm:px-6">
      <SectionHeading
        eyebrow="Возможности"
        title="Помощник, который не отвлекает"
        description="Ghost AI держит весь контекст разговора и помогает вам отвечать уверенно. Всё сведено к шести понятным блокам — без сложных настроек."
      />
      <div className="mt-16 grid grid-cols-1 gap-6 md:grid-cols-2 xl:grid-cols-3">
        {FEATURES.map((feature, index) => {
          const Icon = feature.icon;
          return (
            <GlassCard key={feature.title} className="h-full">
              <motion.div
                className="flex h-full flex-col gap-5"
                initial={{ opacity: 0, y: 20 }}
                whileInView={{ opacity: 1, y: 0 }}
                viewport={{ once: true, amount: 0.3 }}
                transition={{ delay: index * 0.05, duration: 0.45, ease: [0.4, 0, 0.2, 1] }}
              >
                <span className="inline-flex h-11 w-11 items-center justify-center rounded-2xl bg-white/10 text-white">
                  <Icon className="h-5 w-5" />
                </span>
                <div className="space-y-2">
                  <h3 className="text-lg font-semibold text-white">{feature.title}</h3>
                  <p className="text-sm leading-relaxed text-white/65">{feature.description}</p>
                </div>
              </motion.div>
            </GlassCard>
          );
        })}
      </div>
    </section>
  );
}
