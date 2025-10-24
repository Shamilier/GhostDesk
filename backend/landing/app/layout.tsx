import type { Metadata, Viewport } from "next";
import "./globals.css";
import { Inter, Raleway } from "next/font/google";

const inter = Inter({
  subsets: ["latin", "cyrillic"],
  display: "swap",
  variable: "--font-inter"
});

const raleway = Raleway({
  subsets: ["latin", "cyrillic"],
  display: "swap",
  variable: "--font-display"
});

export const metadata: Metadata = {
  title: "GhostDesk — Невидимый AI-ассистент для разговоров",
  description:
    "Реал-тайм транскрибация, подсказки и пост-аналитика встреч. GhostDesk работает поверх любых приложений и помогает говорить уверенно.",
  metadataBase: new URL("https://ghostdesk.app"),
  openGraph: {
    title: "GhostDesk — Невидимый AI-ассистент для разговоров",
    description:
      "Реал-тайм транскрибация, подсказки и пост-аналитика встреч. GhostDesk работает поверх любых приложений.",
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
  twitter: {
    card: "summary_large_image",
    title: "GhostDesk — Невидимый AI-ассистент для разговоров",
    description:
      "Говорите свободно. GhostDesk транскрибирует, подсказывает и сохраняет встречи в умный архив.",
    creator: "@ghostdesk"
  }
};

export const viewport: Viewport = {
  themeColor: "#0B0B0F"
};

export default function RootLayout({
  children
}: {
  children: React.ReactNode;
}) {
  return (
    <html lang="ru" className={`${inter.variable} ${raleway.variable}`} suppressHydrationWarning>
      <body className="font-sans bg-background text-foreground antialiased">
        {children}
      </body>
    </html>
  );
}
