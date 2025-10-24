"use client";

import { motion } from "framer-motion";

const PROOF_ITEMS = [
  {
    value: "40–60%",
    description: "Ускоряет подготовку к встречам",
    note: "По данным ранних пользователей"
  },
  {
    value: "↓ утомление",
    description: "Снижает утомление от разговоров",
    note: "По данным ранних пользователей"
  },
  {
    value: "30–45 мин",
    description: "Экономит на пост-разбор каждой сессии",
    note: "По данным ранних пользователей"
  }
];

export function SocialProof() {
  return (
    <section id="social-proof" className="relative z-10 mx-auto mt-20 w-full max-w-5xl px-4 sm:px-6">
      <div className="grid grid-cols-1 gap-4 sm:grid-cols-3">
        {PROOF_ITEMS.map((item, index) => (
          <motion.div
            key={item.description}
            className="glass relative overflow-hidden rounded-3xl border border-white/10 bg-white/5 p-6 text-center"
            initial={{ opacity: 0, y: 24 }}
            whileInView={{ opacity: 1, y: 0 }}
            viewport={{ once: true, amount: 0.3 }}
            transition={{ delay: index * 0.05, duration: 0.6, ease: [0.4, 0, 0.2, 1] }}
          >
            <div className="text-3xl font-semibold text-white sm:text-4xl">{item.value}</div>
            <p className="mt-3 text-sm text-white/70 sm:text-base">{item.description}</p>
            <p className="mt-4 text-xs uppercase tracking-[0.3em] text-white/40">{item.note}</p>
          </motion.div>
        ))}
      </div>
    </section>
  );
}
