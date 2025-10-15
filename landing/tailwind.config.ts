import type { Config } from "tailwindcss";

const config: Config = {
  content: ["./app/**/*.{js,ts,jsx,tsx}", "./components/**/*.{js,ts,jsx,tsx}", "./content/**/*.{md,mdx}", "./data/**/*.{ts,tsx}"],
  theme: {
    extend: {
      colors: {
        primary: {
          50: "#f2f9ff",
          100: "#e2f0ff",
          200: "#b9dbff",
          300: "#82c0ff",
          400: "#54a5ff",
          500: "#2a8aff",
          600: "#176ce6",
          700: "#1254b4",
          800: "#114794",
          900: "#123c78"
        },
        accent: {
          500: "#7d5aff",
          600: "#5f3bff"
        }
      },
      backgroundImage: {
        "hero-gradient": "radial-gradient(circle at top left, rgba(45,160,255,0.35), transparent 55%), radial-gradient(circle at top right, rgba(125,90,255,0.35), transparent 45%)",
        "card-gradient": "linear-gradient(135deg, rgba(255,255,255,0.12), rgba(255,255,255,0.02))"
      },
      borderRadius: {
        xl: "1.25rem"
      },
      boxShadow: {
        glow: "0 0 60px rgba(42, 138, 255, 0.35)",
        subtle: "0 20px 60px -30px rgba(15, 23, 42, 0.5)"
      },
      fontFamily: {
        sans: ["var(--font-manrope)", "system-ui", "sans-serif"],
        display: ["var(--font-clash)", "var(--font-manrope)", "system-ui", "sans-serif"]
      }
    }
  },
  plugins: [require("@tailwindcss/typography")]
};

export default config;
