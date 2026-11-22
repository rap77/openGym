// Tests e2e del fork (H2.3, docs/fork/PLAN-MEJORAS.md). Corren contra el stack aislado de
// e2e/compose.e2e.yml (puerto 8090). Ver e2e/README.md.
import { defineConfig, devices } from '@playwright/test'

export default defineConfig({
  testDir: './tests',
  // Un solo worker: todos los tests comparten el mismo servidor y WSL va justo de memoria (D-B4).
  workers: 1,
  fullyParallel: false,
  retries: 0,
  timeout: 60_000,
  expect: { timeout: 10_000 },
  reporter: [['list'], ['html', { open: 'never' }]],
  use: {
    baseURL: process.env.E2E_BASE_URL || 'http://localhost:8090',
    // La app elige idioma según el navegador. Fijar inglés hace que los textos de los tests
    // sean las claves originales del código (los packs usan el inglés como clave).
    locale: 'en-US',
    trace: 'retain-on-failure',
    screenshot: 'only-on-failure',
  },
  projects: [
    // Solo Chromium: el autenticador WebAuthn virtual se maneja por CDP, que es de Chromium.
    { name: 'chromium', use: { ...devices['Desktop Chrome'] } },
  ],
})
