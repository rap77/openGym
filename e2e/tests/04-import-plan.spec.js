// Importar el plan file del fork (fork-routines/atlas-movilidad-hipopresivos.opengym-plan.json)
// en la app real.
//
// Por que existe: los tests unitarios validan el motor de progresion contra datos inventados, pero
// el parser del formato de plan (lib/plan-share.js) solo se ejercita de verdad cuando el navegador
// lee el fichero. Este escenario es el que garantiza que la progresion "double" y el tempo
// "3-1-X-2" llegan a la rutina importada, y que un sync del upstream que rompa el formato del plan
// salta en CI en vez de romperse en la rutina del usuario.
//
// Tambien comprueba el caso que el indice de la biblioteca no cubre: la entrada de biblioteca
// (api/coach/core/routine-library.js) solo conserva id/sets/reps y descarta la progresion y el
// tempo. Este fichero, en cambio, los lleva. Ver docs/fork/PLAN-MEJORAS.md (F5-bis.1).
import { test, expect } from '@playwright/test'
import path from 'node:path'
import { fileURLToPath } from 'node:url'
import { addVirtualPasskey } from '../helpers/passkey.js'
import { createProfile } from '../helpers/app.js'

const HERE = path.dirname(fileURLToPath(import.meta.url))
const PLAN = path.resolve(HERE, '../../fork-routines/atlas-movilidad-hipopresivos.opengym-plan.json')

test('importar el plan del fork conserva la progresion y el tempo', async ({ page }) => {
  await addVirtualPasskey(page)
  await createProfile(page)

  await test.step('abrir el menu de Plan y elegir "Import a plan file"', async () => {
    await page.locator('#tabbar').getByRole('button', { name: 'Plan' }).click()
    // Plan.jsx: la vista "Routines" del control segmentado y el boton "Plan options" de la cabecera.
    await page.getByRole('button', { name: 'Routines', exact: true }).click()
    await page.getByRole('button', { name: 'Plan options' }).click()
    await page.getByRole('button', { name: 'Import a plan file' }).click()
  })

  await test.step('la hoja de importacion cuenta lo que trae el fichero', async () => {
    // El input de fichero esta oculto (Plan.jsx:192), pero Playwright lo encuentra igual.
    await page.locator('input[type="file"]').setInputFiles(PLAN)
    const sheet = page.locator('#modal-root')
    await expect(sheet.getByRole('heading', { name: /Import “Atlas, movilidad e hipopresivos”/ })).toBeVisible()
    await expect(sheet.getByText(/5 routines/)).toBeVisible()
    await expect(sheet.getByText(/32 exercises/)).toBeVisible()
    await expect(sheet.getByText(/7 days/)).toBeVisible()
    // Ningun ejercicio fuera del catalogo: el aviso solo sale si dropped > 0.
    await expect(sheet.getByText(/aren’t in your library/)).toHaveCount(0)
    // El interruptor del horario semanal.
    await sheet.locator('button[role="switch"]').click()
    await expect(sheet.locator('button[role="switch"]')).toHaveAttribute('aria-checked', 'true')
  })

  await test.step('importar y comprobar que las cinco rutinas estan', async () => {
    await page.locator('#modal-root').getByRole('button', { name: 'Add to my plan' }).click()
    await expect(page.locator('#modal-root.open')).toHaveCount(0)
    for (const name of ['Atlas A · Empuje', 'Atlas B · Tirón', 'Atlas C · Pierna y core', 'Movilidad diaria', 'Hipopresivos']) {
      await expect(page.getByText(name, { exact: true })).toBeVisible()
    }
  })

  await test.step('la rutina importada lleva la regla y el tempo, no solo los ejercicios', async () => {
    // Abrir "Atlas B · Tirón" y entrar en el primer ejercicio (dominada).
    await page.getByText('Atlas B · Tirón', { exact: true }).click()
    await expect(page.getByText('pull-up', { exact: true }).first()).toBeVisible()
    await page.getByText('pull-up', { exact: true }).first().click()

    const sheet = page.locator('#modal-root')
    // ProgressionFields (sheets.jsx:2443): seccion "Progression" y la fila "Rule".
    await expect(sheet.getByText('Progression', { exact: true })).toBeVisible()
    await expect(sheet.getByText('Double progression', { exact: true })).toBeVisible()
    // La fila "Tempo" muestra el tempo tal cual (sheets.jsx:3071).
    await expect(sheet.getByText('3-1-X-2', { exact: true })).toBeVisible()
  })
})
