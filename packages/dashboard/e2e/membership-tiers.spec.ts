import { expect, type Page, test } from '@playwright/test'
import { gotoIndex, login, rowButton } from './helpers'

const GROUPS_PATH = (storeId: string) => `/${storeId}/customers/groups`
const TIERS_PATH = (storeId: string) => `/${storeId}/loyalty/memberships`

/**
 * A tier is a customer group carrying settings, so the operator's path starts
 * on the group: make one, then make it a tier from the ladder.
 */
async function createCustomerGroup(page: Page, storeId: string, name: string) {
  await gotoIndex(page, GROUPS_PATH(storeId), /add customer group/i)
  await page.getByRole('button', { name: /add customer group/i }).click()
  await expect(page.getByRole('heading', { name: /add customer group/i })).toBeVisible()

  await page.locator('#name').fill(name)
  await page.getByRole('button', { name: /create customer group/i }).click()

  await expect(rowButton(page, name)).toBeVisible({ timeout: 15_000 })
}

/** Makes a group a rung of the ladder, and returns the tier's page. */
async function makeTier(page: Page, storeId: string, groupName: string) {
  await gotoIndex(page, TIERS_PATH(storeId), /new tier/i)
  await page.getByRole('button', { name: /^new tier$/i }).click()
  await expect(page.getByRole('heading', { name: /^new tier$/i })).toBeVisible()

  await page.locator('#membership-tier-group').fill(groupName)
  await page.getByRole('option', { name: groupName }).click()

  await page.getByRole('button', { name: /create tier/i }).click()

  await expect(page.getByRole('heading', { name: groupName })).toBeVisible({ timeout: 15_000 })
}

test.describe('membership tiers', () => {
  test('lists the ladder', async ({ page }) => {
    const creds = await login(page)
    await gotoIndex(page, TIERS_PATH(creds.store_id), /new tier/i)
  })

  test('makes a group a tier and edits what it asks for', async ({ page }) => {
    const creds = await login(page)
    const group = `E2E Tier Group ${Date.now()}`
    await createCustomerGroup(page, creds.store_id, group)

    await makeTier(page, creds.store_id, group)

    // The tier's own figures, saved from the page it was opened on.
    await page.locator('#membership-tier-threshold').fill('199')
    await page.locator('#membership-tier-validity').fill('365')
    await page.getByRole('button', { name: /^save$/i }).click()

    await expect(page.getByRole('button', { name: /^save$/i })).toBeDisabled({ timeout: 15_000 })

    // It is a rung now, with the figures read back.
    await gotoIndex(page, TIERS_PATH(creds.store_id), /new tier/i)
    await expect(rowButton(page, group)).toBeVisible({ timeout: 15_000 })
    await expect(page.getByRole('row', { name: new RegExp(group) })).toContainText('199')
  })

  test('adds a right to a tier, edits its settings and removes it', async ({ page }) => {
    const creds = await login(page)
    const group = `E2E Rights Group ${Date.now()}`
    await createCustomerGroup(page, creds.store_id, group)
    await makeTier(page, creds.store_id, group)

    await page.getByRole('button', { name: /^add right$/i }).click()
    await page.getByRole('button', { name: /birthday double points/i }).click()

    const right = page
      .getByRole('listitem')
      .filter({ hasText: /birthday double points/i })
      .first()
    await expect(right).toBeVisible({ timeout: 15_000 })

    await right.getByRole('button', { name: /^edit$/i }).click()
    await expect(right.getByText(/multiplier/i)).toBeVisible()
    await right.getByRole('button', { name: /^save$/i }).click()

    // Removed again, with the confirmation the destructive path owes.
    await right.getByRole('button', { name: /^delete$/i }).click()
    await page
      .getByRole('dialog')
      .getByRole('button', { name: /^delete$/i })
      .click()

    await expect(page.getByText(/grants nothing yet/i)).toBeVisible({ timeout: 15_000 })
  })
})
