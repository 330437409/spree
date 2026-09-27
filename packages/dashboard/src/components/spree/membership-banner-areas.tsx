import { Button, cn, Field, FieldLabel, Input, useConfirm } from '@spree/dashboard-ui'
import { PlusIcon, Trash2Icon } from '@spree/dashboard-ui/icons'
import {
  type KeyboardEvent,
  type PointerEvent,
  useCallback,
  useEffect,
  useRef,
  useState,
} from 'react'
import { useTranslation } from 'react-i18next'
import {
  BANNER_REM_WIDTH,
  type BannerBox,
  type EditableBannerArea,
  formatAreaRem,
  NEW_AREA_BOX,
  newArea,
  parseAreaRem,
} from '../../lib/banner-areas'

/**
 * The tap targets over a tier's banner, drawn where the client will place them.
 *
 * The coordinates are the client's own — rem, at its design width — so the
 * picture is shown at that scale and a target is dragged into place rather than
 * spelled in numbers. What is stored is still a style string, which is what the
 * mini program reads.
 */
export function MembershipBannerAreas({
  pic,
  areas,
  onChange,
}: {
  pic: string
  areas: EditableBannerArea[]
  onChange: (areas: EditableBannerArea[]) => void
}) {
  const { t } = useTranslation()
  const confirm = useConfirm()
  const canvas = useRef<HTMLDivElement | null>(null)
  const [selected, setSelected] = useState<number | null>(null)
  const [pictureLoaded, setPictureLoaded] = useState(false)

  // The picture's own size, measured rather than read during render: a rem is
  // however wide it is divided by the banner's own width, and a target drawn
  // from a width nobody has measured yet would land at nought.
  const [canvasSize, setCanvasSize] = useState({ width: 0, height: 0 })
  useEffect(() => {
    const node = canvas.current
    if (!node) return

    const measure = () => setCanvasSize({ width: node.clientWidth, height: node.clientHeight })
    measure()

    // The observer is what keeps this honest: the canvas grows when the picture
    // arrives and shrinks when the window does, and both are its own news.
    const observer = new ResizeObserver(measure)
    observer.observe(node)
    return () => observer.disconnect()
  }, [])

  const scale = canvasSize.width / BANNER_REM_WIDTH
  const bounds = { width: BANNER_REM_WIDTH, height: scale > 0 ? canvasSize.height / scale : 0 }

  const updateArea = useCallback(
    (index: number, patch: Partial<EditableBannerArea>) => {
      onChange(areas.map((area, position) => (position === index ? { ...area, ...patch } : area)))
    },
    [areas, onChange],
  )

  /** Keeps a target on the picture: what is outside it is what nobody can tap. */
  function clamped(box: BannerBox): BannerBox {
    const width = Math.min(box.width, bounds.width)
    const height = bounds.height > 0 ? Math.min(box.height, bounds.height) : box.height

    return {
      width,
      height,
      left: Math.min(Math.max(0, box.left), Math.max(0, bounds.width - width)),
      top: Math.min(Math.max(0, box.top), Math.max(0, bounds.height - height)),
    }
  }

  function addArea() {
    onChange([...areas, newArea({ area_rem: formatAreaRem(NEW_AREA_BOX) })])
    setSelected(areas.length)
  }

  async function removeArea(index: number) {
    const ok = await confirm({
      title: t('admin.membership_banners.remove_confirm.title'),
      message: t('admin.membership_banners.remove_confirm.message'),
      variant: 'destructive',
      confirmLabel: t('admin.actions.delete'),
    })
    if (!ok) return

    onChange(areas.filter((_, position) => position !== index))
    setSelected(null)
  }

  /** Drags a target, or its corner handle, in the picture's own pixels. */
  function startDrag(event: PointerEvent<HTMLElement>, index: number, mode: 'move' | 'resize') {
    event.preventDefault()
    event.stopPropagation()
    setSelected(index)
    if (scale === 0) return

    const box = parseAreaRem(areas[index].area_rem)
    const startX = event.clientX
    const startY = event.clientY
    const target = event.currentTarget
    target.setPointerCapture(event.pointerId)

    const onMove = (moveEvent: globalThis.PointerEvent) => {
      const deltaX = (moveEvent.clientX - startX) / scale
      const deltaY = (moveEvent.clientY - startY) / scale

      const moved =
        mode === 'move'
          ? { ...box, left: box.left + deltaX, top: box.top + deltaY }
          : {
              ...box,
              width: Math.max(0.5, box.width + deltaX),
              height: Math.max(0.5, box.height + deltaY),
            }

      updateArea(index, { area_rem: formatAreaRem(clamped(moved)) })
    }

    const onUp = () => {
      target.removeEventListener('pointermove', onMove)
      target.removeEventListener('pointerup', onUp)
      target.releasePointerCapture(event.pointerId)
    }

    target.addEventListener('pointermove', onMove)
    target.addEventListener('pointerup', onUp)
  }

  /** Arrow keys move the target the keyboard is on. Shift takes a bigger step. */
  function nudge(event: KeyboardEvent<HTMLElement>, index: number) {
    const step = event.shiftKey ? 0.5 : 0.1
    const box = parseAreaRem(areas[index].area_rem)

    const moves: Record<string, BannerBox> = {
      ArrowLeft: { ...box, left: box.left - step },
      ArrowRight: { ...box, left: box.left + step },
      ArrowUp: { ...box, top: box.top - step },
      ArrowDown: { ...box, top: box.top + step },
    }

    const moved = moves[event.key]
    if (!moved) return

    event.preventDefault()
    updateArea(index, { area_rem: formatAreaRem(clamped(moved)) })
  }

  return (
    <div className="flex flex-col gap-4">
      <div
        ref={canvas}
        className="relative w-full overflow-hidden rounded-lg border bg-muted"
        // Until the picture loads, the box keeps the proportions a banner is
        // usually cut at, so targets have somewhere to sit and a URL still
        // being typed does not collapse the canvas to its border.
        style={{ aspectRatio: pictureLoaded ? undefined : '3 / 1' }}
      >
        {pic ? (
          <img
            src={pic}
            alt=""
            className="block w-full select-none"
            draggable={false}
            onLoad={() => setPictureLoaded(true)}
            onError={() => setPictureLoaded(false)}
          />
        ) : (
          <div className="flex h-full items-center justify-center text-sm text-muted-foreground">
            {t('admin.membership_banners.no_picture')}
          </div>
        )}

        {pic &&
          areas.map((area, index) => {
            const box = clamped(parseAreaRem(area.area_rem))
            const isSelected = selected === index

            return (
              <button
                key={area.key}
                type="button"
                aria-label={t('admin.membership_banners.target_label', { position: index + 1 })}
                onPointerDown={(event) => startDrag(event, index, 'move')}
                onKeyDown={(event) => nudge(event, index)}
                onFocus={() => setSelected(index)}
                className={cn(
                  'absolute cursor-move touch-none rounded border-2',
                  isSelected
                    ? 'border-primary bg-primary/20'
                    : 'border-primary/60 bg-primary/10 hover:bg-primary/20',
                )}
                style={{
                  left: box.left * scale,
                  top: box.top * scale,
                  width: box.width * scale,
                  height: box.height * scale,
                }}
              >
                <span className="pointer-events-none absolute -top-0.5 left-1/2 -translate-x-1/2 -translate-y-full rounded bg-primary px-1 text-[10px] text-primary-foreground">
                  {index + 1}
                </span>
                {isSelected && (
                  <span
                    role="presentation"
                    onPointerDown={(event) => startDrag(event, index, 'resize')}
                    className="absolute right-0 bottom-0 size-3 translate-x-1/2 translate-y-1/2 cursor-se-resize rounded-sm border border-background bg-primary"
                  />
                )}
              </button>
            )
          })}
      </div>

      <p className="text-xs text-muted-foreground">{t('admin.membership_banners.editor_help')}</p>

      <div className="flex flex-col gap-3">
        {areas.map((area, index) => (
          <div
            key={area.key}
            className={cn(
              'flex items-end gap-2 rounded-md border p-3',
              selected === index && 'border-primary',
            )}
          >
            <Field className="flex-1">
              <FieldLabel htmlFor={`banner-area-link-${index}`}>
                {t('admin.membership_banners.fields.link.label')}
              </FieldLabel>
              <Input
                id={`banner-area-link-${index}`}
                value={area.link}
                placeholder={t('admin.membership_banners.fields.link.placeholder')}
                onFocus={() => setSelected(index)}
                onChange={(event) => updateArea(index, { link: event.target.value })}
              />
            </Field>

            <Field className="flex-1">
              <FieldLabel htmlFor={`banner-area-name-${index}`}>
                {t('admin.membership_banners.fields.name.label')}
              </FieldLabel>
              <Input
                id={`banner-area-name-${index}`}
                value={area.name ?? ''}
                onFocus={() => setSelected(index)}
                onChange={(event) => updateArea(index, { name: event.target.value })}
              />
            </Field>

            <Button
              type="button"
              variant="ghost"
              size="icon"
              aria-label={t('admin.membership_banners.remove_cta')}
              onClick={() => removeArea(index)}
            >
              <Trash2Icon className="size-4" />
            </Button>
          </div>
        ))}

        <Button type="button" variant="outline" size="sm" className="self-start" onClick={addArea}>
          <PlusIcon className="size-4" />
          {t('admin.membership_banners.add_cta')}
        </Button>
      </div>
    </div>
  )
}
