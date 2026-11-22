// Escenario 1 (H2.3): crear un perfil con passkey y entrar en la app.
// Automatiza el paso que en F0 se hizo a mano (y que falló por pulsar "Sign in" sin perfil).
import { test, expect } from '@playwright/test'
import { addVirtualPasskey, credentialCount } from '../helpers/passkey.js'

test('crear perfil con passkey y entrar', async ({ page }) => {
  const { cdp, authenticatorId } = await addVirtualPasskey(page)
  // Nombre único: el stack e2e conserva los perfiles entre ejecuciones hasta `down -v`.
  const name = `e2e-${Date.now()}`

  await page.goto('/')

  // Pantalla de inicio (Login.jsx): sin perfil, hay que crear uno, no iniciar sesión.
  await expect(page.getByRole('button', { name: 'Sign in with passkey' })).toBeVisible()
  await page.getByRole('button', { name: 'Create new profile' }).click()

  // Formulario "Create your profile".
  await expect(page.getByRole('heading', { name: 'Create your profile' })).toBeVisible()
  await page.getByPlaceholder('Your name').fill(name)
  await page.getByRole('button', { name: 'Create passkey' }).click()

  // Login.jsx muestra "Welcome, {nombre}" cuando el registro termina en un navegador sin datos.
  await expect(page.getByText(`Welcome, ${name}`)).toBeVisible()
  // Ya no se ve la pantalla de inicio de sesión.
  await expect(page.getByRole('button', { name: 'Sign in with passkey' })).toHaveCount(0)
  // El autenticador guardó exactamente una passkey.
  expect(await credentialCount(cdp, authenticatorId)).toBe(1)
})
