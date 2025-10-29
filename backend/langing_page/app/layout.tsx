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
  title: "Ghost AI — Невидимый AI-ассистент для разговоров",
  description:
    "Невидимый macOS-помощник для звонков, лекций и созвонов. Ghost AI слушает систему, подсказывает ответы и готовится к пост-анализу встреч.",
  metadataBase: new URL("https://ghostai.ru"),
  openGraph: {
    title: "Ghost AI — Невидимый AI-ассистент для разговоров",
    description:
      "Невидимый macOS-помощник для звонков, лекций и созвонов. Ghost AI слушает систему, подсказывает ответы и готовится к пост-анализу встреч.",
    url: "https://ghostai.ru",
    siteName: "Ghost AI",
    images: [
      {
        url: "https://ghostai.ru/og-image.png",
        width: 1200,
        height: 630,
        alt: "Ghost AI Landing"
      }
    ],
    locale: "ru_RU",
    type: "website"
  },
  twitter: {
    card: "summary_large_image",
    title: "Ghost AI — Невидимый AI-ассистент для разговоров",
    description:
      "Говорите свободно. Ghost AI подсказывает в реальном времени и готовит пост-анализ записей.",
    creator: "@ghostai"
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
