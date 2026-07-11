export function Wordmark({ className }: { className?: string }) {
  return (
    <span className={className ? `wordmark ${className}` : "wordmark"} aria-label="ChillScript">
      <span aria-hidden>Chill</span>
      <strong aria-hidden>Script</strong>
    </span>
  );
}
