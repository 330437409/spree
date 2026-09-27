import type { ReactNode } from 'react'

/**
 * One label and one value, read rather than edited: the shape a detail panel,
 * a sheet and a record's own page all reach for. A run of them belongs inside
 * a card's content with `divide-y` on the wrapper, which is what rules them
 * apart.
 */
export function DetailRow({ label, value }: { label: string; value: ReactNode }) {
  return (
    <div className="flex flex-row items-start justify-between gap-4 px-4 py-3">
      <dt className="text-sm text-muted-foreground">{label}</dt>
      <dd className="max-w-full text-right text-sm">{value}</dd>
    </div>
  )
}

/** The wrapper a run of `DetailRow`s goes in: a description list, ruled. */
export function DetailList({ children }: { children: ReactNode }) {
  return <dl className="flex flex-col divide-y divide-border">{children}</dl>
}
