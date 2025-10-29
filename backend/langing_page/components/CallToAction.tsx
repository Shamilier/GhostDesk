"use client";

import { motion, useReducedMotion } from "framer-motion";
import { ArrowRight, Sparkles, Wand2 } from "lucide-react";

const CTA_POINTS = [
  {
    title: "Подключите Ghost AI",
    copy: "Выберите источники звука, микрофон и экран. Всё занимает меньше минуты."
  },
  {
    title: "Получайте подсказки",
    copy: "AI подстраивает фразы под контекст, выделяет следующее действие и фиксирует договорённости."
  },
  {
    title: "Отправляйте итоги",
    copy: "Готовый конспект уходит в команду или CRM. Вы делитесь ссылкой, а не сырым текстом."
  }
];

export function CallToAction() {
  const shouldReduceMotion = useReducedMotion();

  return (
    <section id="cta" className="relative mx-auto mt-36 w-full max-w-6xl px-4 sm:px-6">
      <motion.div
        className="relative overflow-hidden rounded-[3rem] border border-white/15 bg-white/5 px-8 py-14 sm:px-16"
        initial={{ opacity: 0, y: 24 }}
        whileInView={{ opacity: 1, y: 0 }}
        viewport={{ once: true, amount: 0.35 }}
        transition={{ duration: 0.6, ease: [0.4, 0, 0.2, 1] }}
      >
        <div className="pointer-events-none absolute -left-24 top-0 h-72 w-72 rounded-full bg-[#5b8cff]/30 blur-3xl" aria-hidden />
        <div className="pointer-events-none absolute -right-24 bottom-0 h-80 w-80 rounded-full bg-[#a06aff]/35 blur-3xl" aria-hidden />
        <div className="pointer-events-none absolute inset-0 bg-gradient-to-br from-white/10 via-transparent to-white/5 opacity-40" aria-hidden />
        <div className="relative z-10 grid gap-12 lg:grid-cols-[1.05fr,0.95fr] lg:items-center">
          <div className="space-y-6 text-left">
            <span className="inline-flex items-center gap-2 rounded-full border border-white/15 bg-white/10 px-4 py-2 text-[0.65rem] font-semibold uppercase tracking-[0.32em] text-white/70">
              <Wand2 className="h-4 w-4" /> Попробуйте сейчас
            </span>
            <h2 className="text-3xl font-semibold text-white sm:text-4xl">
              Готовы к идеальному собеседнику? Ghost AI уже ждёт.
            </h2>
            <p className="text-base text-white/75 sm:text-lg">
              Запустите Ghost AI бесплатно и посмотрите, как AI ведёт встречу, подсказки и конспект. Можете пригласить команду и сразу поделиться лентой встреч.
            </p>
            <div className="flex flex-col gap-3 sm:flex-row">
              <motion.a
                href="https://ghostai.ru/signup"
                className="btn-primary justify-center px-8 py-4 text-sm uppercase tracking-[0.2em] sm:text-base"
                whileHover={shouldReduceMotion ? undefined : { scale: 1.06 }}
                whileTap={shouldReduceMotion ? undefined : { scale: 0.95 }}
              >
                Попробовать бесплатно
              </motion.a>
              <motion.a
                href="#how"
                className="btn-secondary justify-center px-8 py-4 text-sm uppercase tracking-[0.2em] sm:text-base"
                whileHover={shouldReduceMotion ? undefined : { scale: 1.04 }}
                whileTap={shouldReduceMotion ? undefined : { scale: 0.96 }}
              >
                Смотреть демо
              </motion.a>
            </div>
            <div className="flex flex-wrap items-center gap-3">
              <span className="inline-flex items-center gap-2 rounded-full border border-white/15 bg-white/10 px-4 py-1.5 text-[0.65rem] uppercase tracking-[0.32em] text-white/70">
                <Sparkles className="h-4 w-4" /> 14 дней бесплатно
              </span>
              <span className="inline-flex items-center gap-2 rounded-full border border-white/10 bg-white/5 px-4 py-1.5 text-[0.65rem] uppercase tracking-[0.32em] text-white/60">
                Без карты — отмените в любой момент
              </span>
            </div>
          </div>
          <div className="space-y-4">
            {CTA_POINTS.map((point, index) => (
              <motion.div
                key={point.title}
                className="group relative overflow-hidden rounded-3xl border border-white/10 bg-white/5 p-6"
                initial={{ opacity: 0, y: 18 }}
                whileInView={{ opacity: 1, y: 0 }}
                viewport={{ once: true, amount: 0.35 }}
                transition={{ delay: index * 0.08, duration: 0.5, ease: [0.4, 0, 0.2, 1] }}
              >
                <div className="pointer-events-none absolute inset-0 opacity-0 transition-opacity duration-500 group-hover:opacity-50"
                  style={{ background: "linear-gradient(135deg, rgba(91,140,255,0.35), rgba(160,106,255,0.2))" }}
                  aria-hidden
                />
                <div className="relative z-10 flex items-start gap-4">
                  <span className="mt-1 inline-flex h-9 w-9 flex-none items-center justify-center rounded-2xl border border-white/15 bg-white/10 text-xs font-semibold uppercase tracking-[0.3em] text-white/60">
                    0{index + 1}
                  </span>
                  <div className="space-y-2">
                    <h3 className="text-base font-semibold text-white sm:text-lg">{point.title}</h3>
                    <p className="text-sm text-white/75">{point.copy}</p>
                  </div>
                </div>
              </motion.div>
            ))}
            <motion.a
              href="https://ghostai.ru/signup"
              className="group inline-flex items-center gap-3 rounded-full border border-white/15 bg-white/5 px-5 py-3 text-xs font-semibold uppercase tracking-[0.28em] text-white transition hover:border-white/40"
              initial={{ opacity: 0, y: 12 }}
              whileInView={{ opacity: 1, y: 0 }}
              viewport={{ once: true, amount: 0.35 }}
              transition={{ delay: 0.3, duration: 0.45, ease: [0.4, 0, 0.2, 1] }}
            >
              Перейти к регистрации
              <ArrowRight className="h-4 w-4 transition-transform duration-300 group-hover:translate-x-1" />
            </motion.a>
          </div>
        </div>
      </motion.div>
    </section>
  );
}
