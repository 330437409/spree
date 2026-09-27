/**
 * The banner's tap targets, in the client's own coordinates.
 *
 * `area_rem` is a CSS style — `left: 1rem;top: 2rem;width: 3rem;height: 1rem;` —
 * because the client lays the targets out in its own rem: 1rem is 94rpx at its
 * design width, so a full-width banner is about eight of them, whatever the
 * screen it lands on. The editor works in the same unit and only converts to
 * pixels to draw.
 */
export const BANNER_REM_WIDTH = 8

export interface BannerArea {
  area_rem: string
  link: string
  name?: string | null
}

/** A box in rem, as the editor moves and resizes it. */
export interface BannerBox {
  left: number
  top: number
  width: number
  height: number
}

/** Where a fresh target starts: a third of the banner, a tenth down. */
export const NEW_AREA_BOX: BannerBox = { left: 1, top: 1, width: 2.5, height: 1 }

/**
 * Reads a style the API stored. Anything it cannot read is treated as the
 * default box rather than refused: the row's own validation is what decides
 * what may be written, and an editor that opens on a broken target can fix it.
 */
export function parseAreaRem(style: string | null | undefined): BannerBox {
  const box = { ...NEW_AREA_BOX }
  if (!style) return box

  for (const part of style.split(';')) {
    const [key, value] = part.split(':').map((piece) => piece?.trim())
    if (!key || !value) continue

    const number = Number.parseFloat(value)
    if (Number.isNaN(number)) continue

    if (key === 'left') box.left = number
    if (key === 'top') box.top = number
    if (key === 'width') box.width = number
    if (key === 'height') box.height = number
  }

  return box
}

/** Rounds to two decimals, which is as fine as a rem coordinate needs to be. */
function rem(value: number): string {
  return `${Math.round(value * 100) / 100}rem`
}

/** Writes a box the way the client reads it, in the order it reads it. */
export function formatAreaRem(box: BannerBox): string {
  return `left: ${rem(box.left)};top: ${rem(box.top)};width: ${rem(box.width)};height: ${rem(box.height)};`
}

/** The areas a payload carried, as the editor's own shape. */
export function toAreas(areas: Array<Record<string, unknown>> | undefined): BannerArea[] {
  return (areas ?? []).map((area) => ({
    area_rem: String(area.area_rem ?? ''),
    link: String(area.link ?? ''),
    name: (area.name as string | null) ?? null,
  }))
}
