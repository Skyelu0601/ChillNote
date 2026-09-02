export function shouldStopAfterDeliveryEvent(type) {
  return type === "outbound_blocked" || type === "smtp_failure";
}
