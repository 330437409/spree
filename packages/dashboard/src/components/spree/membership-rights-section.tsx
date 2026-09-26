import {
  closestCenter,
  DndContext,
  KeyboardSensor,
  PointerSensor,
  useSensor,
  useSensors,
} from '@dnd-kit/core'
import {
  SortableContext,
  sortableKeyboardCoordinates,
  useSortable,
  verticalListSortingStrategy,
} from '@dnd-kit/sortable'
import { CSS } from '@dnd-kit/utilities'
import type { MembershipRight, PreferenceField, ResourceTypeDefinition } from '@spree/admin-sdk'
import {
  Can,
  defaultPreferences,
  PreferencesForm,
  Subject,
  typeDescription,
  typeLabel,
  usePermissions,
  useResourceKeyBuilder,
} from '@spree/dashboard-core'
import {
  Button,
  DragHandle,
  Field,
  FieldGroup,
  FieldLabel,
  FormSection,
  Input,
  Switch,
  Textarea,
  useConfirm,
} from '@spree/dashboard-ui'
import { PlusIcon, Trash2Icon } from '@spree/dashboard-ui/icons'
import { type CSSProperties, useMemo, useState } from 'react'
import { useTranslation } from 'react-i18next'
import {
  useCreateMembershipRight,
  useDeleteMembershipRight,
  useMembershipRights,
  useMembershipRightTypes,
  useUpdateMembershipRight,
} from '../../hooks/use-membership-rights'
import { useOptimisticReorder } from '../../hooks/use-optimistic-reorder'
import {
  membershipRightToFormValues,
  membershipRightValuesToParams,
} from '../../schemas/membership-right'
import { TypePicker } from './type-picker'

/**
 * What a tier carries, edited where the tier is: the rights themselves, each
 * with the settings its own kind declares.
 *
 * The writes are per-right rather than part of the tier's form — a right is a
 * row of its own and a kind's settings are its own declarations — so every
 * control here is `type="button"` and the tier's Save button is not the door a
 * right is added through.
 */
