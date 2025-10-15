import type { Config } from "tailwindcss";

const config: Config = {
  content: [
    "./app/**/*.{ts,tsx}",
    "./components/**/*.{ts,tsx}",
    "./lib/**/*.{ts,tsx}",
    "./ui/**/*.{ts,tsx}"
  ],
  theme: {
    extend: {
      colors: {
        background: "#0F1218",
        surface: "#151A21",
        muted: "#1F252E",
        accent: "#8B9EFF",
        accentSoft: "rgba(139, 158, 255, 0.08)",
        success: "#4ADE80",
        danger: "#F87171"
      },
      fontFamily: {
        sans: ["Inter", "system-ui", "-apple-system", "BlinkMacSystemFont", "Segoe UI", "sans-serif"],
        mono: ["JetBrains Mono", "SFMono-Regular", "Menlo", "monospace"]
      },
      boxShadow: {
        subtle: "0px 8px 24px rgba(8, 12, 20, 0.24)",
        inset: "inset 0 1px 0 rgba(255,255,255,0.05)"
      }
    }
  },
  plugins: [require("@tailwindcss/typography")]
};

export default config;
