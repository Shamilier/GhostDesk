"use client";

import { motion } from "framer-motion";
import clsx from "clsx";

type GlassCardProps = {
  className?: string;
  children: React.ReactNode;
  glow?: boolean;
};

export function GlassCard({ className, children, glow }: GlassCardProps) {
  return (
    <motion.div
      className={clsx(
        "relative overflow-hidden rounded-3xl border border-white/8 bg-white/[0.04] p-6 backdrop-blur-xl sm:p-8",
        glow && "shadow-[0_25px_45px_-40px_rgba(91,140,255,0.9)]",
        className
      )}
      initial={{ opacity: 0, y: 24 }}
      whileInView={{ opacity: 1, y: 0 }}
      viewport={{ once: true, amount: 0.2 }}
      transition={{ duration: 0.5, ease: [0.4, 0, 0.2, 1] }}
    >
      {glow && (
        <div
          aria-hidden="true"
          className="pointer-events-none absolute inset-0 rounded-[inherit] bg-gradient-to-br from-[#5b8cff26] via-[#5be5ff1c] to-[#a06aff2e]"
        />
      )}
      <div className="relative z-10 space-y-4 text-left text-sm text-white/80 sm:text-base">{children}</div>
    </motion.div>
  );
}
