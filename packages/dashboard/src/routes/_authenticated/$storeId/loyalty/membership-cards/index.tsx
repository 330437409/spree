import type { MembershipCard } from '@spree/admin-sdk'
import { adminClient, ResourceTable, resourceSearchSchema } from '@spree/dashboard-core'
import { useRowClickBridge } from '@spree/dashboard-ui'
import { createFileRoute, useNavigate } from '@tanstack/react-router'
import { z } from 'zod/v4'
import { MembershipCardSheet } from '../../../../../components/spree/membership-card-sheet'
import '../../../../../tables/membership-cards'

const cardsSearchSchema = resourceSearchSchema.extend({
  view: z.string().optional(),
})

export const Route = createFileRoute('/_authenticated/$storeId/loyalty/membership-cards/')({
  validateSearch: cardsSearchSchema,
  component: MembershipCardsPage,
})

/**
 * Every card a store has issued, and what became of it — including the ones
 * nobody has activated, which no term answers for. Read-only apart from voiding
 * one, which lives in the card's own sheet because it is a decision about that
 * card rather than an edit to a row.
 */
function MembershipCardsPage() {
  const { storeId } = Route.useParams()
  const search = Route.useSearch() as z.infer<typeof cardsSearchSchema>
  const navigate = useNavigate()

  const openCard = (id: string) =>
    navigate({ search: (prev: Record<string, unknown>) => ({ ...prev, view: id }) as never })

  const closeSheet = () =>
    navigate({
      search: (prev: Record<string, unknown>) => {
        const { view: _view, ...rest } = prev
        return rest as never
      },
    })

  useRowClickBridge('data-membership-card-id', openCard)

  return (
    <>
      <ResourceTable<MembershipCard>
        tableKey="membership-cards"
        queryKey="membership-cards"
        queryFn={(params) => adminClient.membershipCards.list(params)}
        searchParams={search}
      />

      {search.view && (
        <MembershipCardSheet storeId={storeId} cardId={search.view} onClose={closeSheet} />
      )}
    </>
  )
}
