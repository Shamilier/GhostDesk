import { CallToAction } from "@/components/CallToAction";
import { FAQ } from "@/components/FAQ";
import { FeaturesGrid } from "@/components/FeaturesGrid";
import { Footer } from "@/components/Footer";
import { Hero } from "@/components/Hero";
import { HowItWorks } from "@/components/HowItWorks";
import { Navbar } from "@/components/Navbar";
import { Pricing } from "@/components/Pricing";
import { SocialProof } from "@/components/SocialProof";
import { Testimonials } from "@/components/Testimonials";
import { UseCases } from "@/components/UseCases";

export default function Home() {
  return (
    <>
      <Navbar />
      <main className="relative flex flex-col gap-24 pb-24">
        <Hero />
        <SocialProof />
        <FeaturesGrid />
        <HowItWorks />
        <UseCases />
        <Testimonials />
        <Pricing />
        <FAQ />
        <CallToAction />
      </main>
      <Footer />
    </>
  );
}
