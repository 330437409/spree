import { Button } from '@spree/dashboard-ui'
import { useEffect, useRef, useState } from 'react'
import { useTranslation } from 'react-i18next'

/**
 * Tencent's JavaScript map API, as much of it as this editor uses. The SDK is a
 * global loaded from a URL rather than a package, so the little of its shape we
 * touch is declared here instead of imported.
 */
interface TencentMap {
  on(event: 'click', handler: (event: { latLng: { lat: number; lng: number } }) => void): void
  destroy(): void
}

interface TencentMapNamespace {
  Map: new (container: HTMLElement, options: Record<string, unknown>) => TencentMap
  LatLng: new (lat: number, lng: number) => unknown
  PolygonStyle: new (options: Record<string, unknown>) => unknown
  MarkerStyle: new (options: Record<string, unknown>) => unknown
  MultiPolygon: new (
    options: Record<string, unknown>,
  ) => { setGeometries(geometries: unknown[]): void }
  MultiMarker: new (
    options: Record<string, unknown>,
  ) => { setGeometries(geometries: unknown[]): void }
}

declare global {
  interface Window {
    TMap?: TencentMapNamespace
  }
}

export type ServiceAreaVertex = { lat: number; lng: number }

/** Where the map opens when a warehouse has no coordinates and nothing is drawn. */
const DEFAULT_CENTER: ServiceAreaVertex = { lat: 35.8617, lng: 104.1954 }

const loaded = new Map<string, Promise<TencentMapNamespace>>()

/**
 * Loads Tencent's map API once per key, on first use.
 *
 * A browser key, read from the store's settings rather than bundled: the map
 * runs in the panel, and Tencent issues this key to the JavaScript API rather
 * than to the geocoding service the server calls.
 */
function loadTencentMaps(apiKey: string): Promise<TencentMapNamespace> {
  const existing = loaded.get(apiKey)
  if (existing) return existing

  const promise = new Promise<TencentMapNamespace>((resolve, reject) => {
    if (window.TMap) {
      resolve(window.TMap)
      return
    }

    const script = document.createElement('script')
    script.src = `https://map.qq.com/api/gljs?v=1.exp&key=${encodeURIComponent(apiKey)}`
    script.async = true
    script.onload = () =>
      window.TMap ? resolve(window.TMap) : reject(new Error('Tencent Maps loaded without TMap'))
    script.onerror = () => {
      loaded.delete(apiKey)
      reject(new Error('Tencent Maps could not be loaded'))
    }
    document.head.appendChild(script)
  })

  loaded.set(apiKey, promise)
  return promise
}

/**
 * The drawn shape as the server stores it: one closed ring of `[lng, lat]`
 * pairs — GeoJSON's order, and the order the polygon validator reads.
 *
 * Fewer than three points is not a shape, so it answers nothing rather than a
 * degenerate ring the server would refuse.
 */
export function polygonFromVertices(vertices: ServiceAreaVertex[]): number[][][] {
  if (vertices.length < 3) return []

  const ring = vertices.map((vertex) => [vertex.lng, vertex.lat])
  return [[...ring, ring[0]]]
}

/** The stored rings back into editable points — the closing point is not one. */
export function verticesFromPolygon(polygon: number[][][] | null | undefined): ServiceAreaVertex[] {
  const ring = polygon?.[0]
  if (!ring || ring.length < 4) return []

  return ring.slice(0, -1).map(([lng, lat]) => ({ lat, lng }))
}

/**
 * The polygon a warehouse's coverage is narrowed by, drawn on Tencent's map.
 *
 * Tencent's tiles are GCJ-02, which is what the stored coordinates are, so what
 * a merchant draws is where the shape lands — an open-source base map sits three
 * to six hundred metres away in China and would quietly move every boundary
 * with it.
 *
 * Click the map to add a point; the shape closes itself once it has three, and
 * the toolbar takes the last one back or clears the lot. Moving a single point
 * is not offered yet: the map's own editing tools are a larger piece of the SDK
 * than this first version needs.
 */
