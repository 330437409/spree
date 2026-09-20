import { zodResolver } from '@hookform/resolvers/zod'
import { mapSpreeErrorsToForm, PageHeader } from '@spree/dashboard-core'
import {
  Button,
  Card,
  CardContent,
  CardHeader,
  CardTitle,
  Field,
  FieldError,
  FieldGroup,
  FieldLabel,
  Input,
  InputGroup,
  InputGroupAddon,
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
  Separator,
} from '@spree/dashboard-ui'
import { TrashIcon } from '@spree/dashboard-ui/icons'
import { Controller, useForm } from 'react-hook-form'
import { useTranslation } from 'react-i18next'
import { z } from 'zod'
import { ProductVariantPicker } from '../components/product-variant-picker'
import { formatAmount } from '../format'
import type { ProductBundle } from '../types'

const schema = z.object({
  title: z.string().min(1),
  status: z.enum(['draft', 'active', 'archived']),
  discount_kind: z.enum(['amount', 'percentage']),
  discount_value: z.coerce.number().min(0),
  components: z
    .array(
      z.object({
        productId: z.string().optional(),
        productName: z.string().optional(),
        variantId: z.string().min(1),
        quantity: z.coerce.number().int().min(1),
      }),
    )
    .min(1),
})

export type ProductBundleFormValues = z.infer<typeof schema>

interface ProductBundleFormProps {
  /** The set being edited, or undefined when the merchant is creating one. */
  bundle?: ProductBundle
  onSubmit: (values: ProductBundleFormValues) => Promise<void>
}

/**
 * A set's composition and its rule, as one form.
 *
 * The figures beside it are the server's: what the components cost one by one,
 * what the set costs and what it saves. They are computed where the prices are,
 * so the merchant reads them after saving rather than watching a second
 * calculation disagree with the first.
 */
