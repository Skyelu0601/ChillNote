export function subscriptionURL(store: string | null, productId: string | null = null, billingIssue = false): string {
  if (store === "play_store" || store === "google_play") {
    if (billingIssue && productId) {
      const sku = productId.split(":", 1)[0];
      return `https://play.google.com/store/account/subscriptions?sku=${encodeURIComponent(sku)}&package=com.sponteoai.chillscript`;
    }
    return "https://play.google.com/store/account/subscriptions";
  }
  return billingIssue ? "https://apps.apple.com/account/billing" : "https://apps.apple.com/account/subscriptions";
}
