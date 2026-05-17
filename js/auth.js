// ── Kimlik doğrulama yardımcıları ───────────────────

/**
 * Oturum yoksa login.html'e yönlendir.
 * Her korumalı sayfanın başında çağrılır.
 */
async function requireAuth() {
  try {
    const { data: { session } } = await supabaseClient.auth.getSession();
    if (!session) {
      window.location.href = 'login.html';
      return null;
    }
    return session;
  } catch (e) {
    console.warn('Supabase bağlantı hatası. config.js dosyasını kontrol edin.', e);
    return null;
  }
}

/** Çıkış yap */
async function logout() {
  await supabaseClient.auth.signOut();
  window.location.href = 'login.html';
}
