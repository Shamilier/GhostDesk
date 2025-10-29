"use client";

import { motion, useReducedMotion } from "framer-motion";

const CTA_POINTS = [
  "Видите подсказки и заметки прямо на экране",
  "Получаете итоги и задачи сразу после звонка",
  "Делитесь конспектом с командой в два клика"
];

export function CallToAction() {
  const shouldReduceMotion = useReducedMotion();

  return (
    <section id="cta" className="relative mx-auto mt-36 w-full max-w-5xl px-4 sm:px-6">
      <motion.div
        className="glass relative overflow-hidden rounded-[2.75rem] px-6 py-14 sm:px-14"
        initial={{ opacity: 0, y: 24 }}
        whileInView={{ opacity: 1, y: 0 }}
        viewport={{ once: true, amount: 0.3 }}
        transition={{ duration: 0.6, ease: [0.4, 0, 0.2, 1] }}
      >
        <div className="absolute -right-28 -top-28 h-72 w-72 rounded-full bg-accent-gradient opacity-60 blur-3xl" aria-hidden />
        <div className="absolute -bottom-32 -left-20 h-80 w-80 rounded-full bg-[#a06aff] opacity-50 blur-3xl" aria-hidden />
        <div className="relative z-10 grid gap-10 lg:grid-cols-[1.1fr,auto] lg:items-center">
          <div className="space-y-6 text-left">
            <span className="inline-flex items-center gap-2 rounded-full border border-white/20 bg-white/10 px-4 py-2 text-[0.65rem] font-semibold uppercase tracking-[0.32em] text-white/70">
              Попробуйте сейчас
            </span>
            <h2 className="text-3xl font-semibold text-white sm:text-4xl">Готовы говорить уверенно?</h2>
            <p className="text-base text-white/70 sm:text-lg">
              Запустите Ghost AI бесплатно, подключите любимые сервисы и почувствуйте, как AI держит весь контекст разговора.
              В любой момент вы можете пригласить коллег и расширить план.
            </p>
            <ul className="grid gap-3 text-sm text-white/70 sm:grid-cols-2">
              {CTA_POINTS.map(point => (
                <li key={point} className="flex items-start gap-3">
                  <span className="mt-1 inline-flex h-2.5 w-2.5 flex-none rounded-full bg-white/70" />
                  <span>{point}</span>
                </li>
              ))}
            </ul>
          </div>
          <div className="flex flex-col gap-3 sm:flex-row lg:flex-col">
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
        </div>
      </motion.div>
    </section>
  );
}
