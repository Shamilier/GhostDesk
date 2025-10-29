import { CallToAction } from "@/components/CallToAction";
import { FeaturesGrid } from "@/components/FeaturesGrid";
import { Footer } from "@/components/Footer";
import { Hero } from "@/components/Hero";
import { HowItWorks } from "@/components/HowItWorks";
import { Navbar } from "@/components/Navbar";
import { Roadmap } from "@/components/Roadmap";
import { UseCases } from "@/components/UseCases";

export default function Home() {
  return (
    <>
      <Navbar />
      <main className="relative flex flex-col gap-24 pb-24">
        <Hero />
        <FeaturesGrid />
        <UseCases />
        <HowItWorks />
        <Roadmap />
        <CallToAction />
      </main>
      <Footer />
    </>
  );
}
