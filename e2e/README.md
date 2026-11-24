# Tests e2e del fork rap77/openGym

No forman parte del upstream. Corren **Playwright** contra el stack real de openGym (Docker
Compose), con un autenticador WebAuthn virtual por CDP: no hace falta ninguna passkey de verdad,
ni tocar el móvil.

## Correrlos

```bash
e2e/run.sh --down          # levanta el stack aislado en :8090, corre los tests y lo baja
e2e/run.sh                 # idem pero deja el stack arriba para inspeccionar a mano
cd e2e && npx playwright test --headed    # verlos en el navegador
```

El stack es **aislado**: su propio compose (`e2e/compose.e2e.yml`), su puerto (8090) y su volumen
(`e2e-data`), que `--down` borra. Tu `./data` nunca se toca y tu app sigue en el 8080.

## Escenarios

| Fichero | Qué comprueba |
|---|---|
| `01-create-profile.spec.js` | Crear un perfil con passkey virtual y entrar |
| `02-workout-and-relogin.spec.js` | Registrar un entreno libre con 1 serie, verlo en Progreso, cerrar sesión y volver a entrar: los datos siguen |
| `03-personal-record.spec.js` | Escribir un peso en la serie y detectar el PR |
| `04-import-plan.spec.js` | Importar el plan de `fork-routines/` en la app real y comprobar que la **regla de progresión** y el **tempo** llegan a la rutina, no solo los ejercicios |

## Por qué están en inglés

Los tests localizan los textos por su **clave original en inglés**, porque los packs de idioma
(keyed by the English string) usan el inglés como clave. El stack e2e fija `DEFAULT_LANG=en` en
`e2e/compose.e2e.yml` para que sea determinista: tu instancia puede ir en español (`DEFAULT_LANG=es`
en tu `.env`) y los tests seguir funcionando igual.

Si cambias el idioma de los textos de la app, los selectores de los tests se quedan viejos. Cuando
pase, se actualizan aquí y en `e2e/helpers/app.js`.

## Requisitos

- **Node 22** (el de `.nvmrc`). Con Node 24 el upstream da fallos falsos.
- **Chromium** de Playwright: `cd e2e && npx playwright install chromium`. Si falta, los tests
  fallan con `Executable doesn't exist at .../chromium_headless_shell-1255/...` — es el navegador,
  no la app.
- **Docker** con Compose ≥ 2.24 (el compose del e2e usa `!override`).

## CI

`.github/workflows/fork-quality.yml` corre esta suite en cada push y PR que toque `frontend/`,
`api/`, `web/`, `catalogue/`, `e2e/` o `fork-routines/`. Si un test falla, se suben las trazas y
las capturas como artefacto.
