export function shouldReuseCompletedLinkImportJob(
  status: string | null | undefined
): boolean {
  return status === "completed";
}
