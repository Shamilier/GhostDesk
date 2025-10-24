import type { Config } from "tailwindcss";

const config: Config = {
  content: [
    "./app/**/*.{js,ts,jsx,tsx}",
    "./components/**/*.{js,ts,jsx,tsx}",
    "./content/**/*.{md,mdx}",
    "./data/**/*.{ts,tsx}"
  ],
  theme: {
    extend: {
      colors: {
        background: "var(--color-bg)",
        foreground: "var(--color-fg)",
        muted: "var(--color-muted)",
        accent: {
          DEFAULT: "#5B8CFF",
          500: "#5B8CFF"
        },
        purple: {
          500: "#A06AFF"
        }
      },
      backgroundImage: {
        "noise-texture": "var(--noise-image)",
        "accent-gradient": "linear-gradient(90deg, #5B8CFF 0%, #A06AFF 100%)",
        "hero-radial": "radial-gradient(circle at top left, rgba(91,140,255,0.35), transparent 55%), radial-gradient(circle at top right, rgba(160,106,255,0.35), transparent 55%), radial-gradient(circle at bottom, rgba(64,115,255,0.18), transparent 65%)"
      },
      borderRadius: {
        xl: "1.25rem",
        "2xl": "1.75rem",
        "3xl": "2.5rem"
      },
      boxShadow: {
        glass: "0 25px 70px -35px rgba(8,10,25,0.8)",
        glow: "0 0 40px rgba(112,118,255,0.35)",
        "inner-glow": "inset 0 1px 0 0 rgba(255,255,255,0.25)"
      },
      keyframes: {
        float: {
          "0%, 100%": { transform: "translate3d(0, 0, 0)" },
          "50%": { transform: "translate3d(0, -12px, 0)" }
        },
        pulseGlow: {
          "0%, 100%": { opacity: "0.65" },
          "50%": { opacity: "0.95" }
        }
      },
      animation: {
        float: "float 12s ease-in-out infinite",
        "float-slow": "float 18s ease-in-out infinite",
        "pulse-glow": "pulseGlow 6s ease-in-out infinite"
      },
      fontFamily: {
        sans: ["var(--font-inter)", "system-ui", "sans-serif"],
        display: ["var(--font-display)", "var(--font-inter)", "system-ui", "sans-serif"]
      },
      spacing: {
        18: "4.5rem"
      },
      blur: {
        18: "18px"
      }
    }
  },
  plugins: [require("@tailwindcss/typography")]
};

export default config;
