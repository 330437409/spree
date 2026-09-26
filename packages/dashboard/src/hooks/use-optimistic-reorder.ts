import type { DragEndEvent } from '@dnd-kit/core'
import { arrayMove } from '@dnd-kit/sortable'
import type { PaginatedResponse } from '@spree/admin-sdk'
import { useQueryClient } from '@tanstack/react-query'

type Positioned = { id: string; position: number }

/**
 * Drag-to-reorder for a list whose order the server owns: the row an operator
 * dropped is shown where they dropped it — the cache moves first, so the list
 * does not snap back while the write is in flight — and the mutation's own
 * invalidation restores the canonical order afterwards.
 *
 * A failure puts the pre-drag snapshot back: success-only invalidation would
 * otherwise leave an order nobody saved on screen. `reorder` is handed the
 * rollback rather than owning it, because what writes the position differs per
 * list and this must not guess its shape.
 *
 * @param listKey the query key holding the list this list is rendered from
 * @param items the rows on screen, in the order they are shown
 * @param reorder writes one row's new position, calling `onError` if it fails
 * @return a `DndContext` `onDragEnd` handler
 */
export function useOptimisticReorder<T extends Positioned>({
  listKey,
  items,
  reorder,
}: {
  listKey: readonly unknown[]
  items: T[]
  reorder: (id: string, position: number, onError: () => void) => void
}) {
  const queryClient = useQueryClient()

  return function handleDragEnd(event: DragEndEvent) {
    const { active, over } = event
    if (!over || active.id === over.id) return

    const fromIndex = items.findIndex((item) => item.id === active.id)
    const toIndex = items.findIndex((item) => item.id === over.id)
    if (fromIndex === -1 || toIndex === -1) return

    const snapshot = queryClient.getQueryData<PaginatedResponse<T>>(listKey)
    const next = arrayMove(items, fromIndex, toIndex).map((item, index) => ({
      ...item,
      position: index + 1,
    }))

    queryClient.setQueryData(listKey, (prev: PaginatedResponse<T> | undefined) =>
      prev ? { ...prev, data: next } : prev,
    )

    reorder(String(active.id), toIndex + 1, () => queryClient.setQueryData(listKey, snapshot))
  }
}
