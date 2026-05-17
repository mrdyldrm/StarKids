// ── Gezinti çubuğu ──────────────────────────────────
// Her HTML sayfasında <div id="navbar"></div> olmalı,
// ardından renderNav('dashboard') gibi çağrılmalı.

function renderNav(active) {
  const links = [
    { id: 'dashboard', href: 'index.html',    icon: '🏠', label: 'Ana Sayfa'  },
    { id: 'children',  href: 'children.html', icon: '👨‍👩‍👧‍👦', label: 'Çocuklar'   },
    { id: 'rules',     href: 'rules.html',    icon: '📋', label: 'Kurallar'   },
  ];

  const nav = document.getElementById('navbar');
  if (!nav) return;

  nav.innerHTML = `
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

        <!-- Desktop links -->
        <div class="hidden md:flex items-center gap-2">
          ${links.map(l => `
            <a href="${l.href}" class="nav-link ${l.id === active ? 'active' : ''}">
              <span>${l.icon}</span> ${l.label}
            </a>
          `).join('')}
          <button onclick="logout()"
            class="ml-4 flex items-center gap-2 px-4 py-2 rounded-2xl bg-red-50 text-red-600 font-bold hover:bg-red-100 transition-colors">
            🚪 Çıkış
          </button>
        </div>

        <!-- Mobile hamburger -->
        <button id="menuToggle" class="md:hidden text-2xl p-2 rounded-xl hover:bg-purple-50">☰</button>
      </div>

      <!-- Mobile menu -->
      <div id="mobileMenu" class="hidden md:hidden border-t border-purple-100 bg-white px-4 py-3 flex flex-col gap-2">
        ${links.map(l => `
          <a href="${l.href}" class="nav-link ${l.id === active ? 'active' : ''}">
            <span>${l.icon}</span> ${l.label}
          </a>
        `).join('')}
        <button onclick="logout()"
          class="flex items-center gap-2 px-4 py-2 rounded-2xl bg-red-50 text-red-600 font-bold hover:bg-red-100 transition-colors">
          🚪 Çıkış
        </button>
      </div>
    </nav>
  `;

  document.getElementById('menuToggle').addEventListener('click', () => {
    document.getElementById('mobileMenu').classList.toggle('hidden');
  });
}
