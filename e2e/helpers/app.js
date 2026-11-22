// Pasos compartidos por los tests e2e. Los textos son las claves en inglés del código
// (la config fija locale en-US), verificados en Login.jsx, Tour.jsx, TabBar.jsx, Workout.jsx,
// sheets.jsx y Settings.jsx el 22-nov-2026. Si el upstream cambia un texto, falla aquí, en un solo sitio.
import { expect } from '@playwright/test'

/** Crea un perfil nuevo con la passkey virtual ya añadida a la página. Devuelve el nombre. */
export async function createProfile(page) {
  const name = `e2e-${Date.now()}`
  await page.goto('/')
  await page.getByRole('button', { name: 'Create new profile' }).click()
  await page.getByPlaceholder('Your name').fill(name)
  await page.getByRole('button', { name: 'Create passkey' }).click()
  await expect(page.getByText(`Welcome, ${name}`)).toBeVisible()
  await skipTourIfOffered(page)
  return name
}

/**
 * Un perfil nuevo recibe la pregunta "Want a 1-minute tour?" (Tour.jsx, Question). Tapa la
 * pantalla, así que se descarta con "Skip". Si no aparece en 5 s, se sigue sin hacer nada.
 */
export async function skipTourIfOffered(page) {
  const skip = page.locator('.tour-ask').getByRole('button', { name: 'Skip' })
  try {
    await skip.waitFor({ state: 'visible', timeout: 5_000 })
    await skip.click()
    await expect(page.locator('.tour-ask')).toHaveCount(0)
  } catch { /* sin tour: nada que hacer */ }
}