export function ServiceAreaMap({
  value,
  onValueChange,
  apiKey,
  center,
  disabled,
}: {
  /** The stored rings, or null when nothing is drawn. */
  value: number[][][] | null
  onValueChange: (polygon: number[][][] | null) => void
  /** The store's Tencent Maps JavaScript API key; the map is not offered without one. */
  apiKey?: string | null
  /** Where to open the map — the warehouse's own coordinates when it has any. */
  center?: ServiceAreaVertex | null
  disabled?: boolean
}) {
  const { t } = useTranslation()
  const container = useRef<HTMLDivElement | null>(null)
  const map = useRef<TencentMap | null>(null)
  const polygon = useRef<{ setGeometries(geometries: unknown[]): void } | null>(null)
  const markers = useRef<{ setGeometries(geometries: unknown[]): void } | null>(null)
  const verticesRef = useRef<ServiceAreaVertex[]>(verticesFromPolygon(value))
  const disabledRef = useRef(disabled)
  const onValueChangeRef = useRef(onValueChange)

  const [vertices, setVertices] = useState<ServiceAreaVertex[]>(verticesRef.current)
  const [error, setError] = useState<string | null>(null)

  verticesRef.current = vertices
  disabledRef.current = disabled
  onValueChangeRef.current = onValueChange

  // The guard is what makes this once: a later run — a new key, a locale change
  // — finds a map already built and leaves it alone.
  useEffect(() => {
    if (!apiKey || !container.current || map.current) return

    let cancelled = false

    loadTencentMaps(apiKey)
      .then((TMap) => {
        if (cancelled || !container.current) return

        const instance = new TMap.Map(container.current, {
          center: new TMap.LatLng(
            center?.lat ?? DEFAULT_CENTER.lat,
            center?.lng ?? DEFAULT_CENTER.lng,
          ),
          zoom: 12,
        })

        polygon.current = new TMap.MultiPolygon({
          map: instance,
          styles: { default: new TMap.PolygonStyle({}) },
        })
        markers.current = new TMap.MultiMarker({
          map: instance,
          styles: { default: new TMap.MarkerStyle({}) },
        })

        instance.on('click', (event) => {
          if (disabledRef.current) return

          setVertices((current) => [...current, { lat: event.latLng.lat, lng: event.latLng.lng }])
        })

        map.current = instance
      })
      .catch(() => setError(t('admin.stock_locations.service_area.map_unavailable')))

    return () => {
      cancelled = true
    }
  }, [apiKey, center?.lat, center?.lng, t])

  // Redraw what the vertices say, and tell the form what that is.
  useEffect(() => {
    const TMap = window.TMap
    const drawn = polygonFromVertices(vertices)

    if (TMap && map.current) {
      polygon.current?.setGeometries(
        drawn.length
          ? [
              {
                id: 'service-area',
                styleId: 'default',
                paths: vertices.map((vertex) => new TMap.LatLng(vertex.lat, vertex.lng)),
              },
            ]
          : [],
      )
      markers.current?.setGeometries(
        vertices.map((vertex, index) => ({
          id: `vertex-${index}`,
          styleId: 'default',
          position: new TMap.LatLng(vertex.lat, vertex.lng),
        })),
      )
    }

    onValueChangeRef.current(drawn.length ? drawn : null)
  }, [vertices])

  if (!apiKey) {
    return (
      <p className="text-sm text-muted-foreground">
        {t('admin.stock_locations.service_area.map_needs_key')}
      </p>
    )
  }

  return (
    <div className="flex flex-col gap-3">
      <div
        ref={container}
        className="h-80 w-full overflow-hidden rounded-md border"
        data-testid="service-area-map"
      />
      {error && <p className="text-sm text-destructive">{error}</p>}
      <p className="text-xs text-muted-foreground">
        {t('admin.stock_locations.service_area.map_help')}
      </p>
      <div className="flex gap-2">
        <Button
          type="button"
          variant="outline"
          size="sm"
          disabled={disabled || vertices.length === 0}
          onClick={() => setVertices([])}
        >
          {t('admin.stock_locations.service_area.map_clear')}
        </Button>
        <Button
          type="button"
          variant="outline"
          size="sm"
          disabled={disabled || vertices.length === 0}
          onClick={() => setVertices((current) => current.slice(0, -1))}
        >
          {t('admin.stock_locations.service_area.map_undo')}
        </Button>
      </div>
    </div>
  )
}
