import { cn, getTagColor } from "@/lib/utils";

interface BadgeProps {
  children: React.ReactNode;
  index?: number;
  className?: string;
}

export function Badge({ children, index = 0, className }: BadgeProps) {
  return (
    <span
      className={cn(
        "inline-flex items-center rounded-full px-2.5 py-1 text-xs font-medium uppercase tracking-wide",
        getTagColor(index),
        className
      )}
    >
      {children}
    </span>
  );
}
