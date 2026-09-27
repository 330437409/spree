import { describe, expect, it } from 'vitest'
import { formatAreaRem, NEW_AREA_BOX, parseAreaRem, toAreas } from './banner-areas'

describe('parseAreaRem', () => {
  it('reads the coordinates the client writes', () => {
    expect(parseAreaRem('left: 1rem;top: 2rem;width: 3rem;height: 1rem;')).toEqual({
      left: 1,
      top: 2,
      width: 3,
      height: 1,
    })
  })

  it('reads a value written in another unit as the number it is', () => {
    expect(parseAreaRem('left: 15px;top: 0;')).toMatchObject({ left: 15, top: 0 })
  })

  // A target the operator can open and fix beats one that refuses to render:
  // the row's own validation is what decides what may be written.
  it('opens a style it cannot read on the default box', () => {
    expect(parseAreaRem('')).toEqual(NEW_AREA_BOX)
    expect(parseAreaRem(null)).toEqual(NEW_AREA_BOX)
    expect(parseAreaRem('oops')).toEqual(NEW_AREA_BOX)
  })
})

describe('formatAreaRem', () => {
  it('writes every coordinate the client places a target by', () => {
    expect(formatAreaRem({ left: 1, top: 2, width: 3, height: 1 })).toBe(
      'left: 1rem;top: 2rem;width: 3rem;height: 1rem;',
    )
  })

  // A drag lands on pixels: the stored value stays a number a person can read.
  it('rounds a coordinate a drag produced', () => {
    expect(formatAreaRem({ left: 1.234567, top: 0, width: 2, height: 1 })).toBe(
      'left: 1.23rem;top: 0rem;width: 2rem;height: 1rem;',
    )
  })

  it('reads back what it wrote', () => {
    const box = { left: 1.25, top: 2.5, width: 3.75, height: 1.5 }

    expect(parseAreaRem(formatAreaRem(box))).toEqual(box)
  })
})

describe('toAreas', () => {
  it('holds what a payload carried, and a target nobody wrote as blanks', () => {
    expect(
      toAreas([{ area_rem: 'left: 1rem;', link: '/a', name: '左上' }, { area_rem: 12 }]),
    ).toEqual([
      { area_rem: 'left: 1rem;', link: '/a', name: '左上' },
      { area_rem: '12', link: '', name: null },
    ])
  })

  it('answers nothing for a banner nobody has drawn on', () => {
    expect(toAreas(undefined)).toEqual([])
  })
})
