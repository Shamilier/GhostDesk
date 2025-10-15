"use client";

import { cn } from "@/lib/utils";

interface FilterPillProps {
  label: string;
  active?: boolean;
  onClick?: () => void;
  icon?: React.ReactNode;
}

export function FilterPill({ label, active, onClick, icon }: FilterPillProps) {
  return (
    <button
      onClick={onClick}
      className={cn(
        "group inline-flex items-center gap-2 rounded-full border px-4 py-1.5 text-sm transition",
        active
          ? "border-accent/60 bg-accent/10 text-accent"
          : "border-white/5 bg-white/5 text-white/80 hover:border-white/20 hover:text-white"
      )}
    >
      {icon}
      <span>{label}</span>
    </button>
  );
}
