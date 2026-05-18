// ── Gezinti çubuğu ──────────────────────────────────


const ROLE_LABELS = {
  admin:  { icon: '👑', text: 'Admin',    cls: 'bg-purple-100 text-purple-700' },
  editor: { icon: '✏️', text: 'Editör',   cls: 'bg-blue-100 text-blue-700'     },
  viewer: { icon: '👁️', text: 'İzleyici', cls: 'bg-gray-100 text-gray-600'     },
};

/* Profil bilgisi önbelleği — sayfa yenilenene kadar tekrar sorgulanmaz */
let _cachedNavProfile = null;

function _buildNavHTML(active, role, initials, fullName, email) {
  const adminLinks = [
    { id: 'children', href: 'children.html', icon: '👨‍👩‍👧‍👦', label: 'Çocuklar'           },
    { id: 'rules',    href: 'rules.html',    icon: '📋', label: 'Kurallar / Hedefler' },
    { id: 'periods',  href: 'periods.html',  icon: '📅', label: 'Dönemler'            },
    { id: 'users',    href: 'users.html',    icon: '👥', label: 'Kullanıcılar'        },
  ];
  const editorLinks = [
    { id: 'children', href: 'children.html', icon: '👨‍👩‍👧‍👦', label: 'Çocuklar' },
  ];
  const links = role === 'admin' ? adminLinks : role === 'editor' ? editorLinks : [];
  const rl    = ROLE_LABELS[role] || ROLE_LABELS.viewer;

  const profileBtnHtml = `
    <button id="profileBtn" onclick="toggleProfileMenu()"
            class="w-10 h-10 rounded-full bg-gradient-to-br from-purple-500 to-indigo-600
                   text-white font-black text-sm flex items-center justify-center
                   hover:scale-105 transition-transform shadow-md select-none">
      ${initials}
    </button>`;

  return `
    <nav class="bg-white shadow-lg sticky top-0 z-50">
      <div class="max-w-6xl mx-auto px-4 py-3 flex items-center justify-between">

        <!-- Logo -->
        <a href="index.html" class="flex items-center gap-2 no-underline">
          <span class="text-3xl">⭐</span>
          <div>
            <div class="font-black text-purple-700 text-xl leading-tight">${CONFIG.app.name}</div>
            <div class="text-xs text-purple-400 font-semibold">Yönetim Paneli</div>
          </div>
        </a>

        <!-- Desktop links + profil -->
        <div class="hidden md:flex items-center gap-2">
          ${links.map(l => `
            <a href="${l.href}" class="nav-link ${l.id === active ? 'active' : ''}">
              <span>${l.icon}</span> ${l.label}
            </a>
          `).join('')}
          ${profileBtnHtml}
        </div>

        <!-- Mobile right side -->
        <div class="md:hidden flex items-center gap-2">
          ${profileBtnHtml.replace('id="profileBtn"', 'id="profileBtnMobile"')}
          <button id="menuToggle" class="text-2xl p-2 rounded-xl hover:bg-purple-50">☰</button>
        </div>
      </div>

      <!-- Mobile menu -->
      <div id="mobileMenu"
           class="hidden md:hidden border-t border-purple-100 bg-white px-4 py-3 flex flex-col gap-2">
        ${links.map(l => `
          <a href="${l.href}" class="nav-link ${l.id === active ? 'active' : ''}">
            <span>${l.icon}</span> ${l.label}
          </a>
        `).join('')}
      </div>
    </nav>

    <!-- Profil dropdown (fixed, her iki butonla da açılır) -->
    <div id="profileMenu"
         class="hidden fixed top-16 right-4 w-72 bg-white rounded-2xl
                shadow-xl border border-purple-100 z-[200] overflow-hidden">

      <!-- Kullanıcı bilgisi -->
      <div class="flex items-center gap-3 px-4 py-4 bg-gradient-to-r from-purple-50 to-indigo-50
                  border-b border-purple-100">
        <div id="profileMenuAvatar"
             class="w-12 h-12 rounded-full bg-gradient-to-br from-purple-500 to-indigo-600
                    text-white font-black flex items-center justify-center text-base flex-shrink-0">
          ${initials}
        </div>
        <div class="min-w-0">
          <div id="profileMenuName" class="font-black text-gray-800 truncate">${fullName || '—'}</div>
          <div id="profileMenuEmail" class="text-xs text-gray-400 font-semibold truncate">${email}</div>
        </div>
      </div>

      <!-- Rol -->
      <div class="px-4 py-3 border-b border-purple-50">
        <span class="inline-flex items-center gap-1.5 text-xs font-black px-3 py-1.5
                     rounded-full ${rl.cls}">
          ${rl.icon} ${rl.text}
        </span>
      </div>

      <!-- Aksiyonlar -->
      <div class="p-2">
        <button onclick="openChangePasswordModal()"
                class="w-full flex items-center gap-3 px-3 py-2.5 rounded-xl text-left
                       text-gray-700 font-bold hover:bg-purple-50 transition-colors text-sm">
          <span class="text-lg">🔑</span> Şifreyi Değiştir
        </button>
        <button onclick="logout()"
                class="w-full flex items-center gap-3 px-3 py-2.5 rounded-xl text-left
                       text-red-600 font-bold hover:bg-red-50 transition-colors text-sm">
          <span class="text-lg">🚪</span> Çıkış Yap
        </button>
      </div>
    </div>
  `;
}

