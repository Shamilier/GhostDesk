"use client";

import { motion, useMotionValue, useReducedMotion, useSpring } from "framer-motion";
import { ArrowRight, Play, Radar, Sparkles } from "lucide-react";
import { useCallback, useMemo } from "react";

const HERO_BENEFITS = [
  {
    label: "Невидимая панель",
    copy: "Подсказки рядом с курсором, не перекрывают интерфейсы"
  },
  {
    label: "Реал-тайм",
    copy: "AI реагирует через ~120 мс и подстраивает сценарий разговора"
  },
  {
    label: "Память",
    copy: "Итоги, тайм-коды и задачи автоматически попадают в архив"
  }
];

const HERO_METRICS = [
  {
    value: "120 мс",
    label: "Задержка ответа Ghost AI"
  },
  {
    value: "∞",
    label: "История встреч и поиск"
  },
  {
    value: "14 дн.",
    label: "Полноценный trial"
  }
];

const PREVIEW_CARDS = [
  {
    title: "Live transcript",
    tag: "00:14",
    description:
      "Ghost AI распознаёт собеседника и подсвечивает цитаты, пока разговор продолжается.",
    position: "-left-2 top-0",
    gradient: "rgba(91,140,255,0.7), rgba(91,229,255,0.35), rgba(11,11,15,0.0)"
  },
  {
    title: "AI подсказка",
    tag: "Следующий шаг",
    description:
      "Предложите demo-кейс и зафиксируйте дедлайн. Фраза появляется там, где ваш курсор.",
    position: "right-0 top-32",
    gradient: "rgba(160,106,255,0.7), rgba(91,140,255,0.35), rgba(11,11,15,0.0)"
  },
  {
    title: "Insight",
    tag: "UX interview",
    description:
      "Ghost AI выделил боль: «сложно передавать контекст между командами». В архив уходит пометка и цитата.",
    position: "left-6 bottom-2",
    gradient: "rgba(91,229,255,0.6), rgba(160,106,255,0.3), rgba(11,11,15,0.0)"
  }
];

const heroVariants = {
  hidden: { opacity: 0, y: 32 },
  visible: { opacity: 1, y: 0 }
};

type MagneticButtonProps = {
  href: string;
  variant: "primary" | "secondary";
  children: React.ReactNode;
  icon?: React.ReactNode;
  className?: string;
};

function MagneticButton({ href, variant, children, icon, className }: MagneticButtonProps) {
  const shouldReduceMotion = useReducedMotion();
  const x = useMotionValue(0);
  const y = useMotionValue(0);
  const springX = useSpring(x, { stiffness: 180, damping: 18, mass: 0.4 });
  const springY = useSpring(y, { stiffness: 180, damping: 18, mass: 0.4 });

  const handleMove = useCallback(
    (event: React.MouseEvent<HTMLAnchorElement>) => {
      if (shouldReduceMotion) return;
      const rect = event.currentTarget.getBoundingClientRect();
      const distanceX = event.clientX - (rect.left + rect.width / 2);
      const distanceY = event.clientY - (rect.top + rect.height / 2);
      x.set(distanceX * 0.25);
      y.set(distanceY * 0.25);
    },
    [shouldReduceMotion, x, y]
  );

  const reset = useCallback(() => {
    x.set(0);
    y.set(0);
  }, [x, y]);

  const baseClasses = useMemo(
    () =>
      variant === "primary"
        ? "btn-primary group px-8 py-4 text-sm font-semibold uppercase tracking-[0.2em] sm:text-base"
        : "btn-secondary group px-8 py-4 text-sm font-semibold uppercase tracking-[0.2em] sm:text-base",
    [variant]
  );

  return (
    <motion.a
      href={href}
      className={`${baseClasses} ${className ?? ""}`.trim()}
      style={{
        x: shouldReduceMotion ? 0 : springX,
        y: shouldReduceMotion ? 0 : springY
      }}
      onMouseMove={handleMove}
      onMouseLeave={reset}
      onBlur={reset}
    >
      <span className="relative z-10 flex items-center gap-2">
        {children}
        {icon}
      </span>
    </motion.a>
  );
}

