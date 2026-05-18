// ── Kimlik doğrulama & rol yönetimi ─────────────────

let _cachedRole = null;

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

/**
 * Giriş yapmış kullanıcının rolünü döner: 'admin' | 'editor' | 'viewer'
 * Sonuç önbelleğe alınır; sayfa yenilenene kadar tekrar sorgulanmaz.
 */
async function getUserRole() {
  if (_cachedRole) return _cachedRole;
  try {
    const { data: { session } } = await supabaseClient.auth.getSession();
    if (!session) return null;
    const { data } = await supabaseClient
      .from('profiles')
      .select('role')
      .eq('id', session.user.id)
      .single();
    _cachedRole = data?.role || 'viewer';
    return _cachedRole;
  } catch (e) {
    console.warn('Rol alınamadı:', e);
    return 'viewer';
  }
}

/**
 * Kullanıcının rolü izin verilenlere girmiyorsa index.html'e yönlendir.
 * @param {string[]} allowed - İzin verilen roller: ['admin'], ['admin','editor'] vb.
 */
async function requireRole(allowed) {
  const role = await getUserRole();
  if (!allowed.includes(role)) {
    window.location.href = 'index.html';
    return false;
  }
  return true;
}

/** Çıkış yap */
async function logout() {
  _cachedRole = null;
  await supabaseClient.auth.signOut();
  window.location.href = 'login.html';
}
