/**
 * A server figure as money, in the currency it came in.
 *
 * The bundle's prices are plain numbers with a `currency` beside them, because
 * that is what the Admin API answers — the panel formats, it does not convert.
 */
export function formatAmount(
  amount: number | null | undefined,
  currency: string | null | undefined,
): string {
  if (amount === null || amount === undefined) return '—'

  return new Intl.NumberFormat(undefined, {
    style: 'currency',
    currency: currency || 'USD',
  }).format(amount)
}
