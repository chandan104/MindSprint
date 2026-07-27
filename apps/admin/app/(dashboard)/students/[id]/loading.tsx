// Instant navigation feedback: App Router shows this skeleton the moment a
// teacher opens a student, while the server component streams in — no blank
// screen, no perceived stall.
export default function StudentReportLoading() {
  return (
    <div className="space-y-8" aria-busy="true" aria-label="Loading student report">
      <div className="space-y-2">
        <div className="bg-muted h-7 w-56 animate-pulse rounded-md" />
        <div className="bg-muted h-4 w-72 animate-pulse rounded-md" />
      </div>
      <div className="bg-muted h-28 w-full animate-pulse rounded-lg" />
      <div className="bg-muted h-24 w-full animate-pulse rounded-lg" />
      <div className="grid gap-6 lg:grid-cols-2">
        <div className="bg-muted h-56 animate-pulse rounded-lg" />
        <div className="bg-muted h-56 animate-pulse rounded-lg" />
      </div>
    </div>
  );
}
