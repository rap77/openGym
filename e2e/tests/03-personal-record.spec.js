// Escenario 3 (H2.3): una serie con peso en el primer entreno de un ejercicio cuenta como PR.
// Referencia: la prueba manual de F0 (9-nov) con press de banca 10 kg × 8 mostró "1 PR"; con
// 0 kg (escenario 2) el resumen muestra "PRs –". Hoja de resumen: FinishSummary en sheets.jsx.
import { test, expect } from '@playwright/test'
import { addVirtualPasskey } from '../helpers/passkey.js'
import { createProfile, startFreestyleWith, setRow } from '../helpers/app.js'

test('una serie con peso se detecta como PR', async ({ page }) => {
  await addVirtualPasskey(page)
  await createProfile(page)
  await startFreestyleWith(page, 'barbell bench press')

  const { check, row } = setRow(page, 1)
  const weight = row.getByRole('textbox').first()
  await weight.fill('40')
  await expect(weight).toHaveValue('40')
  await check.click()
  await expect(check).toHaveAttribute('aria-checked', 'true')

  await page.getByRole('button', { name: 'Finish', exact: true }).click()
  await page.getByRole('button', { name: 'Finish and save' }).click()

  const sheet = page.locator('#modal-root')
  await expect(sheet.getByRole('heading', { name: 'Workout complete!' })).toBeVisible()
  // Casilla "PRs" del resumen: cuenta 1 (con 0 kg muestra "–").
  await expect(sheet.locator('.tile').filter({ hasText: 'PRs' })).toContainText('1')
  // Línea "New PR: <ejercicio>" debajo de las casillas.
  await expect(sheet.getByText(/New PR:/)).toContainText(/bench press/i)
  // Volumen = 40 kg × 10 reps por defecto = 400 kg.
  await expect(sheet.locator('.tile').filter({ hasText: 'Volume' })).toContainText('400')
})
