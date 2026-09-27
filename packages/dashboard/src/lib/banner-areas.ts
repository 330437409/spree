import type { MembershipBannerAreaInput } from '@spree/admin-sdk'

/**
 * The banner's tap targets, in the client's own coordinates.
 *
 * `area_rem` is a CSS style — `left: 1rem;top: 2rem;width: 3rem;height: 1rem;` —
 * because the client lays the targets out in its own rem: 1rem is 94rpx at its
 * design width, so a full-width banner is about eight of them, whatever the
 * screen it lands on. The editor works in the same unit and only converts to
 * pixels to draw.
 *
 * A style written in another unit is read as the number it carries and written
 * back in rem, which is the unit this system speaks: the mini program never
 * writes anything else, and the row itself refuses an area it cannot place.
 */
export const BANNER_REM_WIDTH = 8

/** One target, as it is written and read. */
export type BannerArea = MembershipBannerAreaInput

/**
 * A target as the editor holds it: the same row plus a key of its own, so that
 * removing one target does not shift what the row above it was showing — the
 * array is a list of rows, and a position is not a name.
 */
export interface EditableBannerArea extends BannerArea {
  key: string
}

/** The same row the API writes, without the editor's own key. */
export function toBannerArea(area: EditableBannerArea): BannerArea {
  return { area_rem: area.area_rem, link: area.link.trim(), name: area.name?.trim() || null }
}

function areaKey(): string {
  return globalThis.crypto?.randomUUID?.() ?? Math.random().toString(36).slice(2)
}

/** A box in rem, as the editor moves and resizes it. */
export interface BannerBox {
  left: number
  top: number
  width: number
  height: number
}

/** Where a fresh target starts: a third of the banner, an eighth down. */
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

function rem(value: number): string {
  return `${Math.round(value * 100) / 100}rem`
}

/** Writes a box the way the client reads it, in the order it reads it. */
export function formatAreaRem(box: BannerBox): string {
  return `left: ${rem(box.left)};top: ${rem(box.top)};width: ${rem(box.width)};height: ${rem(box.height)};`
}

/** The areas a payload carried, as the editor's own shape. */
export function toAreas(areas: Array<Record<string, unknown>> | undefined): EditableBannerArea[] {
  return (areas ?? []).map((area) => ({
    key: areaKey(),
    area_rem: String(area.area_rem ?? ''),
    link: String(area.link ?? ''),
    name: (area.name as string | null) ?? null,
  }))
}

/** A fresh target, with a key of its own. */
export function newArea(area: Partial<BannerArea> = {}): EditableBannerArea {
  return { key: areaKey(), area_rem: '', link: '', name: null, ...area }
}
