import { clsx, type ClassValue } from "clsx";
import { twMerge } from "tailwind-merge";

export function cn(...inputs: ClassValue[]) {
  return twMerge(clsx(inputs));
}

export function formatDuration(totalSeconds: number) {
  const hours = Math.floor(totalSeconds / 3600);
  const minutes = Math.floor((totalSeconds % 3600) / 60);
  const seconds = totalSeconds % 60;
  if (hours > 0) {
    return [hours, minutes, seconds].map((value) => String(value).padStart(2, "0")).join(":");
  }
  return `${String(minutes).padStart(2, "0")}:${String(seconds).padStart(2, "0")}`;
}

export function formatDate(date: Date) {
  return date.toLocaleDateString("en-US", {
    month: "short",
    day: "numeric",
    year: "numeric"
  });
}

export function formatRelative(date: Date) {
  const now = new Date();
  const diff = now.getTime() - date.getTime();
  const minutes = Math.floor(diff / (1000 * 60));
  if (minutes < 1) return "just now";
  if (minutes < 60) return `${minutes}m ago`;
  const hours = Math.floor(minutes / 60);
  if (hours < 24) return `${hours}h ago`;
  const days = Math.floor(hours / 24);
  if (days < 7) return `${days}d ago`;
  const weeks = Math.floor(days / 7);
  if (weeks < 4) return `${weeks}w ago`;
  return formatDate(date);
}

export function formatMilliseconds(ms: number) {
  return formatDuration(Math.floor(ms / 1000));
}

export const TAG_COLORS = [
  "bg-accent/10 text-accent",
  "bg-success/10 text-success",
  "bg-white/10 text-white/90",
  "bg-danger/10 text-danger"
];

export function getTagColor(index: number) {
  return TAG_COLORS[index % TAG_COLORS.length];
}