export function MembershipRightsSection({ groupId }: { groupId: string }) {
  const { t } = useTranslation()
  const { data, isLoading } = useMembershipRights(groupId)
  const { data: typesData } = useMembershipRightTypes()
  const createMutation = useCreateMembershipRight(groupId)
  const updateMutation = useUpdateMembershipRight(groupId)
  const deleteMutation = useDeleteMembershipRight(groupId)
  const confirm = useConfirm()
  const buildKey = useResourceKeyBuilder()
  const { permissions } = usePermissions()

  const rights = data?.data ?? []
  const allTypes = useMemo(() => typesData?.data ?? [], [typesData])
  // A tier carries one right of each kind (the database says so), so only the
  // kinds it does not have are offered.
  const availableTypes = useMemo(() => {
    const used = new Set(rights.map((right) => right.type))
    return allTypes.filter((type) => !used.has(type.type))
  }, [rights, allTypes])
  const canUpdate = permissions.can('update', Subject.MembershipRight)

  const [showPicker, setShowPicker] = useState(false)
  const [editingId, setEditingId] = useState<string | null>(null)

  const sensors = useSensors(
    useSensor(PointerSensor, { activationConstraint: { distance: 5 } }),
    useSensor(KeyboardSensor, { coordinateGetter: sortableKeyboardCoordinates }),
  )

  const handleDragEnd = useOptimisticReorder({
    listKey: buildKey('customer-groups', groupId, 'membership-rights'),
    items: rights,
    reorder: (id, position, onError) =>
      updateMutation.mutate({ id, params: { position } }, { onError }),
  })

  async function handleDelete(right: MembershipRight) {
    const ok = await confirm({
      title: t('admin.membership_rights.delete_confirm.title'),
      message: t('admin.membership_rights.delete_confirm.message', {
        name: typeLabel('membership_right', right.type, definitionFor(right.type, allTypes)?.label),
      }),
      variant: 'destructive',
      confirmLabel: t('admin.actions.delete'),
    })
    if (!ok) return
    if (editingId === right.id) setEditingId(null)
    await deleteMutation.mutateAsync(right.id).catch(() => undefined)
  }

  return (
    <FormSection
      title={t('admin.membership_rights.title')}
      description={t('admin.membership_rights.help')}
      action={
        !isLoading &&
        availableTypes.length > 0 && (
          <Can I="create" a={Subject.MembershipRight}>
            <Button
              type="button"
              variant="outline"
              size="sm"
              onClick={() => setShowPicker((open) => !open)}
            >
              <PlusIcon className="size-4" />
              {t('admin.membership_rights.add_cta')}
            </Button>
          </Can>
        )
      }
    >
      {showPicker && (
        <TypePicker
          family="membership_right"
          titleKey="admin.membership_rights.picker.title"
          types={availableTypes}
          disabled={createMutation.isPending}
          onPick={(type) => {
            createMutation.mutate({ type: type.type })
            setShowPicker(false)
          }}
          onCancel={() => setShowPicker(false)}
        />
      )}

      {isLoading ? (
        <p className="text-sm text-muted-foreground">{t('admin.common.loading')}</p>
      ) : rights.length === 0 ? (
        <p className="text-sm text-muted-foreground">{t('admin.membership_rights.empty')}</p>
      ) : (
        <DndContext sensors={sensors} collisionDetection={closestCenter} onDragEnd={handleDragEnd}>
          <SortableContext
            items={rights.map((right) => right.id)}
            strategy={verticalListSortingStrategy}
          >
            <ul className="flex flex-col gap-1">
              {rights.map((right) => (
                <SortableRightRow
                  key={right.id}
                  right={right}
                  definition={definitionFor(right.type, allTypes)}
                  canUpdate={canUpdate}
                  canDestroy={permissions.can('destroy', Subject.MembershipRight)}
                  editing={editingId === right.id}
                  onTogglePublished={(published) =>
                    updateMutation.mutate({ id: right.id, params: { published } })
                  }
                  onToggleEdit={() => setEditingId(editingId === right.id ? null : right.id)}
                  // Closed only once the write lands: a refusal leaves the
                  // editor open on what the operator typed, with the reason
                  // toasted beside it.
                  onSave={async (values) => {
                    try {
                      await updateMutation.mutateAsync({
                        id: right.id,
                        params: membershipRightValuesToParams(values),
                      })
                      setEditingId(null)
                    } catch {
                      // The hook has said why; the editor stays as it is.
                    }
                  }}
                  onDelete={() => handleDelete(right)}
                />
              ))}
            </ul>
          </SortableContext>
        </DndContext>
      )}
    </FormSection>
  )
}

function definitionFor(type: string, types: ResourceTypeDefinition[]) {
  return types.find((candidate) => candidate.type === type)
}