export function Hero() {
  const shouldReduceMotion = useReducedMotion();

  return (
    <section id="hero" className="relative isolate overflow-hidden pt-32 sm:pt-40">
      <div className="pointer-events-none absolute inset-x-0 top-[-240px] -z-10 flex justify-center">
        <motion.div
          className="h-[640px] w-[780px] max-w-[95vw] rounded-[50%] bg-hero-radial opacity-70 blur-[30px]"
          initial={{ opacity: 0, scale: 0.9 }}
          animate={{ opacity: 1, scale: 1 }}
          transition={{ duration: 0.9, ease: [0.45, 0, 0.2, 1] }}
        />
      </div>
      <div className="pointer-events-none absolute inset-x-0 top-0 -z-10 flex justify-center">
        <motion.div
          className="relative h-[620px] w-full max-w-6xl"
          initial={{ opacity: 0.4 }}
          animate={{ opacity: 1 }}
          transition={{ duration: 1.2, ease: "easeOut" }}
        >
          <motion.div
            className="absolute left-[15%] top-16 h-36 w-36 rounded-full bg-[#5b8cff]/30 blur-3xl"
            animate={
              shouldReduceMotion
                ? { opacity: 0.45 }
                : { opacity: [0.35, 0.6, 0.35], scale: [1, 1.1, 1] }
            }
            transition={{ duration: 12, repeat: shouldReduceMotion ? 0 : Infinity, ease: "easeInOut" }}
          />
          <motion.div
            className="absolute right-[18%] top-24 h-40 w-40 rounded-full bg-[#a06aff]/35 blur-3xl"
            animate={
              shouldReduceMotion
                ? { opacity: 0.45 }
                : { opacity: [0.35, 0.7, 0.35], scale: [1, 1.08, 1] }
            }
            transition={{ duration: 14, repeat: shouldReduceMotion ? 0 : Infinity, ease: "easeInOut" }}
          />
          <motion.div
            className="absolute left-1/2 top-40 h-48 w-48 -translate-x-1/2 rounded-full bg-[#5be5ff]/25 blur-3xl"
            animate={
              shouldReduceMotion
                ? { opacity: 0.4 }
                : { opacity: [0.3, 0.65, 0.3], scale: [1, 1.12, 1] }
            }
            transition={{ duration: 16, repeat: shouldReduceMotion ? 0 : Infinity, ease: "easeInOut" }}
          />
        </motion.div>
      </div>
      <div className="mx-auto flex w-full max-w-6xl flex-col gap-16 px-4 sm:px-6">
        <motion.div
          className="inline-flex items-center gap-3 self-center rounded-full border border-white/10 bg-white/5 px-5 py-2 text-xs font-medium uppercase tracking-[0.32em] text-white/70 sm:self-start"
          variants={heroVariants}
          initial="hidden"
          animate="visible"
          transition={{ delay: 0.1, duration: 0.6, ease: [0.45, 0, 0.2, 1] }}
        >
          Невидимый слой для разговоров
        </motion.div>
        <div className="grid gap-16 lg:grid-cols-[1.04fr,0.96fr] lg:items-center">
          <div className="space-y-10 text-left">
            <motion.h1
              className="text-4xl font-semibold leading-tight text-white sm:text-5xl md:text-6xl"
              variants={heroVariants}
              initial="hidden"
              animate="visible"
              transition={{ delay: 0.2, duration: 0.7, ease: [0.4, 0, 0.2, 1] }}
            >
              Ghost AI — ваш <span className="text-white/70">соведущий</span> на каждой встрече
            </motion.h1>
            <motion.p
              className="text-base text-white/75 sm:text-lg"
              variants={heroVariants}
              initial="hidden"
              animate="visible"
              transition={{ delay: 0.35, duration: 0.7, ease: [0.4, 0, 0.2, 1] }}
            >
              Мы слушаем системный звук, ваш голос и то, что происходит на экране, чтобы мягко подсказывать, фиксировать инсайты и собирать отчёт, пока вы сосредоточены на собеседнике.
            </motion.p>
            <motion.ul
              className="grid gap-3 sm:grid-cols-3"
              initial="hidden"
              animate="visible"
              variants={{ hidden: {}, visible: { transition: { staggerChildren: 0.08 } } }}
            >
              {HERO_BENEFITS.map(benefit => (
                <motion.li
                  key={benefit.label}
                  variants={{ hidden: { opacity: 0, y: 18 }, visible: { opacity: 1, y: 0 } }}
                  className="group rounded-2xl border border-white/10 bg-white/5 p-4 transition hover:border-white/25"
                >
                  <div className="text-xs font-semibold uppercase tracking-[0.28em] text-white/40">
                    {benefit.label}
                  </div>
                  <p className="mt-2 text-sm text-white/75">{benefit.copy}</p>
                </motion.li>
              ))}
            </motion.ul>
            <motion.div
              className="flex flex-col items-start gap-4 sm:flex-row"
              variants={heroVariants}
              initial="hidden"
              animate="visible"
              transition={{ delay: 0.45, duration: 0.7, ease: [0.4, 0, 0.2, 1] }}
            >
              <MagneticButton
                href="#cta"
                variant="primary"
                icon={<ArrowRight className="h-4 w-4 transition-transform duration-300 group-hover:translate-x-1" />}
              >
                Попробовать бесплатно
              </MagneticButton>
              <MagneticButton
                href="#how"
                variant="secondary"
                className="backdrop-blur-xl"
                icon={<Play className="h-4 w-4" />}
              >
                Смотреть демо
              </MagneticButton>
            </motion.div>
            <motion.div
              className="flex flex-wrap items-center gap-3"
              initial={{ opacity: 0, y: 16 }}
              animate={{ opacity: 1, y: 0 }}
              transition={{ delay: 0.55, duration: 0.6, ease: [0.4, 0, 0.2, 1] }}
            >
              <span className="inline-flex items-center gap-2 rounded-full border border-white/15 bg-white/10 px-5 py-2 text-xs font-semibold uppercase tracking-[0.28em] text-white">
                <Sparkles className="h-4 w-4" /> 14 дней бесплатно
              </span>
              <span className="inline-flex items-center gap-2 rounded-full border border-white/10 bg-white/5 px-4 py-1.5 text-[0.65rem] uppercase tracking-[0.32em] text-white/60">
                -18% при годовой подписке
              </span>
            </motion.div>
            <motion.dl
              className="grid gap-3 sm:grid-cols-3"
              initial={{ opacity: 0, y: 20 }}
              animate={{ opacity: 1, y: 0 }}
              transition={{ delay: 0.65, duration: 0.6, ease: [0.4, 0, 0.2, 1] }}
            >
              {HERO_METRICS.map(metric => (
                <div key={metric.label} className="rounded-2xl border border-white/10 bg-white/5 p-4">
                  <dt className="text-xs uppercase tracking-[0.3em] text-white/40">{metric.label}</dt>
                  <dd className="mt-2 text-lg font-semibold text-white">{metric.value}</dd>
                </div>
              ))}
            </motion.dl>
          </div>
          <div className="relative flex items-center justify-center">
            <div className="absolute inset-0 -z-10 rounded-[3rem] border border-white/10 bg-white/5 blur-3xl" aria-hidden />
            <div className="relative w-full max-w-md">
              <motion.div
                className="pointer-events-none absolute -inset-16 rounded-[3.5rem] border border-white/5"
                initial={{ opacity: 0, scale: 0.9 }}
                animate={{ opacity: 1, scale: 1 }}
                transition={{ duration: 0.8, ease: [0.4, 0, 0.2, 1] }}
              />
              <div className="relative">
                <motion.div
                  className="absolute -left-10 top-8 inline-flex items-center gap-2 rounded-full border border-white/15 bg-white/5 px-4 py-2 text-xs uppercase tracking-[0.3em] text-white/60"
                  initial={{ opacity: 0, y: 12 }}
                  animate={{ opacity: 1, y: 0 }}
                  transition={{ delay: 0.4, duration: 0.5, ease: [0.4, 0, 0.2, 1] }}
                >
                  <Radar className="h-4 w-4" /> Live session
                </motion.div>
                {PREVIEW_CARDS.map((card, index) => (
                  <motion.div
                    key={card.title}
                    className={`glass group absolute ${card.position} w-[250px] rounded-[1.75rem] border border-white/10 bg-white/5 p-5 shadow-glow sm:w-[280px]`}
                    style={{
                      backdropFilter: "blur(26px)"
                    }}
                    initial={{ opacity: 0, y: 24, rotate: -2 + index }}
                    animate={
                      shouldReduceMotion
                        ? { opacity: 1, y: 0 }
                        : {
                            opacity: 1,
                            y: [0, index % 2 === 0 ? -12 : -18, 0],
                            rotate: [-2 + index, -1 + index, -2 + index]
                          }
                    }
                    transition={{ duration: 4 + index, repeat: shouldReduceMotion ? 0 : Infinity, ease: "easeInOut", delay: index * 0.25 }}
                  >
                    <motion.div
                      className="pointer-events-none absolute inset-0 rounded-[inherit] opacity-0 transition duration-500 group-hover:opacity-40"
                      style={{
                        background: `linear-gradient(135deg, ${card.gradient})`
                      }}
                    />
                    <div className="relative z-10 space-y-3">
                      <div className="flex items-center justify-between text-xs uppercase tracking-[0.28em] text-white/60">
                        <span>{card.title}</span>
                        <span className="rounded-full border border-white/20 px-2 py-0.5 text-[0.6rem] text-white/60">{card.tag}</span>
                      </div>
                      <p className="text-sm text-white/80">{card.description}</p>
                    </div>
                  </motion.div>
                ))}
                <motion.div
                  className="glass relative z-10 mx-auto flex w-full flex-col gap-4 rounded-[2.5rem] border border-white/10 bg-white/5 px-8 py-10 text-left"
                  initial={{ opacity: 0, y: 32 }}
                  animate={{ opacity: 1, y: 0 }}
                  transition={{ delay: 0.35, duration: 0.6, ease: [0.4, 0, 0.2, 1] }}
                >
                  <div className="flex items-center justify-between">
                    <span className="text-sm font-medium text-white">Ghost Desk Overlay</span>
                    <span className="text-xs uppercase tracking-[0.32em] text-white/40">Real time</span>
                  </div>
                  <div className="space-y-3 text-sm text-white/70">
                    <p>• Умный слой поверх приложений</p>
                    <p>• Подсказки, заметки и тайм-коды</p>
                    <p>• Экспорт отчётов по окончании разговора</p>
                  </div>
                </motion.div>
              </div>
            </div>
          </div>
        </div>
      </div>
    </section>
  );
}
