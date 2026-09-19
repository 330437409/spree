import { useQuery } from '@tanstack/react-query'
import { getApiClient, type PanelAdministrativeDivision } from '../api-client'

/**
 * The children of one node of the administrative tree, keyed by the node.
 *
 * The tree is reference data — it changes when a new dataset release is
 * imported and not between two requests — so a node's children are fetched once
 * per page and shared by every picker that opens the same step: the province
 * list is the same list for every warehouse form in the panel.
 *
 * `null` asks for the top of the tree, which is the province list a picker
 * opens with.
 */
export function useAdministrativeDivisionChildren(parentCode: string | null) {
  return useQuery({
    queryKey: ['administrative_divisions', parentCode ?? 'root'],
    queryFn: async (): Promise<{ data: PanelAdministrativeDivision[] }> => {
      const list = getApiClient().listAdministrativeDivisions
      if (!list) return { data: [] }

      return list(parentCode ? { parent_code: parentCode } : {})
    },
    // A release is an import, not a request; nothing within a session invalidates
    // this, and a reload picks up a new release.
    staleTime: Number.POSITIVE_INFINITY,
  })
}
