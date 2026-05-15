import type { Metadata } from "next";
import { Check, Sparkles } from "lucide-react";
import { MarketingShell } from "@/components/marketing-shell";
import { copy } from "@/lib/copy";

export const metadata: Metadata = {
  title: "Pricing | ChillNote",
  description:
    "Compare ChillNote Free and Pro pricing for creator swipe files, transcription, AI Skills, and longer recordings.",
};

type PricingPlan = {
  name: string;
  price: string;
  caption: string;
  cta: string;
  features: string[];
  note?: string;
};

const plans: PricingPlan[] = [copy.pricing.free, copy.pricing.monthly, copy.pricing.yearly];

export default function PricingPage() {
  return (
    <MarketingShell>
      <section className="subpage-band">
        <p className="eyebrow">{copy.pricing.eyebrow}</p>
        <h1>{copy.pricing.title}</h1>
        <p>{copy.pricing.subtitle}</p>
      </section>

      <section className="pricing-band">
        {plans.map((plan, index) => (
          <article className={index === 2 ? "pricing-card featured" : "pricing-card"} key={plan.name}>
            <div className="pricing-card-heading">
              <Sparkles size={22} />
              <h2>{plan.name}</h2>
            </div>
            <p className="pricing-price">{plan.price}</p>
            <p className="pricing-caption">{plan.caption}</p>
            {plan.note ? <span className="price-note">{plan.note}</span> : null}
            <ul>
              {plan.features.map((feature) => (
                <li key={feature}>
                  <Check size={17} />
                  <span>{feature}</span>
                </li>
              ))}
            </ul>
            <a className={index === 2 ? "primary-button" : "secondary-button"} href="/app">
              {plan.cta}
            </a>
          </article>
        ))}
      </section>
    </MarketingShell>
  );
}
