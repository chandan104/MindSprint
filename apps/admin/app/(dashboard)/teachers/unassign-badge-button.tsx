"use client";

import { useTransition } from "react";
import { X } from "lucide-react";
import { Badge } from "@/components/ui/badge";
import { unassignClass } from "@/lib/actions/teachers";

export function UnassignBadgeButton({
  teacherId,
  classId,
  className,
}: {
  teacherId: string;
  classId: string;
  className: string;
}) {
  const [pending, startTransition] = useTransition();

  return (
    <Badge variant="outline" className="gap-1">
      {className}
      <button
        type="button"
        aria-label={`Unassign ${className}`}
        disabled={pending}
        onClick={() =>
          startTransition(async () => {
            await unassignClass(teacherId, classId);
          })
        }
        className="hover:text-destructive -mr-0.5 ml-0.5"
      >
        <X className="size-3" aria-hidden />
      </button>
    </Badge>
  );
}