function SortableRightRow({
  right,
  definition,
  canUpdate,
  canDestroy,
  editing,
  onTogglePublished,
  onToggleEdit,
  onSave,
  onDelete,
}: {
  right: MembershipRight
  definition?: ResourceTypeDefinition
  canUpdate: boolean
  canDestroy: boolean
  editing: boolean
  onTogglePublished: (published: boolean) => void
  onToggleEdit: () => void
  onSave: (values: ReturnType<typeof membershipRightToFormValues>) => void
  onDelete: () => void
}) {
  const { t } = useTranslation()
  const { attributes, listeners, setNodeRef, transform, transition, isDragging } = useSortable({
    id: right.id,
    disabled: !canUpdate,
  })
  const style: CSSProperties = { transform: CSS.Transform.toString(transform), transition }
  const label = typeLabel('membership_right', right.type, definition?.label)
  const description = typeDescription('membership_right', right.type, definition?.description)

  return (
    <li
      ref={setNodeRef}
      style={style}
      className={`rounded-md border bg-card ${isDragging ? 'relative z-10 opacity-80 shadow-lg' : ''}`}
    >
      <div className="flex items-center gap-2 p-2">
        {canUpdate && (
          <span className="w-6 touch-none">
            <DragHandle attributes={attributes} listeners={listeners} />
          </span>
        )}
        <div className="min-w-0 flex-1">
          <span className="block truncate text-sm" title={description || undefined}>
            {right.name?.trim() || label}
          </span>
          {!right.published && (
            <span className="text-xs text-muted-foreground">
              {t('admin.membership_rights.draft')}
            </span>
          )}
        </div>
        <Switch
          checked={right.published}
          disabled={!canUpdate}
          aria-label={t('admin.membership_rights.published')}
          onCheckedChange={onTogglePublished}
        />
        <Button
          type="button"
          variant="ghost"
          size="sm"
          disabled={!canUpdate}
          onClick={onToggleEdit}
        >
          {editing ? t('admin.actions.close') : t('admin.actions.edit')}
        </Button>
        {canDestroy && (
          <Button
            type="button"
            variant="ghost"
            size="icon"
            aria-label={t('admin.actions.delete')}
            onClick={onDelete}
          >
            <Trash2Icon className="size-4" />
          </Button>
        )}
      </div>

      {editing && (
        // Seeded when it opens and its own draft afterwards: a write to this row
        // from anywhere else — the switch beside it, another tab — leaves what
        // somebody is typing alone.
        <RightEditor
          right={right}
          schema={definition?.preference_schema ?? []}
          canUpdate={canUpdate}
          onSave={onSave}
          onCancel={onToggleEdit}
        />
      )}
    </li>
  )
}

/** One right's own copy and the settings its kind declares. */
function RightEditor({
  right,
  schema,
  canUpdate,
  onSave,
  onCancel,
}: {
  right: MembershipRight
  /** The kind's declared settings, from the registry: a right's own row carries
   *  what the operator wrote, and the kind carries what may be written. */
  schema: PreferenceField[]
  canUpdate: boolean
  onSave: (values: ReturnType<typeof membershipRightToFormValues>) => void
  onCancel: () => void
}) {
  const { t } = useTranslation()
  const [values, setValues] = useState(() =>
    membershipRightToFormValues({
      ...right,
      // What the kind declares where the operator has written nothing: the
      // fields open on the defaults rather than blank, and what is on screen is
      // what saving writes.
      preferences: { ...defaultPreferences(schema), ...right.preferences },
    }),
  )

  return (
    <div className="flex flex-col gap-3 border-t p-3">
      <FieldGroup>
        <Field>
          <FieldLabel htmlFor={`membership-right-name-${right.id}`}>
            {t('admin.fields.name.label')}
          </FieldLabel>
          <Input
            id={`membership-right-name-${right.id}`}
            disabled={!canUpdate}
            value={values.name ?? ''}
            onChange={(event) => setValues((prev) => ({ ...prev, name: event.target.value }))}
          />
        </Field>
        <Field>
          <FieldLabel htmlFor={`membership-right-description-${right.id}`}>
            {t('admin.fields.description.label')}
          </FieldLabel>
          <Textarea
            id={`membership-right-description-${right.id}`}
            disabled={!canUpdate}
            value={values.description ?? ''}
            onChange={(event) =>
              setValues((prev) => ({ ...prev, description: event.target.value }))
            }
          />
        </Field>
      </FieldGroup>

      {schema.length > 0 && (
        <PreferencesForm
          schema={schema}
          values={values.preferences}
          onChange={(preferences) => setValues((prev) => ({ ...prev, preferences }))}
        />
      )}

      <div className="flex justify-end gap-2">
        <Button type="button" variant="outline" size="sm" onClick={onCancel}>
          {t('admin.actions.cancel')}
        </Button>
        <Button type="button" size="sm" disabled={!canUpdate} onClick={() => onSave(values)}>
          {t('admin.actions.save')}
        </Button>
      </div>
    </div>
  )
}
