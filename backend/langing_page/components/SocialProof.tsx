"use client";

import { motion, useReducedMotion } from "framer-motion";

const LOGOS = ["Sber", "Miro", "Avito", "MTS", "Yandex", "Skyeng", "Revolut", "Spotify"];

const METRICS = [
  {
    value: "40–60%",
    description: "быстрее готовитесь и разбираете встречи",
    note: "данные по ранним пользователям"
  },
  {
    value: "↓ усталость",
    description: "AI снимает когнитивную нагрузку во время диалога",
    note: "по внутренним UX-исследованиям"
  },
  {
    value: "30–45 мин",
    description: "экономия на пост-разбор каждой сессии",
    note: "по данным alpha-программы"
  }
];

export function SocialProof() {
  const shouldReduceMotion = useReducedMotion();

  return (
    <section id="social-proof" className="relative z-10 mx-auto mt-20 w-full max-w-6xl px-4 sm:px-6">
      <div className="overflow-hidden rounded-[2.5rem] border border-white/10 bg-white/5 p-6 sm:p-8">
        <div className="relative mb-6 overflow-hidden rounded-2xl border border-white/10 bg-white/5">
          <motion.div
            className="flex min-w-full items-center gap-10 whitespace-nowrap px-6 py-4 text-sm uppercase tracking-[0.35em] text-white/50"
            animate={
              shouldReduceMotion
                ? undefined
                : { x: ["0%", "-50%"], transition: { duration: 22, repeat: Infinity, ease: "linear" } }
            }
          >
            {[...LOGOS, ...LOGOS].map((logo, index) => (
              <span key={`${logo}-${index}`} className="text-white/60">
                {logo}
              </span>
            ))}
          </motion.div>
          <div className="pointer-events-none absolute inset-y-0 left-0 w-20 bg-gradient-to-r from-[rgba(11,11,15,0.85)] to-transparent" />
          <div className="pointer-events-none absolute inset-y-0 right-0 w-20 bg-gradient-to-l from-[rgba(11,11,15,0.85)] to-transparent" />
        </div>
        <div className="grid gap-4 sm:grid-cols-3">
          {METRICS.map((item, index) => (
            <motion.div
              key={item.description}
              className="group relative overflow-hidden rounded-2xl border border-white/10 bg-white/5 p-6"
              initial={{ opacity: 0, y: 18 }}
              whileInView={{ opacity: 1, y: 0 }}
              viewport={{ once: true, amount: 0.4 }}
              transition={{ delay: index * 0.05, duration: 0.5, ease: [0.4, 0, 0.2, 1] }}
            >
              <div
                className="pointer-events-none absolute inset-0 opacity-0 transition-opacity duration-500 group-hover:opacity-40"
                style={{ background: "radial-gradient(circle at top, rgba(91,140,255,0.35), transparent 65%)" }}
                aria-hidden
              />
              <div className="relative z-10 space-y-3">
                <div className="text-3xl font-semibold text-white sm:text-4xl">{item.value}</div>
                <p className="text-sm text-white/75 sm:text-base">{item.description}</p>
                <p className="text-[0.65rem] uppercase tracking-[0.32em] text-white/40">{item.note}</p>
              </div>
            </motion.div>
          ))}
        </div>
      </div>
    </section>
  );
}
