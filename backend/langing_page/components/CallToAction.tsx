"use client";

import { motion } from "framer-motion";

const CTA_POINTS = [
  "macOS-клиент работает поверх любых сервисов",
  "Подсказки и ответы появляются за доли секунды",
  "Пост-анализ записей — подключим участникам раннего доступа"
];

export function CallToAction() {
  return (
    <section id="cta" className="relative mx-auto mt-36 w-full max-w-5xl px-4 sm:px-6">
      <motion.div
        className="relative overflow-hidden rounded-[2.5rem] border border-white/12 bg-white/[0.05] px-6 py-14 sm:px-14"
        initial={{ opacity: 0, y: 24 }}
        whileInView={{ opacity: 1, y: 0 }}
        viewport={{ once: true, amount: 0.3 }}
        transition={{ duration: 0.6, ease: [0.4, 0, 0.2, 1] }}
      >
        <div className="absolute -right-32 top-0 h-72 w-72 rounded-full bg-gradient-to-br from-[#5b8cff3d] to-[#a06aff40] blur-3xl" aria-hidden />
        <div className="absolute -left-24 bottom-0 h-72 w-72 rounded-full bg-[#5be5ff33] blur-3xl" aria-hidden />
        <div className="relative z-10 grid gap-8 lg:grid-cols-[1.05fr,auto] lg:items-center">
          <div className="space-y-6 text-left">
            <span className="inline-flex items-center gap-2 rounded-full border border-white/15 bg-white/10 px-4 py-2 text-[0.65rem] font-semibold uppercase tracking-[0.32em] text-white/70">
              Ранний доступ
            </span>
            <h2 className="text-3xl font-semibold text-white sm:text-4xl">Подключите Ghost AI к следующему звонку</h2>
            <p className="text-base text-white/70 sm:text-lg">
              Скачайте macOS-приложение, настройте источники и протестируйте Ghost AI 14 дней бесплатно. Мы напомним, как только выйдет пост-анализ записей и командные рабочие пространства.
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
              className="btn-primary justify-center px-8 py-4 text-sm uppercase tracking-[0.2em]"
              whileHover={{ scale: 1.04 }}
              whileTap={{ scale: 0.97 }}
            >
              Скачать для macOS
            </motion.a>
            <motion.a
              href="#roadmap"
              className="btn-secondary justify-center px-8 py-4 text-sm uppercase tracking-[0.2em]"
              whileHover={{ scale: 1.04 }}
              whileTap={{ scale: 0.97 }}
            >
              Смотреть планы
            </motion.a>
          </div>
        </div>
      </motion.div>
    </section>
  );
}
