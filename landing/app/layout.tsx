import type { Metadata } from "next";
import "./globals.css";
import { Manrope, Plus_Jakarta_Sans } from "next/font/google";

const manrope = Manrope({
  subsets: ["latin"],
  display: "swap",
  variable: "--font-manrope"
});

const jakarta = Plus_Jakarta_Sans({
  subsets: ["latin"],
  display: "swap",
  variable: "--font-clash"
});

export const metadata: Metadata = {
  title: "GhostDesk — Умный второй мозг для ваших записей",
  description:
    "Записывайте встречи, извлекайте инсайты и делитесь важным с командой. GhostDesk помогает превратить разговоры в знания и действия.",
  openGraph: {
    title: "GhostDesk",
    description:
      "Записывайте встречи, извлекайте инсайты и делитесь важным с командой. GhostDesk — ваш второй мозг.",
    url: "https://ghostdesk.app",
    siteName: "GhostDesk",
    images: [
      {
        url: "https://ghostdesk.app/og-image.png",
        width: 1200,
        height: 630,
        alt: "GhostDesk Landing"
      }
    ],
    locale: "ru_RU",
    type: "website"
  },
  metadataBase: new URL("https://ghostdesk.app"),
  twitter: {
    card: "summary_large_image",
    title: "GhostDesk — Второй мозг для ваших записей",
    description:
      "Автоматические транскрипты, инсайты и поиск по всем звонкам и лекциям. Попробуйте GhostDesk.",
    creator: "@ghostdesk"
  }
};

export default function RootLayout({
  children
}: {
  children: React.ReactNode;
}) {
  return (
    <html lang="ru" className={`${manrope.variable} ${jakarta.variable}`}>
      <body className="font-sans bg-slate-950 text-slate-100">
        {children}
      </body>
    </html>
  );
}
