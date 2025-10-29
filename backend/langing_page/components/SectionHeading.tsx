"use client";

import { motion } from "framer-motion";
import clsx from "clsx";
import type { ReactNode } from "react";

type SectionHeadingProps = {
  eyebrow: string;
  title: ReactNode;
  description?: ReactNode;
  align?: "left" | "center";
  kicker?: ReactNode;
  className?: string;
};

export function SectionHeading({
  eyebrow,
  title,
  description,
  align = "center",
  kicker,
  className
}: SectionHeadingProps) {
  const alignmentClasses =
    align === "center" ? "mx-auto max-w-3xl text-center" : "max-w-2xl text-left";

  return (
    <div className={clsx("space-y-5", alignmentClasses, className)}>
      <motion.span
        className="relative inline-flex items-center justify-center gap-2 overflow-hidden rounded-full border border-white/10 bg-white/5 px-4 py-2 text-[0.65rem] font-semibold uppercase tracking-[0.32em] text-white/60"
        initial={{ opacity: 0, y: 16 }}
        whileInView={{ opacity: 1, y: 0 }}
        viewport={{ once: true, amount: 0.3 }}
        transition={{ duration: 0.55, ease: [0.4, 0, 0.2, 1] }}
      >
        <span className="pointer-events-none absolute inset-0 bg-gradient-to-r from-white/20 via-transparent to-white/10 opacity-40" aria-hidden />
        <span className="relative z-10">{eyebrow}</span>
      </motion.span>
      <motion.div
        initial={{ opacity: 0, y: 24 }}
        whileInView={{ opacity: 1, y: 0 }}
        viewport={{ once: true, amount: 0.3 }}
        transition={{ delay: 0.08, duration: 0.6, ease: [0.4, 0, 0.2, 1] }}
        className="space-y-4"
      >
        <div className={clsx("relative inline-block", align === "center" ? "" : "text-left")}>
          <span className="pointer-events-none absolute inset-x-0 bottom-1 h-2 rounded-full bg-gradient-to-r from-[#5b8cff]/40 via-transparent to-[#a06aff]/40 blur-lg" aria-hidden />
          <h2 className="relative text-3xl font-semibold text-white sm:text-4xl">{title}</h2>
        </div>
        {description && <p className="text-base text-white/70 sm:text-lg">{description}</p>}
      </motion.div>
      {kicker && (
        <motion.div
          initial={{ opacity: 0, y: 24 }}
          whileInView={{ opacity: 1, y: 0 }}
          viewport={{ once: true, amount: 0.3 }}
          transition={{ delay: 0.16, duration: 0.6, ease: [0.4, 0, 0.2, 1] }}
          className="text-sm text-white/60"
        >
          {kicker}
        </motion.div>
      )}
    </div>
  );
}
