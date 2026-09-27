import { PageHeader, Subject, usePermissions } from '@spree/dashboard-core'
import {
  Button,
  ErrorState,
  Field,
  FieldLabel,
  FormSection,
  Input,
  ResourceLayout,
  Skeleton,
} from '@spree/dashboard-ui'
import { createFileRoute } from '@tanstack/react-router'
import { useEffect, useRef, useState } from 'react'
import { useTranslation } from 'react-i18next'
import { MembershipBannerAreas } from '../../../../../../components/spree/membership-banner-areas'
import { useCustomerGroup } from '../../../../../../hooks/use-customer-groups'
import {
  useMembershipBanner,
  useSaveMembershipBanner,
} from '../../../../../../hooks/use-membership-banner'
import { type EditableBannerArea, toAreas, toBannerArea } from '../../../../../../lib/banner-areas'

export const Route = createFileRoute(
  '/_authenticated/$storeId/loyalty/memberships/$groupId/banner',
)({
  component: MembershipBannerPage,
})

/**
 * The picture a tier's members see at the top of the member centre, and the tap
 * targets laid over it.
 *
 * The picture is a URL rather than an upload — the client renders it as a
 * background image and a merchant's banner comes from their own CDN — and the
 * targets are the client's own coordinates in rem, which is why they are placed
 * on the picture rather than typed as numbers.
 */
function MembershipBannerPage() {
  const { t } = useTranslation()
  const { groupId } = Route.useParams()
  const { data: group } = useCustomerGroup(groupId)
  const { data: banner, isLoading, isError } = useMembershipBanner(groupId)
  const saveBanner = useSaveMembershipBanner(groupId)
  const { permissions } = usePermissions()

  const [pic, setPic] = useState('')
  const [name, setName] = useState('')
  const [areas, setAreas] = useState<EditableBannerArea[]>([])

  // What the read answered, held once: it is what "unsaved changes" is measured
  // against, and rebuilding it every render would rebuild it on every pointer
  // move of a drag.
  const baseline = useRef({ pic: '', name: '', areas: [] as EditableBannerArea[] })
  const seeded = useRef(false)

  useEffect(() => {
    if (seeded.current || isLoading) return

    seeded.current = true
    const savedPic = banner?.pic ?? ''
    const savedName = banner?.name ?? ''
    const savedAreas = toAreas(banner?.areas)

    baseline.current = { pic: savedPic, name: savedName, areas: savedAreas }
    setPic(savedPic)
    setName(savedName)
    setAreas(savedAreas)
  }, [banner, isLoading])

  const canUpdate = permissions.can('update', Subject.MembershipBanner)
  const isDirty =
    pic.trim() !== baseline.current.pic.trim() ||
    name.trim() !== baseline.current.name.trim() ||
    JSON.stringify(areas.map(toBannerArea)) !==
      JSON.stringify(baseline.current.areas.map(toBannerArea))
  // What the row itself refuses: a banner with no picture, and a target the
  // client could not place — one without a link is a tap nobody can tap.
  const hasUnlinkableArea = areas.some((area) => !area.link.trim())

  async function handleSave() {
    const savedPic = pic.trim()
    const savedName = name.trim()
    const savedAreas = areas.map(toBannerArea)

    try {
      await saveBanner.mutateAsync({
        exists: !!banner,
        params: { pic: savedPic, name: savedName || null, areas: savedAreas },
      })
      // What the server now holds is the baseline, and the rows the operator is
      // looking at are the same targets they were: only the copy is trimmed.
      baseline.current = { pic: savedPic, name: savedName, areas }
      setPic(savedPic)
      setAreas(areas.map((area) => ({ ...area, ...toBannerArea(area) })))
    } catch {
      // The hook has said why: a 422 in the row's own words, or a toast.
    }
  }

  return (
    <ResourceLayout
      header={
        <PageHeader
          title={group?.name ?? ''}
          backTo="loyalty/memberships"
          actions={
            canUpdate ? (
              <Button
                size="sm"
                className="h-[2.125rem]"
                disabled={!pic.trim() || hasUnlinkableArea || !isDirty || saveBanner.isPending}
                onClick={handleSave}
              >
                {t('admin.actions.save')}
              </Button>
            ) : undefined
          }
        />
      }
      main={
        isError ? (
          <ErrorState
            title={t('admin.membership_banners.unavailable')}
            description={t('admin.membership_banners.unavailable_help')}
          />
        ) : (
          <>
            <FormSection
              title={t('admin.membership_banners.picture.title')}
              description={t('admin.membership_banners.picture.help')}
            >
              <div className="flex flex-col gap-4">
                <Field>
                  <FieldLabel htmlFor="membership-banner-pic">
                    {t('admin.membership_banners.fields.pic.label')}
                  </FieldLabel>
                  <Input
                    id="membership-banner-pic"
                    type="url"
                    value={pic}
                    placeholder={t('admin.membership_banners.fields.pic.placeholder')}
                    disabled={!canUpdate}
                    onChange={(event) => setPic(event.target.value)}
                  />
                </Field>

                <Field>
                  <FieldLabel htmlFor="membership-banner-name">
                    {t('admin.membership_banners.fields.name.label')}
                  </FieldLabel>
                  <Input
                    id="membership-banner-name"
                    value={name}
                    disabled={!canUpdate}
                    onChange={(event) => setName(event.target.value)}
                  />
                </Field>
              </div>
            </FormSection>

            <FormSection
              title={t('admin.membership_banners.targets.title')}
              description={t('admin.membership_banners.targets.help')}
            >
              {isLoading ? (
                <Skeleton className="h-64 w-full rounded-lg" />
              ) : canUpdate ? (
                <MembershipBannerAreas pic={pic.trim()} areas={areas} onChange={setAreas} />
              ) : (
                <p className="text-sm text-muted-foreground">
                  {t('admin.membership_banners.read_only')}
                </p>
              )}

              {hasUnlinkableArea && (
                <p className="text-sm text-destructive" role="alert">
                  {t('admin.membership_banners.unlinkable_area')}
                </p>
              )}
            </FormSection>
          </>
        )
      }
    />
  )
}
