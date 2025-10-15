import "./globals.css";

import type { Metadata } from "next";
import { Inter } from "next/font/google";
import AppShell from "@/components/layout/app-shell";
import type { ReactNode } from "react";

const inter = Inter({ subsets: ["latin", "cyrillic"], variable: "--font-inter" });

export const metadata: Metadata = {
  title: "GhostDesk Web",
  description: "Второй мозг для ваших записей: история, поиск, инсайты и шаринг."
};

export default function RootLayout({ children }: { children: ReactNode }) {
  return (
    <html lang="ru" className={inter.variable}>
      <body className="bg-background text-white">
        <AppShell>{children}</AppShell>
      </body>
    </html>
  );
}
