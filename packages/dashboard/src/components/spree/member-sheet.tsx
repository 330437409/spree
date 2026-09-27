import {
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
} from '@spree/dashboard-ui'
import { Link } from '@tanstack/react-router'
import { useTranslation } from 'react-i18next'
import { useMembership } from '../../hooks/use-memberships'
import { tierName } from '../../lib/membership'

/**
 * One term: whose it is, which tier it holds and until when. Read-only — a term
 * is written by a card's activation and moved by the sweep — so the sheet is
 * the whole record rather than a form, with the way to the customer who holds
 * it at the bottom.
 */
export function MemberSheet({
  storeId,
  memberId,
  onClose,
}: {
  storeId: string
  memberId: string
  onClose: () => void
}) {
  const { t } = useTranslation()
  const { data: term, isLoading } = useMembership(memberId)

  return (
    <Sheet open onOpenChange={(open) => !open && onClose()}>
      <SheetContent className="flex flex-col sm:max-w-md">
        <SheetHeader>
          <SheetTitle>{term?.customer_email ?? ''}</SheetTitle>
          <SheetDescription>{t('admin.members.sheet.help')}</SheetDescription>
        </SheetHeader>

        <div className="flex flex-1 flex-col gap-4 overflow-y-auto p-4">
          {isLoading ? (
            <Skeleton className="h-40 w-full rounded-lg" />
          ) : term ? (
            <>
              <Card className="py-0">
                <CardContent className="p-0">
                  <DetailList>
                    <DetailRow
                      label={t('admin.members.columns.tier')}
                      value={tierName(term.tier)}
                    />
                    <DetailRow
                      label={t('admin.fields.status.label')}
                      value={
                        <StatusBadge
                          status={term.status}
                          label={t(`admin.members.status.${term.status}`)}
                        />
                      }
                    />
                    <DetailRow
                      label={t('admin.members.columns.starts_at')}
                      value={term.starts_at ? <RelativeTime iso={term.starts_at} /> : '—'}
                    />
                    <DetailRow
                      label={t('admin.members.columns.ends_at')}
                      value={
                        term.ends_at ? (
                          <RelativeTime iso={term.ends_at} />
                        ) : (
                          t('admin.members.open_ended')
                        )
                      }
                    />
                  </DetailList>
                </CardContent>
              </Card>

              <Link
                to="/$storeId/customers/$customerId"
                params={{ storeId, customerId: term.customer_id }}
                className="text-sm font-medium text-primary hover:underline"
              >
                {t('admin.members.view_customer')}
              </Link>
            </>
          ) : (
            <p className="text-sm text-destructive" role="alert">
              {t('admin.members.sheet.unavailable')}
            </p>
          )}
        </div>
      </SheetContent>
    </Sheet>
  )
}
