import type { ResourceTypeDefinition } from '@spree/admin-sdk'
import { type TypeFamily, typeDescription, typeLabel } from '@spree/dashboard-core'
import { Button } from '@spree/dashboard-ui'
import { useTranslation } from 'react-i18next'

/**
 * The kinds a registry offers, as a list of buttons: whichever of them the
 * caller has already used are left out before they arrive — a channel holds one
 * routing rule per kind, a tier one right — so this renders what it is given.
 *
 * A kind's copy is the dashboard's own where it has one and the registry's
 * otherwise: a kind an extension gem adds has no translation here and still
 * reads as something.
 */
export function TypePicker({
  family,
  types,
  titleKey,
  disabled,
  onPick,
  onCancel,
}: {
  family: TypeFamily
  types: ResourceTypeDefinition[]
  titleKey: string
  disabled: boolean
  onPick: (type: ResourceTypeDefinition) => void
  onCancel: () => void
}) {
  const { t } = useTranslation()

  return (
    <div className="flex flex-col gap-1 rounded-md border p-2">
      <span className="px-1 text-xs font-medium text-muted-foreground">{t(titleKey)}</span>
      {types.map((type) => {
        const description = typeDescription(family, type.type, type.description ?? '')
        return (
          <button
            key={type.type}
            type="button"
            disabled={disabled}
            className="rounded-md px-2 py-1.5 text-left hover:bg-accent disabled:opacity-50"
            onClick={() => onPick(type)}
          >
            <span className="block text-sm">{typeLabel(family, type.type, type.label)}</span>
            {description && (
              <span className="block text-xs text-muted-foreground">{description}</span>
            )}
          </button>
        )
      })}
      <Button type="button" variant="outline" size="sm" className="self-start" onClick={onCancel}>
        {t('admin.actions.cancel')}
      </Button>
    </div>
  )
}
