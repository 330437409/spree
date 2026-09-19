import { describe, expect, it } from 'vitest'
import { administrativeDivisionChain } from './administrative-division-fields'

describe('administrativeDivisionChain', () => {
  // The codes are hierarchical by construction — a province is its two digits
  // and four zeros, a city its four and two, a district six, a township nine —
  // so a picker can open the right steps from a stored binding alone.
  it('reads the ancestors of a township out of its code', () => {
    expect(administrativeDivisionChain('110101001')).toEqual({
      province: '110000',
      city: '110100',
      district: '110101',
      township: '110101001',
    })
  })

  it('reads a district, a city and a province to themselves', () => {
    expect(administrativeDivisionChain('110101')).toEqual({
      province: '110000',
      city: '110100',
      district: '110101',
      township: null,
    })
    expect(administrativeDivisionChain('110100')).toEqual({
      province: '110000',
      city: '110100',
      district: '110100',
      township: null,
    })
    expect(administrativeDivisionChain('110000')).toEqual({
      province: '110000',
      city: '110000',
      district: '110000',
      township: null,
    })
  })

  it('opens nothing for the national root, which is not a code of the tree’s arithmetic', () => {
    expect(administrativeDivisionChain('CN')).toEqual({
      province: null,
      city: null,
      district: null,
      township: null,
    })
  })

  it('opens nothing when the warehouse has bound nothing', () => {
    expect(administrativeDivisionChain(null)).toEqual({
      province: null,
      city: null,
      district: null,
      township: null,
    })
  })

  // A province-level binding answers the province step; the deeper steps are
  // the same node, which the picker then shows as selected rather than empty.
  it('points every level at the same node for a shallow binding', () => {
    const chain = administrativeDivisionChain('310000')

    expect(chain.province).toBe('310000')
    expect(chain.township).toBeNull()
  })
})
