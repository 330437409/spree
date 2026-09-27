import type { MembershipRight, PreferenceField, ResourceTypeDefinition } from '@spree/admin-sdk'
import {
  defaultPreferences,
  PreferencesForm,
  Subject,
  typeDescription,
  typeLabel,
  usePermissions,
} from '@spree/dashboard-core'
import {
  Button,
  Field,
  FieldGroup,
  FieldLabel,
  Input,
  Sheet,
  SheetContent,
  SheetDescription,
  SheetFooter,
  SheetHeader,
  SheetTitle,
  Switch,
  Textarea,
} from '@spree/dashboard-ui'
import { useState } from 'react'
import { useTranslation } from 'react-i18next'
import {
  useCreateMembershipRight,
  useUpdateMembershipRight,
} from '../../hooks/use-membership-rights'
import {
  type MembershipRightFormValues,
  membershipRightToFormValues,
  membershipRightValuesToParams,
} from '../../schemas/membership-right'
import { TypePicker } from './type-picker'

/**
 * One right of a tier, added or edited in a sheet of its own: the kind it is,
 * the operator's own words for it, and the settings that kind declares —
 * rendered from what the kind says about itself, so a kind an extension gem
 * adds is editable here with no change to this file.
 *
 * Adding starts by picking a kind, because a right is what its kind grants;
 * editing one keeps the kind it was created as.
 */
export function MembershipRightSheet({
  groupId,
  right,
  types,
  usedTypes,
  onClose,
}: {
  groupId: string
  /** The right being edited, or nothing when one is being added. */
  right?: MembershipRight
  /** Every kind the registry declares. */
  types: ResourceTypeDefinition[]
  /** The kinds this tier already carries — a tier carries one of each. */
  usedTypes: string[]
  onClose: () => void
}) {
  const { t } = useTranslation()
  const { permissions } = usePermissions()
  const createMutation = useCreateMembershipRight(groupId)
  const updateMutation = useUpdateMembershipRight(groupId)

  const [type, setType] = useState(right?.type ?? '')
  const [values, setValues] = useState<MembershipRightFormValues>(() =>
    right ? membershipRightToFormValues(right) : { name: '', description: '', preferences: {} },
  )
  const [published, setPublished] = useState(right?.published ?? true)

  const definition = types.find((candidate) => candidate.type === type)
  const availableTypes = types.filter((candidate) => !usedTypes.includes(candidate.type))
  const editing = !!right
  const saving = createMutation.isPending || updateMutation.isPending
  // The door the operator came through is the one the write is checked
  // against: adding is a create, editing an update.
  const canWrite = permissions.can(right ? 'update' : 'create', Subject.MembershipRight)

  function pickKind(kind: ResourceTypeDefinition) {
    setType(kind.type)
    setValues({
      name: '',
      description: '',
      // What the kind declares where the operator has written nothing: the
      // fields open on the defaults rather than blank, and what is on screen
      // is what saving writes.
      preferences: defaultPreferences(kind.preference_schema as unknown as PreferenceField[]),
    })
  }

  async function handleSave() {
    const params = { ...membershipRightValuesToParams(values), published }

    try {
      if (right) {
        await updateMutation.mutateAsync({ id: right.id, params })
      } else {
        await createMutation.mutateAsync({ type, ...params })
      }
      onClose()
    } catch {
      // The hook has said why, and the sheet stays open on what was typed.
    }
  }

  const kindLabel = typeLabel('membership_right', type, definition?.label)

  return (
    <Sheet open onOpenChange={(open) => !open && onClose()}>
      <SheetContent className="flex flex-col sm:max-w-md">
        <SheetHeader>
          <SheetTitle>
            {editing ? right?.name?.trim() || kindLabel : t('admin.membership_rights.new.title')}
          </SheetTitle>
          <SheetDescription>
            {editing
              ? t('admin.membership_rights.edit.help')
              : t('admin.membership_rights.new.help')}
          </SheetDescription>
        </SheetHeader>

        <div className="flex min-h-0 flex-1 flex-col gap-4 overflow-y-auto p-4">
          {!editing && !type ? (
            <TypePicker
              family="membership_right"
              titleKey="admin.membership_rights.picker.title"
              types={availableTypes}
              disabled={createMutation.isPending}
              onPick={pickKind}
              onCancel={onClose}
            />
          ) : (
            <>
              <div className="flex flex-col gap-1 rounded-md border bg-muted/40 px-3 py-2">
                <span className="text-sm">{kindLabel}</span>
                {typeDescription('membership_right', type, definition?.description) && (
                  <span className="text-xs text-muted-foreground">
                    {typeDescription('membership_right', type, definition?.description)}
                  </span>
                )}
              </div>

              <FieldGroup>
                <Field>
                  <FieldLabel htmlFor="membership-right-name">
                    {t('admin.fields.name.label')}
                  </FieldLabel>
                  <Input
                    id="membership-right-name"
                    disabled={!canWrite}
                    value={values.name ?? ''}
                    onChange={(event) =>
                      setValues((prev) => ({ ...prev, name: event.target.value }))
                    }
                    placeholder={kindLabel}
                  />
                  <p className="text-xs text-muted-foreground">
                    {t('admin.membership_rights.name.help')}
                  </p>
                </Field>

                <Field>
                  <FieldLabel htmlFor="membership-right-description">
                    {t('admin.fields.description.label')}
                  </FieldLabel>
                  <Textarea
                    id="membership-right-description"
                    disabled={!canWrite}
                    value={values.description ?? ''}
                    onChange={(event) =>
                      setValues((prev) => ({ ...prev, description: event.target.value }))
                    }
                  />
                </Field>
              </FieldGroup>

              {definition && definition.preference_schema.length > 0 && (
                <PreferencesForm
                  schema={definition.preference_schema as unknown as PreferenceField[]}
                  values={values.preferences}
                  onChange={(preferences) => setValues((prev) => ({ ...prev, preferences }))}
                />
              )}

              <Field orientation="horizontal">
                <FieldLabel htmlFor="membership-right-published">
                  {t('admin.membership_rights.published')}
                </FieldLabel>
                <Switch
                  id="membership-right-published"
                  checked={published}
                  disabled={!canWrite}
                  onCheckedChange={setPublished}
                />
              </Field>
            </>
          )}
        </div>

        <SheetFooter>
          <Button type="button" variant="outline" onClick={onClose}>
            {t('admin.actions.cancel')}
          </Button>
          <Button type="button" onClick={handleSave} disabled={!type || !canWrite || saving}>
            {t('admin.actions.save')}
          </Button>
        </SheetFooter>
      </SheetContent>
    </Sheet>
  )
}
