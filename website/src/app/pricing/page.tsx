import type { Metadata } from "next";
import { ArrowRight, Check, Sparkles } from "lucide-react";
import { MarketingShell } from "@/components/marketing-shell";
import { copy } from "@/lib/copy";
import { storeLinks } from "@/lib/links";

export const metadata: Metadata = {
  title: "Pricing | ChillScript",
  description:
    "Compare ChillScript Free and Pro pricing for AI creator notes, transcription, AI Skills, and longer recordings.",
};

type PricingPlan = {
  name: string;
  price: string;
  caption: string;
  features: string[];
  note?: string;
};

const plans: PricingPlan[] = [copy.pricing.free, copy.pricing.weekly, copy.pricing.yearly];

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
          </article>
        ))}
      </section>

      <section className="store-downloads">
        <h2>{copy.pricing.downloadTitle}</h2>
        <div>
          <a className="primary-button" href={storeLinks.appStore}>
            {copy.pricing.iosAction}
            <ArrowRight size={17} />
          </a>
          <a className="secondary-button" href={storeLinks.googlePlay}>
            {copy.pricing.androidAction}
            <ArrowRight size={17} />
          </a>
        </div>
      </section>
    </MarketingShell>
  );
}
