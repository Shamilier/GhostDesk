"use client";

import Link from "next/link";

const FOOTER_LINKS = [
  { label: "Возможности", href: "#features" },
  { label: "Сценарии", href: "#scenarios" },
  { label: "Как работает", href: "#workflow" },
  { label: "Что дальше", href: "#roadmap" }
];

const SOCIALS = [
  { label: "Twitter", href: "https://twitter.com/ghostai" },
  { label: "LinkedIn", href: "https://linkedin.com/company/ghostai" },
  { label: "Product Hunt", href: "https://www.producthunt.com/posts/ghost-ai" }
];

export function Footer() {
  return (
    <footer className="relative mx-auto mt-24 w-full max-w-6xl px-4 pb-12 pt-10 sm:px-6">
      <div className="flex flex-col gap-8 rounded-3xl border border-white/10 bg-white/5 px-6 py-8 backdrop-blur-xl sm:px-10 lg:flex-row lg:items-center lg:justify-between">
        <div>
          <div className="flex items-center gap-2 text-xs font-semibold uppercase tracking-[0.32em] text-white/60">
            <span className="h-2 w-2 rounded-full bg-white" aria-hidden="true" />
            Ghost AI
          </div>
          <p className="mt-3 max-w-md text-sm text-white/70">
            Невидимый AI-ассистент для звонков, лекций и живых встреч. Слушает, подсказывает и остаётся за кадром.
          </p>
        </div>
        <nav className="flex flex-1 flex-col gap-6 text-sm text-white/70 sm:flex-row sm:items-center sm:justify-end sm:gap-8">
          <div className="flex flex-wrap gap-4">
            {FOOTER_LINKS.map(link => (
              <Link key={link.label} href={link.href} className="transition hover:text-white">
                {link.label}
              </Link>
            ))}
          </div>
          <div className="flex flex-wrap gap-4">
            {SOCIALS.map(link => (
              <a key={link.label} href={link.href} target="_blank" rel="noreferrer" className="transition hover:text-white">
                {link.label}
              </a>
            ))}
          </div>
        </nav>
      </div>
      <div className="mt-8 text-xs text-white/40">© {new Date().getFullYear()} Ghost AI. Все права защищены.</div>
    </footer>
  );
}
