import Link from "next/link";
import { buttonVariants } from "@/components/ui/button";

export default function NotFound() {
  return (
    <div className="flex min-h-screen flex-col items-center justify-center gap-4 p-6 text-center">
      <h1 className="text-xl font-semibold">Page not found</h1>
      <p className="text-muted-foreground max-w-sm text-sm">
        That page doesn&apos;t exist or you don&apos;t have access to it.
      </p>
      <Link href="/" className={buttonVariants({ variant: "default" })}>
        Back to overview
      </Link>
    </div>
  );
}
