// Escenarios 2 y 4 (H2.3) en un solo test, porque cada paso necesita el estado del anterior:
//   2. registrar un entreno libre con 1 ejercicio y 1 serie, y verlo en Stats → Recent workouts
//   4. cerrar sesión, volver a entrar con la misma passkey y comprobar que el entreno sigue
// El escenario 3 (PR detectado) queda pendiente: hace falta escribir un peso en la serie, y el
// campo de peso todavía no está verificado en el código (ver docs/fork/PLAN-MEJORAS.md, H2.3).
import { test, expect } from '@playwright/test'
import { addVirtualPasskey } from '../helpers/passkey.js'
import { createProfile } from '../helpers/app.js'

test('registrar un entreno y conservarlo tras volver a entrar', async ({ page }) => {
  await addVirtualPasskey(page)
  await createProfile(page)

  await test.step('escenario 2: entreno libre con 1 serie', async () => {
    // Botón central de la barra (TabBar.jsx). Sin rutinas, abre el selector de inicio.
    await page.locator('#tabbar button.start').click()
    await expect(page.getByRole('heading', { name: 'Start workout' })).toBeVisible()
    await page.getByRole('button', { name: 'Freestyle workout (pick as you go)' }).click()
    await expect(page.getByText('Freestyle workout. Add your first exercise and off you go.')).toBeVisible()

    // Fila "Add exercise" al final del entreno → selector de ejercicios (sheets.jsx).
    await page.getByRole('button', { name: 'Add exercise' }).click()
    await page.getByPlaceholder(/^Search .* exercises/).fill('barbell bench press')
    // Botón "+" de la fila: aria-label 'Add “<nombre>”'. El nombre puede salir capitalizado.
    await page.getByRole('button', { name: /^Add “barbell bench press”$/i }).click()
    // El "+" añade pero deja el selector abierto (sirve para añadir varios). Se cierra con
    // Escape (Modals.jsx cierra la hoja de arriba) y se espera a que el panel desaparezca,
    // porque si no tapa la serie y el clic no llega (fallo del 22-nov, 14-e2e.log).
    await page.keyboard.press('Escape')
    await expect(page.locator('#modal-root.open')).toHaveCount(0)

    // Casilla de la serie 1 (Check en ui.jsx: role=checkbox, label 'Set {0} done').
    const set1 = page.getByRole('checkbox', { name: 'Set 1 done' })
    await set1.click()
    await expect(set1).toHaveAttribute('aria-checked', 'true')

    // Terminar → hoja de cierre → "Finish and save".
    await page.getByRole('button', { name: 'Finish', exact: true }).click()
    await page.getByRole('button', { name: 'Finish and save' }).click()

    // Al guardar se abre la hoja "Workout complete!" con el resumen (16-e2e.log). Se comprueba
    // que cuenta 1 serie y se cierra con "Nice!" antes de navegar, o tapa la barra.
    const done = page.locator('#modal-root')
    await expect(done.getByRole('heading', { name: 'Workout complete!' })).toBeVisible()
    await expect(done.getByText(/1 set/).first()).toBeVisible()
    await done.getByRole('button', { name: 'Nice!' }).click()
    await expect(page.locator('#modal-root.open')).toHaveCount(0)
    // Navegar con la barra, no con page.goto: recargar la SPA la manda a Inicio (15-e2e.log).
    await page.locator('#tabbar').getByRole('button', { name: 'Stats' }).click()
    await expect(page.getByRole('heading', { name: 'Recent workouts' })).toBeVisible()
    // Stats.jsx: junto al título va el botón "All {n}" con el número de entrenos guardados.
    await expect(page.getByRole('button', { name: /^All\s*1$/ })).toBeVisible()
  })

  await test.step('escenario 4: cerrar sesión y volver a entrar', async () => {
    // Ajustes se abre desde Inicio (botón "Settings" de la cabecera).
    await page.locator('#tabbar').getByRole('button', { name: 'Home' }).click()
    await page.getByRole('button', { name: 'Settings', exact: true }).click()
    // "Sign out" vive dentro de la subpágina de cuenta (fila "<nombre> Account, devices and
    // sync"), no en la portada de Ajustes (17-e2e.log).
    await page.getByRole('button', { name: /Account, devices and sync/ }).click()
    await page.getByRole('button', { name: 'Sign out', exact: true }).click()
    // La hoja de confirmación (en #modal-root) tiene su propio botón "Sign out".
    await page.locator('#modal-root').getByRole('button', { name: 'Sign out', exact: true }).click()

    await expect(page.getByRole('button', { name: 'Sign in with passkey' })).toBeVisible()
    // La passkey virtual sigue en el navegador: el login la usa sin escribir el nombre.
    await page.getByRole('button', { name: 'Sign in with passkey' }).click()
    await expect(page.getByText(/^Welcome back, /)).toBeVisible()

    await page.locator('#tabbar').getByRole('button', { name: 'Stats' }).click()
    await expect(page.getByRole('heading', { name: 'Recent workouts' })).toBeVisible()
    await expect(page.getByRole('button', { name: /^All\s*1$/ })).toBeVisible()
  })
})
