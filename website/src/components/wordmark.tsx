export function Wordmark({ className }: { className?: string }) {
  return (
    <span className={className ? `wordmark ${className}` : "wordmark"} aria-label="ChillNote">
      <span aria-hidden>Chill</span>
      <strong aria-hidden>Note</strong>
    </span>
  );
}
