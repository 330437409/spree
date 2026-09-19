/**
 * One node of the administrative tree the service-area pickers cascade
 * through, as `GET /administrative_divisions` answers it.
 *
 * A node is addressed by its `code` rather than its row id: a code survives a
 * re-import of the dataset and a row id does not, so a code is what a form
 * stores and sends back.
 */
export interface AdministrativeDivision {
  /** GB/T 2260 for a province, city or district; the statistics bureau's code deeper; `CN` at the root. */
  code: string
  name: string
  /** `country` | `province` | `city` | `district` | `township` */
  level: string
  /** The initial a picker anchors its A–Z index on. */
  first_pinyin: string
  /** Whether asking again for this node's children is worth a round trip. */
  has_children: boolean
}

export type AdministrativeDivisionListParams = {
  /** The node whose children to answer. Omit for the top of the tree. */
  parent_code?: string
  /** Search by name or by the dataset's romanisation. */
  keywords?: string
  /** One level of the tree — `province` when nothing else is asked for. */
  level?: string
}
