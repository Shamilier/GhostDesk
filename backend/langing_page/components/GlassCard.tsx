"use client";

import { motion, useMotionValue, useSpring, useReducedMotion } from "framer-motion";
import clsx from "clsx";
import { useCallback, useRef } from "react";

type GlassCardProps = {
  className?: string;
  children: React.ReactNode;
  glow?: boolean;
};

export function GlassCard({ className, children, glow }: GlassCardProps) {
  const containerRef = useRef<HTMLDivElement | null>(null);
  const shouldReduceMotion = useReducedMotion();

  const rotateX = useMotionValue(0);
  const rotateY = useMotionValue(0);
  const x = useSpring(rotateX, { stiffness: 120, damping: 18, mass: 0.4 });
  const y = useSpring(rotateY, { stiffness: 120, damping: 18, mass: 0.4 });
  const glowLevel = useMotionValue(glow ? 0.28 : 0);
  const glowOpacity = useSpring(glowLevel, { stiffness: 140, damping: 22, mass: 0.4 });

  const handleMouseMove = useCallback(
    (event: React.MouseEvent<HTMLDivElement>) => {
      if (shouldReduceMotion) return;
      const node = containerRef.current;
      if (!node) return;
      const rect = node.getBoundingClientRect();
      const offsetX = event.clientX - rect.left;
      const offsetY = event.clientY - rect.top;
      const rotateAmountX = Number(((offsetY / rect.height - 0.5) * -18).toFixed(2));
      const rotateAmountY = Number(((offsetX / rect.width - 0.5) * 18).toFixed(2));
      rotateX.set(rotateAmountX);
      rotateY.set(rotateAmountY);
      if (glow) {
        const intensity = Math.min(0.65, (Math.abs(rotateAmountX) + Math.abs(rotateAmountY)) / 24 + 0.28);
        glowLevel.set(intensity);
      }
    },
    [glow, glowLevel, rotateX, rotateY, shouldReduceMotion]
  );

  const handleMouseLeave = useCallback(() => {
    rotateX.set(0);
    rotateY.set(0);
    if (glow) {
      glowLevel.set(0.28);
    }
  }, [glow, glowLevel, rotateX, rotateY]);

  return (
    <motion.div
      ref={containerRef}
      onMouseMove={handleMouseMove}
      onMouseLeave={handleMouseLeave}
      className={clsx(
        "glass group relative overflow-hidden rounded-3xl p-6 sm:p-8 transition-transform duration-300 will-change-transform",
        glow && "shadow-glow",
        className
      )}
      style={{
        transformStyle: "preserve-3d",
        transformPerspective: "1200px",
        rotateX: shouldReduceMotion ? 0 : x,
        rotateY: shouldReduceMotion ? 0 : y
      }}
      initial={{ opacity: 0, y: 24 }}
      whileInView={{ opacity: 1, y: 0 }}
      viewport={{ once: true, amount: 0.2 }}
      transition={{ duration: 0.6, ease: [0.4, 0, 0.2, 1] }}
    >
      <div className="pointer-events-none absolute inset-0 opacity-0 transition-opacity duration-500 group-hover:opacity-60">
        <div className="absolute inset-0 bg-accent-gradient blur-[60px]" aria-hidden="true" />
      </div>
      <div
        className="pointer-events-none absolute inset-0 opacity-0 transition-opacity duration-500 group-hover:opacity-30"
        aria-hidden="true"
        style={{
          background:
            "radial-gradient(circle at 20% 20%, rgba(91,140,255,0.35), transparent 55%), radial-gradient(circle at 80% 10%, rgba(160,106,255,0.35), transparent 55%)"
        }}
      />
      {glow && (
        <motion.div
          aria-hidden="true"
          className="pointer-events-none absolute -inset-px rounded-[inherit] bg-accent-gradient opacity-30 blur-2xl"
          style={{ opacity: shouldReduceMotion ? 0.28 : glowOpacity }}
        />
      )}
      <div className="relative z-10 space-y-4 text-left text-sm text-white/80 sm:text-base">{children}</div>
    </motion.div>
  );
}
