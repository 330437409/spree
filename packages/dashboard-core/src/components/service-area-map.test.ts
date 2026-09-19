import { describe, expect, it } from 'vitest'
import { polygonFromVertices, verticesFromPolygon } from './service-area-map'

describe('polygonFromVertices', () => {
  // GeoJSON's order is [lng, lat], and the ring has to be closed — the server's
  // validator refuses an open one, so the editor closes it rather than asking
  // the merchant to click the first point again.
  it('writes a closed ring of longitude and latitude', () => {
    expect(
      polygonFromVertices([
        { lat: 39.9, lng: 116.4 },
        { lat: 39.95, lng: 116.4 },
        { lat: 39.95, lng: 116.45 },
      ]),
    ).toEqual([
      [
        [116.4, 39.9],
        [116.4, 39.95],
        [116.45, 39.95],
        [116.4, 39.9],
      ],
    ])
  })

  it('answers nothing for fewer than three points, which is not a shape', () => {
    expect(polygonFromVertices([])).toEqual([])
    expect(
      polygonFromVertices([
        { lat: 39.9, lng: 116.4 },
        { lat: 39.95, lng: 116.4 },
      ]),
    ).toEqual([])
  })
})

describe('verticesFromPolygon', () => {
  it('reads a stored ring back without its closing point', () => {
    expect(
      verticesFromPolygon([
        [
          [116.4, 39.9],
          [116.4, 39.95],
          [116.45, 39.95],
          [116.4, 39.9],
        ],
      ]),
    ).toEqual([
      { lat: 39.9, lng: 116.4 },
      { lat: 39.95, lng: 116.4 },
      { lat: 39.95, lng: 116.45 },
    ])
  })

  it('answers nothing for a warehouse that has drawn none', () => {
    expect(verticesFromPolygon(null)).toEqual([])
    expect(verticesFromPolygon([])).toEqual([])
  })

  it('round-trips what it wrote', () => {
    const vertices = [
      { lat: 39.9, lng: 116.4 },
      { lat: 39.95, lng: 116.4 },
      { lat: 39.95, lng: 116.45 },
    ]

    expect(verticesFromPolygon(polygonFromVertices(vertices))).toEqual(vertices)
  })
})
