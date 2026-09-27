import { adminClient, useResourceKey } from '@spree/dashboard-core'
import { useQuery } from '@tanstack/react-query'

/** One term, for the sheet a member row opens. */
export function useMembership(id: string | undefined) {
  return useQuery({
    queryKey: useResourceKey('memberships', id ?? 'noop'),
    queryFn: () => adminClient.memberships.get(id as string),
    enabled: !!id,
  })
}
