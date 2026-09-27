import { PageHeader, ResourceLayout, Subject, usePermissions } from '@spree/dashboard-core'
import {
  Button,
  Card,
  CardContent,
  Field,
  FieldLabel,
  FormSection,
  Input,
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
import { type BannerArea, toAreas } from '../../../../../../lib/banner-areas'

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
  const { data: banner, isLoading } = useMembershipBanner(groupId)
  const saveBanner = useSaveMembershipBanner(groupId)
  const { permissions } = usePermissions()

  const [pic, setPic] = useState('')
  const [name, setName] = useState('')
  const [areas, setAreas] = useState<BannerArea[]>([])

  // Seeded once, from the read that opened the page: what the operator types
  // afterwards is theirs, and a refetch must not write over it.
  const seeded = useRef(false)
  useEffect(() => {
    if (seeded.current || isLoading) return

    seeded.current = true
    setPic(banner?.pic ?? '')
    setName(banner?.name ?? '')
    setAreas(toAreas(banner?.areas))
  }, [banner, isLoading])

  const canUpdate = permissions.can('update', Subject.MembershipTierSetting)
  const saved = {
    pic: banner?.pic ?? '',
    name: banner?.name ?? '',
    areas: toAreas(banner?.areas),
  }
  const isDirty =
    pic !== saved.pic ||
    name !== saved.name ||
    JSON.stringify(areas) !== JSON.stringify(saved.areas)
  // What the row itself refuses: a banner with no picture, and a target the
  // client could not place — one without a link is a tap nobody can tap.
  const hasUnlinkableArea = areas.some((area) => !area.link.trim())

  async function handleSave() {
    await saveBanner
      .mutateAsync({
        exists: !!banner,
        params: { pic: pic.trim(), name: name.trim() || null, areas },
      })
      .catch(() => undefined)
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
            ) : (
              <Card className="py-0">
                <CardContent className="p-4">
                  {canUpdate ? (
                    <MembershipBannerAreas pic={pic.trim()} areas={areas} onChange={setAreas} />
                  ) : (
                    <p className="text-sm text-muted-foreground">
                      {t('admin.membership_banners.read_only')}
                    </p>
                  )}
                </CardContent>
              </Card>
            )}

            {hasUnlinkableArea && (
              <p className="text-sm text-destructive" role="alert">
                {t('admin.membership_banners.unlinkable_area')}
              </p>
            )}
          </FormSection>
        </>
      }
    />
  )
}
