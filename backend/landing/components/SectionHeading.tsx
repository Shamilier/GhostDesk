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
    <div className={clsx("space-y-4", alignmentClasses, className)}>
      <motion.span
        className="inline-flex items-center justify-center gap-2 rounded-full border border-white/10 bg-white/5 px-4 py-2 text-[0.65rem] font-semibold uppercase tracking-[0.32em] text-white/60"
        initial={{ opacity: 0, y: 16 }}
        whileInView={{ opacity: 1, y: 0 }}
        viewport={{ once: true, amount: 0.3 }}
        transition={{ duration: 0.55, ease: [0.4, 0, 0.2, 1] }}
      >
        {eyebrow}
      </motion.span>
      <motion.div
        initial={{ opacity: 0, y: 24 }}
        whileInView={{ opacity: 1, y: 0 }}
        viewport={{ once: true, amount: 0.3 }}
        transition={{ delay: 0.08, duration: 0.6, ease: [0.4, 0, 0.2, 1] }}
        className="space-y-4"
      >
        <h2 className="text-3xl font-semibold text-white sm:text-4xl">{title}</h2>
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