function _attachNavEvents() {
  document.getElementById('menuToggle')?.addEventListener('click', () => {
    document.getElementById('mobileMenu').classList.toggle('hidden');
  });

  document.addEventListener('click', e => {
    const menu = document.getElementById('profileMenu');
    const btnD = document.getElementById('profileBtn');
    const btnM = document.getElementById('profileBtnMobile');
    if (!menu) return;
    if (menu.contains(e.target) || e.target === btnD || e.target === btnM) return;
    menu.classList.add('hidden');
  });

  if (!document.getElementById('changePasswordModal')) {
    const modal = document.createElement('div');
    modal.id        = 'changePasswordModal';
    modal.className = 'fixed inset-0 modal-overlay z-[300] hidden flex items-center justify-center p-4';
    modal.innerHTML = `
      <div class="modal-box bg-white rounded-3xl shadow-2xl w-full max-w-sm p-6">
        <div class="flex items-center justify-between mb-5">
          <h3 class="text-xl font-black text-purple-700">🔑 Şifreyi Değiştir</h3>
          <button onclick="closeChangePasswordModal()" class="text-gray-400 hover:text-gray-600 text-2xl">✕</button>
        </div>
        <label class="block text-sm font-bold text-gray-600 mb-1">Yeni Şifre</label>
        <input id="newPasswordInput" type="password" placeholder="En az 6 karakter"
               class="w-full border-2 border-purple-200 rounded-2xl px-4 py-3 font-semibold
                      focus:outline-none focus:border-purple-500 mb-3">
        <label class="block text-sm font-bold text-gray-600 mb-1">Yeni Şifre (Tekrar)</label>
        <input id="newPasswordConfirm" type="password" placeholder="Şifreyi tekrar girin"
               class="w-full border-2 border-purple-200 rounded-2xl px-4 py-3 font-semibold
                      focus:outline-none focus:border-purple-500 mb-5">
        <button id="changePasswordBtn" onclick="saveNewPassword()"
                class="w-full bg-purple-600 hover:bg-purple-700 text-white font-black
                       py-3 rounded-2xl transition-all hover:scale-105">
          Kaydet
        </button>
      </div>`;
    document.body.appendChild(modal);
    modal.addEventListener('click', e => {
      if (e.target === modal) closeChangePasswordModal();
    });
  }
}

async function renderNav(active) {
  const nav = document.getElementById('navbar');
  if (!nav) return;

  /* Bu noktada requireAuth() ve getUserRole() zaten çağrıldı,
     dolayısıyla session ve rol önbellekte — ağ gecikmesi yok. */
  const { data: { session } } = await supabaseClient.auth.getSession();
  const role  = await getUserRole();
  const email = session?.user?.email || '';

  /* Profil adı önbellekte varsa hemen kullan; yoksa e-posta ile başla */
  let fullName = _cachedNavProfile
    ? (_cachedNavProfile.full_name || _cachedNavProfile.email || email)
    : email;
  const initials = (fullName || '?').slice(0, 2).toUpperCase();

  /* ── Navbar'ı render et (iskeleti gerçek içerikle değiştir) ── */
  nav.innerHTML = _buildNavHTML(active, role, initials, fullName, email);
  _attachNavEvents();

  /* Profil adı henüz önbellekte yoksa arka planda çek ve güncelle */
  if (!_cachedNavProfile && session) {
    supabaseClient
      .from('profiles')
      .select('full_name, email')
      .eq('id', session.user.id)
      .single()
      .then(({ data: prof }) => {
        if (!prof) return;
        _cachedNavProfile = prof;
        const name        = prof.full_name || prof.email || email;
        const newInitials = (name || '?').slice(0, 2).toUpperCase();

        /* Yalnızca dinamik alanları güncelle, tüm DOM'u yeniden çizme */
        ['profileBtn', 'profileBtnMobile'].forEach(id => {
          const btn = document.getElementById(id);
          if (btn) btn.textContent = newInitials;
        });
        const nameEl   = document.getElementById('profileMenuName');
        const avatarEl = document.getElementById('profileMenuAvatar');
        const emailEl  = document.getElementById('profileMenuEmail');
        if (nameEl)   nameEl.textContent   = name || '—';
        if (avatarEl) avatarEl.textContent  = newInitials;
        if (emailEl)  emailEl.textContent   = email;
      });
  }
}

function toggleProfileMenu() {
  document.getElementById('profileMenu')?.classList.toggle('hidden');
}

function openChangePasswordModal() {
  document.getElementById('profileMenu')?.classList.add('hidden');
  document.getElementById('newPasswordInput').value  = '';
  document.getElementById('newPasswordConfirm').value = '';
  document.getElementById('changePasswordModal').classList.remove('hidden');
}

function closeChangePasswordModal() {
  document.getElementById('changePasswordModal').classList.add('hidden');
}

async function saveNewPassword() {
  const pw1 = document.getElementById('newPasswordInput').value;
  const pw2 = document.getElementById('newPasswordConfirm').value;
  const btn = document.getElementById('changePasswordBtn');

  if (pw1.length < 6) { showToast('Şifre en az 6 karakter olmalı!', 'warning'); return; }
  if (pw1 !== pw2)    { showToast('Şifreler eşleşmiyor!', 'warning'); return; }

  btn.disabled    = true;
  btn.textContent = '⏳ Kaydediliyor…';

  const { error } = await supabaseClient.auth.updateUser({ password: pw1 });

  btn.disabled    = false;
  btn.textContent = 'Kaydet';

  if (error) { showToast('Hata: ' + error.message, 'error'); return; }

  showToast('✅ Şifre güncellendi!', 'success');
  closeChangePasswordModal();
}
