// Autenticador WebAuthn virtual (Chrome DevTools Protocol). Sustituye a Windows Hello o a la
// huella: el navegador cree que hay una llave de plataforma con verificación de usuario y
// responde solo a cada petición, así los tests de registro y login no necesitan intervención.

/**
 * Añade un autenticador de plataforma virtual a la página.
 * @param {import('@playwright/test').Page} page
 * @returns {Promise<{ cdp: import('@playwright/test').CDPSession, authenticatorId: string }>}
 */
export async function addVirtualPasskey(page) {
  const cdp = await page.context().newCDPSession(page)
  await cdp.send('WebAuthn.enable')
  const { authenticatorId } = await cdp.send('WebAuthn.addVirtualAuthenticator', {
    options: {
      protocol: 'ctap2',
      transport: 'internal',          // como Windows Hello / Touch ID: llave del propio dispositivo
      hasResidentKey: true,           // passkey descubrible (login sin escribir nombre)
      hasUserVerification: true,
      isUserVerified: true,
      automaticPresenceSimulation: true,
    },
  })
  return { cdp, authenticatorId }
}

/**
 * Cuántas credenciales guarda el autenticador virtual (para comprobar que el registro creó una).
 * @param {import('@playwright/test').CDPSession} cdp
 * @param {string} authenticatorId
 */
export async function credentialCount(cdp, authenticatorId) {
  const { credentials } = await cdp.send('WebAuthn.getCredentials', { authenticatorId })
  return credentials.length
}
