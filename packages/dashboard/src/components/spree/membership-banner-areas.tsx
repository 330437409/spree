import { Button, cn, Field, FieldLabel, Input, useConfirm } from '@spree/dashboard-ui'
import { GripVerticalIcon, PlusIcon, Trash2Icon } from '@spree/dashboard-ui/icons'
import { type KeyboardEvent, type PointerEvent, useRef, useState } from 'react'
import { useTranslation } from 'react-i18next'
import {
  BANNER_REM_WIDTH,
  type BannerArea,
  type BannerBox,
  formatAreaRem,
  NEW_AREA_BOX,
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
  areas: BannerArea[]
  onChange: (areas: BannerArea[]) => void
}) {
  const { t } = useTranslation()
  const confirm = useConfirm()
  const canvas = useRef<HTMLDivElement | null>(null)
  const [selected, setSelected] = useState<number | null>(areas.length > 0 ? 0 : null)

  // A rem is however wide the picture is divided by the banner's own width: the
  // client's rem is a fixed unit, so the preview only has to agree with it.
  const remToPixels = () => (canvas.current?.clientWidth ?? 0) / BANNER_REM_WIDTH

  function replaceBox(index: number, box: BannerBox) {
    onChange(
      areas.map((area, position) =>
        position === index ? { ...area, area_rem: formatAreaRem(box) } : area,
      ),
    )
  }

  function addArea() {
    onChange([...areas, { area_rem: formatAreaRem(NEW_AREA_BOX), link: '', name: null }])
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

    const box = parseAreaRem(areas[index].area_rem)
    const startX = event.clientX
    const startY = event.clientY
    const scale = remToPixels()
    if (scale === 0) return

    const target = event.currentTarget
    target.setPointerCapture(event.pointerId)

    const onMove = (moveEvent: globalThis.PointerEvent) => {
      const deltaX = (moveEvent.clientX - startX) / scale
      const deltaY = (moveEvent.clientY - startY) / scale

      if (mode === 'move') {
        replaceBox(index, {
          ...box,
          left: Math.max(0, box.left + deltaX),
          top: Math.max(0, box.top + deltaY),
        })
      } else {
        replaceBox(index, {
          ...box,
          width: Math.max(0.5, box.width + deltaX),
          height: Math.max(0.5, box.height + deltaY),
        })
      }
    }

    const onUp = () => {
      target.removeEventListener('pointermove', onMove)
      target.removeEventListener('pointerup', onUp)
      target.releasePointerCapture(event.pointerId)
    }

    target.addEventListener('pointermove', onMove)
    target.addEventListener('pointerup', onUp)
  }

  /** Arrow keys nudge the target a keyboard selected. */
  function nudge(event: KeyboardEvent<HTMLElement>, index: number) {
    const step = event.shiftKey ? 0.5 : 0.1
    const box = parseAreaRem(areas[index].area_rem)

    const moves: Record<string, BannerBox> = {
      ArrowLeft: { ...box, left: Math.max(0, box.left - step) },
      ArrowRight: { ...box, left: box.left + step },
      ArrowUp: { ...box, top: Math.max(0, box.top - step) },
      ArrowDown: { ...box, top: box.top + step },
    }

    const moved = moves[event.key]
    if (!moved) return

    event.preventDefault()
    replaceBox(index, moved)
  }

  return (
    <div className="flex flex-col gap-4">
      <div
        ref={canvas}
        className="relative w-full overflow-hidden rounded-lg border bg-muted"
        // The picture sets the height: the banner's own proportions are the
        // operator's, and the targets sit on it.
        style={{ aspectRatio: pic ? undefined : '3 / 1' }}
      >
        {pic ? (
          <img src={pic} alt="" className="block w-full select-none" draggable={false} />
        ) : (
          <div className="flex h-full items-center justify-center text-sm text-muted-foreground">
            {t('admin.membership_banners.no_picture')}
          </div>
        )}

        {pic &&
          areas.map((area, index) => {
            const box = parseAreaRem(area.area_rem)
            const scale = remToPixels()
            const isSelected = selected === index

            return (
              <div
                // biome-ignore lint/suspicious/noArrayIndexKey: a target has no id of its own; the order is the row.
                key={index}
                role="button"
                tabIndex={0}
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
                <span className="absolute -top-0.5 left-1/2 -translate-x-1/2 -translate-y-full rounded bg-primary px-1 text-[10px] text-primary-foreground">
                  {index + 1}
                </span>
                {isSelected && (
                  <span
                    role="presentation"
                    onPointerDown={(event) => startDrag(event, index, 'resize')}
                    className="absolute right-0 bottom-0 size-3 translate-x-1/2 translate-y-1/2 cursor-se-resize rounded-sm border border-background bg-primary"
                  />
                )}
              </div>
            )
          })}
      </div>

      <p className="text-xs text-muted-foreground">{t('admin.membership_banners.editor_help')}</p>

      <div className="flex flex-col gap-3">
        {areas.map((area, index) => (
          <div
            // biome-ignore lint/suspicious/noArrayIndexKey: a target has no id of its own; the order is the row.
            key={index}
            className={cn(
              'flex items-end gap-2 rounded-md border p-3',
              selected === index && 'border-primary',
            )}
            onFocus={() => setSelected(index)}
          >
            <span className="pb-2 text-muted-foreground">
              <GripVerticalIcon className="size-4" />
            </span>

            <Field className="flex-1">
              <FieldLabel htmlFor={`banner-area-link-${index}`}>
                {t('admin.membership_banners.fields.link.label')}
              </FieldLabel>
              <Input
                id={`banner-area-link-${index}`}
                value={area.link}
                placeholder={t('admin.membership_banners.fields.link.placeholder')}
                onChange={(event) =>
                  onChange(
                    areas.map((entry, position) =>
                      position === index ? { ...entry, link: event.target.value } : entry,
                    ),
                  )
                }
              />
            </Field>

            <Field className="flex-1">
              <FieldLabel htmlFor={`banner-area-name-${index}`}>
                {t('admin.membership_banners.fields.name.label')}
              </FieldLabel>
              <Input
                id={`banner-area-name-${index}`}
                value={area.name ?? ''}
                onChange={(event) =>
                  onChange(
                    areas.map((entry, position) =>
                      position === index ? { ...entry, name: event.target.value } : entry,
                    ),
                  )
                }
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
