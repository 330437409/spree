import { adminClient, Subject, usePermissions, useResourceKey } from '@spree/dashboard-core'
import {
  Button,
  Card,
  CardContent,
  DetailList,
  DetailRow,
  RelativeTime,
  Sheet,
  SheetContent,
  SheetDescription,
  SheetHeader,
  SheetTitle,
  Skeleton,
  StatusBadge,
  useConfirm,
} from '@spree/dashboard-ui'
import { useQuery } from '@tanstack/react-query'
import { Link } from '@tanstack/react-router'
import { useTranslation } from 'react-i18next'
import { useRecycleMembershipCard } from '../../hooks/use-membership-cards'
import { tierName } from '../../lib/membership'

/**
 * One card: whose it is, what it grants, where it came from and what became of
 * it — everything a support desk needs to answer "where did this card go",
 * with the one write this surface has at the bottom.
 */
export function MembershipCardSheet({
  storeId,
  cardId,
  onClose,
}: {
  storeId: string
  cardId: string
  onClose: () => void
}) {
  const { t } = useTranslation()
  const { permissions } = usePermissions()
  const confirm = useConfirm()
  const recycle = useRecycleMembershipCard()

  const { data: card, isLoading } = useQuery({
    queryKey: useResourceKey('membership-cards', cardId),
    queryFn: () => adminClient.membershipCards.get(cardId),
  })

  const canVoid = permissions.can('update', Subject.MembershipCard)
  const endsAt = (card?.membership as { ends_at?: string | null } | null)?.ends_at

  async function handleVoid() {
    if (!card) return

    const ok = await confirm({
      title: t('admin.membership_cards.void_confirm.title'),
      // What a void actually does: two cards of one tier share a single term,
      // so voiding one gives back the days it granted rather than the whole
      // membership.
      message: t('admin.membership_cards.void_confirm.message', {
        customer: card.customer_email ?? '',
      }),
      variant: 'destructive',
      confirmLabel: t('admin.membership_cards.void_confirm.confirm'),
    })
    if (!ok) return

    await recycle.mutateAsync({ id: card.id }).catch(() => undefined)
  }

  return (
    <Sheet open onOpenChange={(open) => !open && onClose()}>
      <SheetContent className="flex flex-col sm:max-w-md">
        <SheetHeader>
          <SheetTitle>{card?.customer_email ?? ''}</SheetTitle>
          <SheetDescription>{t('admin.membership_cards.sheet.help')}</SheetDescription>
        </SheetHeader>

        <div className="flex flex-1 flex-col gap-4 overflow-y-auto p-4">
          {isLoading ? (
            <Skeleton className="h-56 w-full rounded-lg" />
          ) : card ? (
            <>
              <Card className="py-0">
                <CardContent className="p-0">
                  <DetailList>
                    <DetailRow
                      label={t('admin.membership_cards.columns.tier')}
                      value={tierName(card.tier)}
                    />
                    <DetailRow
                      label={t('admin.fields.status.label')}
                      value={
                        <StatusBadge
                          status={card.status}
                          label={t(`admin.membership_cards.status.${card.status}`)}
                        />
                      }
                    />
                    <DetailRow
                      label={t('admin.membership_cards.columns.source')}
                      value={t(`admin.membership_cards.source.${card.source}`)}
                    />
                    <DetailRow
                      label={t('admin.membership_cards.columns.activated_at')}
                      value={card.activated_at ? <RelativeTime iso={card.activated_at} /> : '—'}
                    />
                    <DetailRow
                      label={t('admin.membership_cards.activate_before')}
                      value={
                        card.activates_before ? <RelativeTime iso={card.activates_before} /> : '—'
                      }
                    />
                    <DetailRow
                      label={t('admin.membership_cards.columns.expires_at')}
                      value={endsAt ? <RelativeTime iso={endsAt} /> : '—'}
                    />
                    <DetailRow
                      label={t('admin.membership_cards.giftable')}
                      value={card.giftable ? t('admin.common.yes') : t('admin.common.no')}
                    />
                  </DetailList>
                </CardContent>
              </Card>

              <Link
                to="/$storeId/customers/$customerId"
                params={{ storeId, customerId: card.customer_id }}
                className="text-sm font-medium text-primary hover:underline"
              >
                {t('admin.membership_cards.view_customer')}
              </Link>

              {canVoid && card.status !== 'recycled' && (
                <Button
                  type="button"
                  variant="outline"
                  className="self-start text-destructive"
                  disabled={recycle.isPending}
                  onClick={handleVoid}
                >
                  {t('admin.membership_cards.void_cta')}
                </Button>
              )}
            </>
          ) : (
            <p className="text-sm text-destructive" role="alert">
              {t('admin.membership_cards.sheet.unavailable')}
            </p>
          )}
        </div>
      </SheetContent>
    </Sheet>
  )
}