export function ProductBundleForm({ bundle, onSubmit }: ProductBundleFormProps) {
  const { t } = useTranslation()

  const form = useForm<ProductBundleFormValues>({
    // The zod v4 resolver's generics do not line up with RHF's own unless the
    // schema and the form type are declared together; the cast is what core's
    // own forms do.
    resolver: zodResolver(schema) as never,
    defaultValues: {
      title: bundle?.title ?? '',
      status: bundle?.status ?? 'draft',
      discount_kind: (bundle?.saving_kind as 'amount' | 'percentage') ?? 'amount',
      discount_value: bundle?.saving_value ?? 0,
      components: bundle?.components.map((component) => ({
        productId: component.product_id ?? undefined,
        variantId: component.variant_id ?? '',
        quantity: component.quantity,
      })) ?? [{ variantId: '', quantity: 1 }],
    },
  })

  const components = form.watch('components')

  async function handleSubmit(values: ProductBundleFormValues) {
    try {
      await onSubmit(values)
    } catch (err) {
      if (!mapSpreeErrorsToForm(err, form.setError)) throw err
    }
  }

  return (
    <form onSubmit={form.handleSubmit(handleSubmit)}>
      <div className="space-y-6">
        <PageHeader
          title={
            bundle
              ? t('admin.product_bundles_plugin.form.edit_title')
              : t('admin.product_bundles_plugin.form.new_title')
          }
          actions={
            <Button type="submit" size="sm" disabled={form.formState.isSubmitting}>
              {t('admin.actions.save')}
            </Button>
          }
        />
        <Card>
          <CardHeader>
            <CardTitle>{t('admin.product_bundles_plugin.form.details')}</CardTitle>
          </CardHeader>
          <CardContent>
            <FieldGroup>
              <Field>
                <FieldLabel>{t('admin.product_bundles_plugin.fields.title')}</FieldLabel>
                <Input
                  {...form.register('title')}
                  aria-invalid={Boolean(form.formState.errors.title)}
                />
                <FieldError>{form.formState.errors.title?.message}</FieldError>
              </Field>

              <Field>
                <FieldLabel>{t('admin.product_bundles_plugin.fields.status')}</FieldLabel>
                <Select
                  value={form.watch('status')}
                  onValueChange={(value) =>
                    form.setValue('status', value as ProductBundle['status'])
                  }
                >
                  <SelectTrigger>
                    <SelectValue />
                  </SelectTrigger>
                  <SelectContent>
                    {(['draft', 'active', 'archived'] as const).map((status) => (
                      <SelectItem key={status} value={status}>
                        {t(`admin.product_bundles_plugin.statuses.${status}`)}
                      </SelectItem>
                    ))}
                  </SelectContent>
                </Select>
              </Field>
            </FieldGroup>
          </CardContent>
        </Card>

        <Card>
          <CardHeader>
            <CardTitle>{t('admin.product_bundles_plugin.form.composition')}</CardTitle>
          </CardHeader>
          <CardContent className="space-y-3">
            {components.map((component, index) => (
              <div key={component.variantId || `row-${index}`} className="flex items-start gap-3">
                <div className="min-w-0 flex-1">
                  <ProductVariantPicker
                    value={component}
                    onChange={(next) =>
                      form.setValue(`components.${index}`, next, { shouldDirty: true })
                    }
                  />
                </div>
                <Button
                  type="button"
                  variant="ghost"
                  size="icon"
                  disabled={components.length === 1}
                  onClick={() => {
                    const rows = components.filter((_, position) => position !== index)
                    form.setValue('components', rows, { shouldDirty: true })
                  }}
                >
                  <TrashIcon className="size-4" />
                </Button>
              </div>
            ))}

            <Button
              type="button"
              variant="outline"
              size="sm"
              onClick={() =>
                form.setValue('components', [...components, { variantId: '', quantity: 1 }], {
                  shouldDirty: true,
                })
              }
            >
              {t('admin.product_bundles_plugin.form.add_component')}
            </Button>
            <FieldError>{form.formState.errors.components?.message}</FieldError>
          </CardContent>
        </Card>

        <Card>
          <CardHeader>
            <CardTitle>{t('admin.product_bundles_plugin.form.rule')}</CardTitle>
          </CardHeader>
          <CardContent className="space-y-4">
            <FieldGroup>
              <Field>
                <FieldLabel>{t('admin.product_bundles_plugin.form.discount_kind')}</FieldLabel>
                <Select
                  value={form.watch('discount_kind')}
                  onValueChange={(value) =>
                    form.setValue('discount_kind', value as 'amount' | 'percentage', {
                      shouldDirty: true,
                    })
                  }
                >
                  <SelectTrigger>
                    <SelectValue />
                  </SelectTrigger>
                  <SelectContent>
                    <SelectItem value="amount">
                      {t('admin.product_bundles_plugin.form.kind_amount')}
                    </SelectItem>
                    <SelectItem value="percentage">
                      {t('admin.product_bundles_plugin.form.kind_percentage')}
                    </SelectItem>
                  </SelectContent>
                </Select>
              </Field>

              <Field>
                <FieldLabel>{t('admin.product_bundles_plugin.fields.saving')}</FieldLabel>
                <Controller
                  control={form.control}
                  name="discount_value"
                  render={({ field }) => (
                    <InputGroup>
                      {form.watch('discount_kind') === 'amount' && (
                        <InputGroupAddon align="inline-start">
                          {bundle?.currency ?? '¥'}
                        </InputGroupAddon>
                      )}
                      <Input
                        type="number"
                        min={0}
                        step={form.watch('discount_kind') === 'percentage' ? 1 : 0.01}
                        value={field.value}
                        onChange={(event) => field.onChange(event.target.value)}
                      />
                      {form.watch('discount_kind') === 'percentage' && (
                        <InputGroupAddon align="inline-end">%</InputGroupAddon>
                      )}
                    </InputGroup>
                  )}
                />
              </Field>
            </FieldGroup>
          </CardContent>
        </Card>

        {bundle && (
          <Card>
            <CardHeader>
              <CardTitle>{t('admin.product_bundles_plugin.form.figures')}</CardTitle>
            </CardHeader>
            <CardContent className="space-y-2 text-sm">
              <div className="flex justify-between">
                <span>{t('admin.product_bundles_plugin.fields.goods_price')}</span>
                <span className="tabular-nums">
                  {formatAmount(bundle.goods_price, bundle.currency)}
                </span>
              </div>
              <Separator />
              <div className="flex justify-between">
                <span>{t('admin.product_bundles_plugin.fields.saving')}</span>
                <span className="tabular-nums">{formatAmount(bundle.saving, bundle.currency)}</span>
              </div>
              <Separator />
              <div className="flex justify-between font-medium">
                <span>{t('admin.product_bundles_plugin.fields.price')}</span>
                <span className="tabular-nums">{formatAmount(bundle.price, bundle.currency)}</span>
              </div>
            </CardContent>
          </Card>
        )}
      </div>
    </form>
  )
}
