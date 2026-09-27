import type { Membership } from '@spree/admin-sdk'
import { adminClient, ResourceTable, resourceSearchSchema } from '@spree/dashboard-core'
import { useRowClickBridge } from '@spree/dashboard-ui'
import { createFileRoute, useNavigate } from '@tanstack/react-router'
import { z } from 'zod/v4'
import { MemberSheet } from '../../../../../components/spree/member-sheet'
import '../../../../../tables/members'

const membersSearchSchema = resourceSearchSchema.extend({
  view: z.string().optional(),
})

export const Route = createFileRoute('/_authenticated/$storeId/loyalty/members/')({
  validateSearch: membersSearchSchema,
  component: MembersPage,
})

/**
 * Who holds which tier, and until when. Read-only: a term is written by a card's
 * activation and moved by the sweep, so nothing on this page edits one — what it
 * answers is whose membership to look up, and how it is going.
 */
function MembersPage() {
  const { storeId } = Route.useParams()
  const search = Route.useSearch() as z.infer<typeof membersSearchSchema>
  const navigate = useNavigate()

  const openTerm = (id: string) =>
    navigate({ search: (prev: Record<string, unknown>) => ({ ...prev, view: id }) as never })

  const closeSheet = () =>
    navigate({
      search: (prev: Record<string, unknown>) => {
        const { view: _view, ...rest } = prev
        return rest as never
      },
    })

  useRowClickBridge('data-member-id', openTerm)

  return (
    <>
      <ResourceTable<Membership>
        tableKey="members"
        queryKey="members"
        queryFn={(params) => adminClient.memberships.list(params)}
        searchParams={search}
      />

      {search.view && <MemberSheet storeId={storeId} memberId={search.view} onClose={closeSheet} />}
    </>
  )
}
