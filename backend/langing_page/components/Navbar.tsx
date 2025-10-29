"use client";

import clsx from "clsx";
import { AnimatePresence, motion, useReducedMotion } from "framer-motion";
import Link from "next/link";
import { useCallback, useEffect, useMemo, useState } from "react";
import { Menu, X } from "lucide-react";

const NAV_LINKS = [
  { label: "Возможности", href: "#features" },
  { label: "Сценарии", href: "#scenarios" },
  { label: "Как работает", href: "#workflow" },
  { label: "Скоро", href: "#roadmap" }
];

export function Navbar() {
  const [isScrolled, setIsScrolled] = useState(false);
  const [isOpen, setIsOpen] = useState(false);
  const [activeSection, setActiveSection] = useState("hero");
  const shouldReduceMotion = useReducedMotion();

  useEffect(() => {
    const handleScroll = () => {
      setIsScrolled(window.scrollY > 64);
    };

    handleScroll();
    window.addEventListener("scroll", handleScroll, { passive: true });
    return () => window.removeEventListener("scroll", handleScroll);
  }, []);

  useEffect(() => {
    const ids = ["hero", "features", "scenarios", "workflow", "roadmap", "cta"] as const;
    const observer = new IntersectionObserver(
      entries => {
        entries.forEach(entry => {
          if (entry.isIntersecting) {
            setActiveSection(entry.target.id);
          }
        });
      },
      {
        rootMargin: "-45% 0px -45% 0px",
        threshold: 0.2
      }
    );

    ids.forEach(id => {
      const element = document.getElementById(id);
      if (element) {
        observer.observe(element);
      }
    });

    return () => observer.disconnect();
  }, []);

  const toggleMenu = useCallback(() => setIsOpen(prev => !prev), []);
  const closeMenu = useCallback(() => setIsOpen(false), []);

  const activeHref = useMemo(() => {
    if (activeSection === "hero") return "";
    const match = NAV_LINKS.find(link => link.href.slice(1) === activeSection);
    return match?.href ?? "";
  }, [activeSection]);

  return (
    <header className="fixed inset-x-0 top-0 z-50 flex justify-center px-3 pt-4 sm:px-6">
      <motion.nav
        className={clsx(
          "relative flex w-full max-w-5xl items-center justify-between rounded-full border border-white/12 bg-[#0f1016bf] px-4 py-3 backdrop-blur-xl transition-all sm:px-6",
          isScrolled ? "shadow-[0_25px_45px_-35px_rgba(5,9,27,0.85)]" : "shadow-[0_18px_36px_-28px_rgba(5,9,27,0.65)]"
        )}
        initial={{ opacity: 0, y: -16 }}
        animate={{ opacity: 1, y: 0 }}
        transition={{ duration: 0.6, ease: [0.4, 0, 0.2, 1] }}
      >
        <Link href="#hero" className="flex items-center gap-2 text-xs font-medium uppercase tracking-[0.32em] text-white/80">
          <span className="h-2 w-2 rounded-full bg-white" aria-hidden="true" />
          Ghost AI
        </Link>
        <div className="hidden items-center gap-8 text-sm font-medium text-white/70 lg:flex">
          {NAV_LINKS.map(link => (
            <Link
              key={link.href}
              href={link.href}
              className={clsx(
                "relative px-1 py-1 transition-colors",
                activeHref === link.href
                  ? "text-white"
                  : "text-white/70 hover:text-white"
              )}
            >
              {link.label}
              <motion.span
                layoutId="nav-underline"
                className="absolute inset-x-1 bottom-0 h-px rounded-full bg-white/70"
                initial={false}
                animate={{ opacity: activeHref === link.href ? 1 : 0 }}
                transition={{ duration: 0.3, ease: "easeOut" }}
              />
            </Link>
          ))}
        </div>
        <div className="hidden items-center gap-3 lg:flex">
          <Link
            href="#cta"
            className="inline-flex items-center gap-2 rounded-full bg-white/12 px-5 py-2 text-xs font-semibold uppercase tracking-[0.2em] text-white transition hover:bg-white/20"
          >
            Скачать для macOS
          </Link>
        </div>
        <button
          type="button"
          aria-label="Открыть меню"
          className="inline-flex h-10 w-10 items-center justify-center rounded-full border border-white/10 bg-white/5 text-white lg:hidden"
          onClick={toggleMenu}
        >
          {isOpen ? <X className="h-4 w-4" /> : <Menu className="h-4 w-4" />}
        </button>
        <AnimatePresence>
          {isOpen && (
            <motion.div
              initial={{ opacity: 0, y: -12 }}
              animate={{ opacity: 1, y: 0 }}
              exit={{ opacity: 0, y: -12 }}
              transition={{ duration: shouldReduceMotion ? 0 : 0.25, ease: "easeOut" }}
              className="absolute right-0 top-full mt-4 w-full min-w-[240px] rounded-3xl border border-white/10 bg-[#111321]/95 p-4 shadow-glow lg:hidden"
            >
              <div className="flex flex-col gap-2 text-sm text-white/80">
                {NAV_LINKS.map(link => (
                  <Link
                    key={link.href}
                    href={link.href}
                    onClick={closeMenu}
                    className="rounded-xl px-3 py-2 transition hover:bg-white/10 hover:text-white"
                  >
                    {link.label}
                  </Link>
                ))}
              </div>
              <div className="mt-4 flex flex-col gap-2">
                <Link
                  href="#cta"
                  onClick={closeMenu}
                  className="btn-primary justify-center text-xs uppercase tracking-[0.2em]"
                >
                  Скачать для macOS
                </Link>
              </div>
            </motion.div>
          )}
        </AnimatePresence>
      </motion.nav>
    </header>
  );
}
