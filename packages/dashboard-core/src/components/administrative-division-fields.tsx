import {
  Field,
  FieldLabel,
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from '@spree/dashboard-ui'
import { useEffect, useState } from 'react'
import { useTranslation } from 'react-i18next'
import type { PanelAdministrativeDivision } from '../api-client'
import { useAdministrativeDivisionChildren } from '../hooks/use-administrative-divisions'

const LEVELS = ['province', 'city', 'district', 'township'] as const
type Level = (typeof LEVELS)[number]

type Chain = Record<Level, string | null>

const EMPTY_CHAIN: Chain = { province: null, city: null, district: null, township: null }

/**
 * Which node at each level contains `code`, read off the code itself.
 *
 * The codes are hierarchical by construction — a province is its two digits and
 * four zeros, a city its four and two, a district six, a township nine — so a
 * warehouse's binding tells a picker which steps to open without asking the
 * server for the node's ancestors. A code that is not the tree's (the `CN` root)
 * opens nothing.
 */
export function administrativeDivisionChain(code: string | null | undefined): Chain {
  if (!code || !/^\d+$/.test(code)) return EMPTY_CHAIN

  return {
    province: `${code.slice(0, 2)}0000`,
    city: `${code.slice(0, 4)}00`,
    district: code.slice(0, 6),
    township: code.length >= 9 ? code.slice(0, 9) : null,
  }
}

/**
 * The service-area picker: a warehouse's coverage is a node of the
 * administrative tree, and a node is chosen by walking down to it.
 *
 * Any level may be the answer — a warehouse that covers a whole province stops
 * at the province — so the value is the deepest node chosen and every step is
 * optional. A level is offered only when the one above it has children, which
 * the tree reports rather than the picker guessing.
 */
export function AdministrativeDivisionFields({
  value,
  onValueChange,
  idPrefix = 'administrative-division',
  disabled,
}: {
  /** The bound node's code, or null when the warehouse covers nothing yet. */
  value: string | null
  onValueChange: (code: string | null) => void
  idPrefix?: string
  disabled?: boolean
}) {
  const { t } = useTranslation()
  const [chain, setChain] = useState<Chain>(() => administrativeDivisionChain(value))

  // A sheet can open on another record under us.
  useEffect(() => setChain(administrativeDivisionChain(value)), [value])

  // One query per level, keyed by the node above it — so the province list is
  // fetched once for the whole panel, not once per form.
  const provinces = useAdministrativeDivisionChildren(null)
  const cities = useAdministrativeDivisionChildren(chain.province)
  const districts = useAdministrativeDivisionChildren(chain.city)
  const townships = useAdministrativeDivisionChildren(chain.district)

  const lists: Record<Level, PanelAdministrativeDivision[]> = {
    province: provinces.data?.data ?? [],
    city: cities.data?.data ?? [],
    district: districts.data?.data ?? [],
    township: townships.data?.data ?? [],
  }

  function choose(level: Level, code: string) {
    const next: Chain = { ...chain, [level]: code || null }

    // Everything below a changed step is answered by the step above it, so it
    // goes — otherwise the form would keep a district the new province does not
    // contain.
    const deeper = LEVELS.slice(LEVELS.indexOf(level) + 1)
    for (const lower of deeper) next[lower] = null

    setChain(next)
    onValueChange([...deeper, level].map((l) => next[l]).find(Boolean) ?? null)
  }

  const options = (level: Level) =>
    lists[level].map((node) => ({ value: node.code, label: node.name }))

  const chosen = (level: Level) => lists[level].find((node) => node.code === chain[level]) ?? null

  // The province list is always worth offering; each step below it only when the
  // node above reports children.
  const offered = (level: Level): boolean => {
    const index = LEVELS.indexOf(level)
    if (index === 0) return true

    return chosen(LEVELS[index - 1])?.has_children === true
  }

  return (
    <div className="flex flex-col gap-4">
      {LEVELS.map((level) => {
        if (!offered(level)) return null

        const items = [
          { value: '', label: t('admin.stock_locations.service_area.any') },
          ...options(level),
        ]

        return (
          <Field key={level}>
            <FieldLabel htmlFor={`${idPrefix}-${level}`}>
              {t(`admin.stock_locations.service_area.levels.${level}`)}
            </FieldLabel>
            <Select
              items={items}
              value={chain[level] ?? ''}
              onValueChange={(code) => choose(level, code as string)}
              disabled={disabled}
            >
              <SelectTrigger id={`${idPrefix}-${level}`}>
                <SelectValue />
              </SelectTrigger>
              <SelectContent>
                {items.map((item) => (
                  <SelectItem key={item.value} value={item.value}>
                    {item.label}
                  </SelectItem>
                ))}
              </SelectContent>
            </Select>
          </Field>
        )
      })}
    </div>
  )
}
