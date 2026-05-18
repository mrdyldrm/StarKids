// =====================================================
//  Yıldız Çocuklar — Dönem Yönetimi (Paylaşımlı)
// =====================================================
// Her sayfa: initPeriods(navId, callback) çağırır.
// callback(period|null) → sayfa verilerini yenile.

/* ── Durum ── */
let allPeriods       = [];
let currentPeriod    = null;   // null = Tüm Zamanlar
let _periodChangeCb  = null;
let _editingPeriodId = null;

const PERIOD_TYPE_META = {
  weekly:  { icon: '📅', label: 'Haftalık' },
  monthly: { icon: '🗓️', label: 'Aylık'    },
  custom:  { icon: '✏️', label: 'Özel'     },
};

/* ── Başlat ── */

/**
 * Sadece modalları ve veriyi hazırlar (nav container gerekmez).
 * Tüm sayfalardaki navbar Dönemler butonları için çağrılır.
 */
async function initPeriodsGlobal() {
  if (!document.getElementById('periodModalsWrap')) _injectPeriodModals();
  await _loadAndRender();
}

/**
 * Nav container + modaller + veri. Period filtresi kullanan sayfalar için.
 * Önce select HTML'ini enjekte eder, sonra veriyi çeker — sıra önemli.
 */
async function initPeriods(navContainerId, onChangeCb) {
  _periodChangeCb = onChangeCb;
  if (!document.getElementById('periodModalsWrap')) _injectPeriodModals();
  _injectPeriodNav(navContainerId);   // ← select önce oluşsun
  await _loadAndRender();             // ← sonra verilerle doldur
}

/* ── Veritabanı işlemleri ── */
async function _loadAndRender() {
  const { data } = await supabaseClient
    .from('periods').select('*').order('start_date', { ascending: false });
  allPeriods = data || [];
  _renderPeriodSelect();
  /* Dönemler sayfası açıksa listeyi yenile */
  if (typeof window.onPeriodsLoaded === 'function') window.onPeriodsLoaded(allPeriods);
}

async function savePeriod() {
  const name  = document.getElementById('pmName').value.trim();
  const type  = document.getElementById('pmType').value;
  const start = document.getElementById('pmStart').value;
  const end   = document.getElementById('pmEnd').value;

  if (!name)  { showToast('Dönem adını girin!',         'warning'); return; }
  if (!start) { showToast('Başlangıç tarihini seçin!',  'warning'); return; }
  if (!end)   { showToast('Bitiş tarihini seçin!',      'warning'); return; }
  if (start > end) { showToast('Başlangıç, bitişten önce olmalı!', 'warning'); return; }

  const payload = { name, type, start_date: start, end_date: end };
  let error;
  if (_editingPeriodId) {
    ({ error } = await supabaseClient.from('periods').update(payload).eq('id', _editingPeriodId));
  } else {
    ({ error } = await supabaseClient.from('periods').insert(payload));
  }
  if (error) { showToast('Hata: ' + error.message, 'error'); return; }

  showToast(_editingPeriodId ? '✏️ Dönem güncellendi!' : '✅ Dönem eklendi!', 'success');
  closePeriodModal();
  await _loadAndRender();

  /* Yeni dönem varsa onu seç */
  if (!_editingPeriodId && allPeriods.length > 0) {
    const newest = allPeriods[0];
    document.getElementById('periodSelect').value = newest.id;
    _onPeriodSelectChange();
  }
}

async function deletePeriodById(id) {
  const { error } = await supabaseClient.from('periods').delete().eq('id', id);
  if (error) { showToast('Hata: ' + error.message, 'error'); return; }
  showToast('🗑️ Dönem silindi!', 'info');
  if (currentPeriod?.id === id) {
    currentPeriod = null;
    if (_periodChangeCb) _periodChangeCb(null);
  }
  await _loadAndRender();
  _renderPeriodManagerList();
}

/* ── Sorgu filtresi ── */
function applyPeriodFilter(query) {
  if (!currentPeriod) return query;
  return query
    .gte('created_at', currentPeriod.start_date + 'T00:00:00')
    .lte('created_at', currentPeriod.end_date   + 'T23:59:59.999');
}

function periodLabel() {
  if (!currentPeriod) return 'Tüm Zamanlar';
  return currentPeriod.name;
}

/* ── Select render ── */
function _renderPeriodSelect() {
  const sel = document.getElementById('periodSelect');
  if (!sel) return;
  const cur = sel.value;
  sel.innerHTML = '<option value="">🌐 Tüm Zamanlar</option>' +
    allPeriods.map(p => {
      const m = PERIOD_TYPE_META[p.type];
      return `<option value="${p.id}">${m.icon} ${p.name}</option>`;
    }).join('');
  /* Mevcut seçimi koru */
  if (cur && allPeriods.some(p => p.id === cur)) sel.value = cur;
  else if (currentPeriod) {
    const still = allPeriods.find(p => p.id === currentPeriod.id);
    sel.value = still ? still.id : '';
  }
  _updateArrows();
}

function _onPeriodSelectChange() {
  const id = document.getElementById('periodSelect').value;
  currentPeriod = id ? (allPeriods.find(p => p.id === id) || null) : null;
  _updateArrows();
  if (_periodChangeCb) _periodChangeCb(currentPeriod);
}

/* ── Modal: Dönem Ekle / Düzenle ── */
function openAddPeriodModal(id) {
  _editingPeriodId = id || null;
  const isEdit = !!id;
  document.getElementById('pmModalTitle').textContent = isEdit ? '✏️ Dönemi Düzenle' : '➕ Yeni Dönem';

  if (isEdit) {
    const p = allPeriods.find(x => x.id === id);
    if (!p) return;
    document.getElementById('pmName').value  = p.name;
    document.getElementById('pmType').value  = p.type;
    document.getElementById('pmStart').value = p.start_date;
    document.getElementById('pmEnd').value   = p.end_date;
    _updatePeriodTypeUI(p.type, false);
  } else {
    document.getElementById('pmName').value  = '';
    document.getElementById('pmStart').value = '';
    document.getElementById('pmEnd').value   = '';
    _selectPeriodType('monthly');
  }
  document.getElementById('addPeriodModal').classList.remove('hidden');
  /* Toplu bilgiyi güncelle */
  setTimeout(() => _updateBulkInfo(document.getElementById('pmType').value), 50);
}

function closePeriodModal() {
  document.getElementById('addPeriodModal').classList.add('hidden');
}

function selectPeriodType(type) {
  document.getElementById('pmType').value = type;
  _updatePeriodTypeUI(type, true);
}

function _selectPeriodType(type) {
  document.getElementById('pmType').value = type;
  _updatePeriodTypeUI(type, true);
}

function _updatePeriodTypeUI(type, autofill) {
  /* Tab butonları */
  document.querySelectorAll('.pm-type-btn').forEach(b =>
    b.classList.toggle('active', b.dataset.type === type));

  /* Toplu ekleme bölümü */
  const bulkSection = document.getElementById('pmBulkSection');
  if (bulkSection) {
    const show = type === 'weekly' || type === 'monthly';
    bulkSection.classList.toggle('hidden', !show);
    if (show) _updateBulkInfo(type);
  }

  if (!autofill) return;

  const today = new Date();
  let start, end, name;

  if (type === 'weekly') {
    const day  = today.getDay();
    const diff = day === 0 ? -6 : 1 - day;
    const mon  = new Date(today); mon.setDate(today.getDate() + diff);
    const sun  = new Date(mon);   sun.setDate(mon.getDate() + 6);
    start = formatDateLocal(mon);
    end   = formatDateLocal(sun);
    name  = `${mon.toLocaleDateString('tr-TR',{day:'2-digit',month:'short'})} – ${sun.toLocaleDateString('tr-TR',{day:'2-digit',month:'short',year:'numeric'})}`;
  } else if (type === 'monthly') {
    const first = new Date(today.getFullYear(), today.getMonth(), 1);
    const last  = new Date(today.getFullYear(), today.getMonth() + 1, 0);
    start = formatDateLocal(first);
    end   = formatDateLocal(last);
    name  = first.toLocaleString('tr-TR', { month: 'long', year: 'numeric' });
  } else {
    document.getElementById('pmStart').value = '';
    document.getElementById('pmEnd').value   = '';
    if (!document.getElementById('pmName').value) {
      document.getElementById('pmName').value = 'Özel Dönem';
    }
    return;
  }

  document.getElementById('pmStart').value = start;
  document.getElementById('pmEnd').value   = end;
  if (!document.getElementById('pmName').value ||
      document.getElementById('pmName').dataset.auto === 'true') {
    document.getElementById('pmName').value = name;
    document.getElementById('pmName').dataset.auto = 'true';
  }
}

/* ── Toplu Ekleme ── */

function _updateBulkInfo(type) {
  const yearEl = document.getElementById('pmBulkYear');
  if (!yearEl) return;
  const year  = parseInt(yearEl.value);
  const type_ = (type && typeof type === 'string') ? type : document.getElementById('pmType').value;
  const generated = type_ === 'monthly'
    ? _generateMonthlyPeriods(year)
    : _generateWeeklyPeriods(year);

  /* Zaten var olanları say */
  const existing = new Set(allPeriods.map(p => p.start_date));
  const toAdd = generated.filter(p => !existing.has(p.start_date));

  const info = document.getElementById('pmBulkInfo');
  if (!info) return;
  if (toAdd.length === 0) {
    info.textContent = `✅ ${year} yılının tüm dönemleri zaten eklenmiş.`;
    info.className = 'text-xs text-green-600 font-semibold mt-2';
  } else {
    const total = generated.length;
    const skip  = total - toAdd.length;
    info.textContent = `${toAdd.length} dönem eklenecek${skip > 0 ? `, ${skip} zaten mevcut` : ''}.`;
    info.className = 'text-xs text-purple-500 font-semibold mt-2';
  }
}

async function bulkAddPeriods() {
  const yearEl = document.getElementById('pmBulkYear');
  const year   = parseInt(yearEl.value);
  const type   = document.getElementById('pmType').value;
  const btn    = document.getElementById('pmBulkBtn');

  const generated = type === 'monthly'
    ? _generateMonthlyPeriods(year)
    : _generateWeeklyPeriods(year);

  const existing = new Set(allPeriods.map(p => p.start_date));
  const toAdd    = generated.filter(p => !existing.has(p.start_date));

  if (toAdd.length === 0) {
    showToast(`${year} yılının tüm dönemleri zaten mevcut!`, 'info');
    return;
  }

  btn.disabled    = true;
  btn.textContent = `⏳ ${toAdd.length} dönem ekleniyor…`;

  const { error } = await supabaseClient.from('periods').insert(toAdd);
  if (error) {
    showToast('Hata: ' + error.message, 'error');
    btn.disabled    = false;
    btn.textContent = '📦 Tümünü Ekle';
    return;
  }

  showToast(`✅ ${toAdd.length} dönem eklendi!`, 'success');
  btn.disabled    = false;
  btn.textContent = '📦 Tümünü Ekle';
  await _loadAndRender();
  _updateBulkInfo(type);
}

function _generateMonthlyPeriods(year) {
  const result = [];
  for (let m = 0; m < 12; m++) {
    const first = new Date(year, m, 1);
    const last  = new Date(year, m + 1, 0);
    result.push({
      name:       first.toLocaleString('tr-TR', { month: 'long', year: 'numeric' }),
      type:       'monthly',
      start_date: formatDateLocal(first),
      end_date:   formatDateLocal(last),
    });
  }
  return result;
}

function _generateWeeklyPeriods(year) {
  const result = [];
  /* İlk Pazartesiyi bul (Jan 1 veya öncesi) */
  const jan1   = new Date(year, 0, 1);
  const dayJ   = jan1.getDay(); // 0=Pzr
  const diff   = dayJ === 0 ? -6 : 1 - dayJ;
  const cursor = new Date(jan1);
  cursor.setDate(jan1.getDate() + diff);

  let weekNum = 1;
  while (true) {
    const mon = new Date(cursor);
    const sun = new Date(cursor); sun.setDate(cursor.getDate() + 6);

    /* Pazartesi zaten bir sonraki yılda → dur */
    if (mon.getFullYear() > year) break;

    const monLabel = mon.toLocaleDateString('tr-TR', { day:'2-digit', month:'short' });
    const sunYear  = sun.getFullYear() !== year ? ` ${sun.getFullYear()}` : '';
    const sunLabel = sun.toLocaleDateString('tr-TR', { day:'2-digit', month:'short' }) + sunYear;

    result.push({
      name:       `${weekNum}. Hafta – ${monLabel} / ${sunLabel} ${year}`,
      type:       'weekly',
      start_date: formatDateLocal(mon),
      end_date:   formatDateLocal(sun),
    });

    cursor.setDate(cursor.getDate() + 7);
    weekNum++;
  }
  return result;
}

/* ── Modal: Dönem Yönetimi ── */
function openPeriodManager() {
  _renderPeriodManagerList();
  document.getElementById('periodManagerModal').classList.remove('hidden');
}

function closePeriodManager() {
  document.getElementById('periodManagerModal').classList.add('hidden');
}

function _renderPeriodManagerList() {
  const el = document.getElementById('pmListContainer');
  if (!el) return;
  if (allPeriods.length === 0) {
    el.innerHTML = `<div class="text-center py-8 text-gray-400 font-semibold">
      Henüz dönem eklenmemiş.<br>
      <button onclick="closePeriodManager();openAddPeriodModal();"
              class="mt-3 bg-purple-600 text-white font-bold px-4 py-2 rounded-xl text-sm hover:bg-purple-700">
        ➕ Dönem Ekle
      </button>
    </div>`;
    return;
  }
  el.innerHTML = allPeriods.map(p => {
    const m = PERIOD_TYPE_META[p.type];
    const isActive = currentPeriod?.id === p.id;
    return `
      <div class="flex items-center gap-3 p-3 rounded-2xl border-2
                  ${isActive ? 'border-purple-400 bg-purple-50' : 'border-gray-100 bg-white'}
                  transition-all mb-2">
        <span class="text-2xl">${m.icon}</span>
        <div class="flex-1 min-w-0">
          <div class="font-black text-gray-800 truncate">${p.name}</div>
          <div class="text-xs text-gray-400 font-semibold">
            ${p.start_date} → ${p.end_date}
            <span class="ml-2 px-2 py-0.5 rounded-full text-xs font-bold
                         ${isActive ? 'bg-purple-200 text-purple-700' : 'bg-gray-100 text-gray-500'}">
              ${m.label}
            </span>
          </div>
        </div>
        <div class="flex gap-1 flex-shrink-0">
          <button onclick="closePeriodManager();openAddPeriodModal('${p.id}');"
                  class="bg-yellow-100 hover:bg-yellow-200 text-yellow-700 font-bold px-2 py-1 rounded-xl text-xs">
            ✏️
          </button>
          <button onclick="deletePeriodById('${p.id}')"
                  class="bg-red-100 hover:bg-red-200 text-red-600 font-bold px-2 py-1 rounded-xl text-xs">
            🗑️
          </button>
        </div>
      </div>`;
  }).join('');
}

/* ── HTML Enjeksiyonu ── */
function _injectPeriodNav(containerId) {
  const el = document.getElementById(containerId);
  if (!el) return;
  el.innerHTML = `
    <div class="flex items-center gap-2 bg-white rounded-2xl px-3 py-3
                shadow-sm border border-purple-100">
      <button id="periodPrevBtn" onclick="navigatePeriod(-1)" title="Önceki dönem"
              class="w-9 h-9 flex items-center justify-center rounded-xl bg-purple-100
                     hover:bg-purple-200 text-purple-700 font-black text-base transition-colors
                     disabled:opacity-30 disabled:cursor-not-allowed flex-shrink-0">◀</button>

      <select id="periodSelect" onchange="_onPeriodSelectChange()"
              class="flex-1 min-w-[120px] border-2 border-purple-200 rounded-xl px-3 py-2
                     font-bold text-purple-700 focus:outline-none focus:border-purple-500
                     bg-white cursor-pointer text-sm">
        <option value="">🌐 Tüm Zamanlar</option>
      </select>

      <span id="periodTypeBadge"
            class="hidden text-xs font-black px-2 py-1 rounded-lg bg-purple-100
                   text-purple-600 flex-shrink-0 whitespace-nowrap"></span>

      <button id="periodNextBtn" onclick="navigatePeriod(1)" title="Sonraki dönem"
              class="w-9 h-9 flex items-center justify-center rounded-xl bg-purple-100
                     hover:bg-purple-200 text-purple-700 font-black text-base transition-colors
                     disabled:opacity-30 disabled:cursor-not-allowed flex-shrink-0">▶</button>
    </div>`;
  _updateArrows();
}

/* ── Ok navigasyonu ── */
function navigatePeriod(dir) {
  const sorted = [...allPeriods].sort((a, b) => a.start_date.localeCompare(b.start_date));
  if (sorted.length === 0) return;

  if (!currentPeriod) {
    /* "Tüm Zamanlar"dan oka basıldı → ilk veya son periyoda git */
    const target = dir === -1 ? sorted[sorted.length - 1] : sorted[0];
    if (target) { document.getElementById('periodSelect').value = target.id; _onPeriodSelectChange(); }
    return;
  }

  const idx    = sorted.findIndex(p => p.id === currentPeriod.id);
  const target = sorted[idx + dir];
  if (target) {
    document.getElementById('periodSelect').value = target.id;
    _onPeriodSelectChange();
  }
}

function _updateArrows() {
  const prevBtn = document.getElementById('periodPrevBtn');
  const nextBtn = document.getElementById('periodNextBtn');
  const badge   = document.getElementById('periodTypeBadge');
  if (!prevBtn) return;

  const sorted = [...allPeriods].sort((a, b) => a.start_date.localeCompare(b.start_date));

  if (!currentPeriod || sorted.length === 0) {
    prevBtn.disabled = true;
    nextBtn.disabled = sorted.length === 0;
    if (badge) badge.classList.add('hidden');
    return;
  }

  const idx = sorted.findIndex(p => p.id === currentPeriod.id);
  prevBtn.disabled = idx <= 0;
  nextBtn.disabled = idx >= sorted.length - 1;

  if (badge) {
    const meta = PERIOD_TYPE_META[currentPeriod.type];
    badge.textContent = `${meta.icon} ${meta.label}`;
    badge.classList.remove('hidden');
  }
}

function _injectPeriodModals() {
  const wrap = document.createElement('div');
  wrap.id = 'periodModalsWrap';
  wrap.innerHTML = `
    <!-- Dönem Ekle / Düzenle Modalı -->
    <div id="addPeriodModal"
         class="fixed inset-0 modal-overlay z-50 hidden flex items-center justify-center p-4">
      <div class="modal-box bg-white rounded-3xl shadow-2xl w-full max-w-md p-6 max-h-[90vh] overflow-y-auto">
        <div class="flex items-center justify-between mb-5">
          <h3 id="pmModalTitle" class="text-2xl font-black text-purple-700">➕ Yeni Dönem</h3>
          <button onclick="closePeriodModal()"
                  class="text-gray-400 hover:text-gray-600 text-2xl font-bold">✕</button>
        </div>

        <!-- Tür seçimi -->
        <label class="block text-sm font-bold text-gray-600 mb-2">Dönem Türü</label>
        <div class="grid grid-cols-3 gap-2 mb-4">
          ${Object.entries(PERIOD_TYPE_META).map(([type, m]) => `
            <button type="button" onclick="selectPeriodType('${type}')"
                    data-type="${type}"
                    class="pm-type-btn flex flex-col items-center gap-1 p-3 rounded-2xl border-2
                           border-purple-200 hover:border-purple-400 transition-all">
              <span class="text-2xl">${m.icon}</span>
              <span class="text-xs font-black text-purple-700">${m.label}</span>
            </button>`).join('')}
        </div>
        <input type="hidden" id="pmType" value="monthly">

        <!-- Toplu Ekleme (Haftalık / Aylık modlarında) -->
        <div id="pmBulkSection" class="border-2 border-purple-100 rounded-2xl p-4 mb-4 bg-gradient-to-r from-purple-50 to-indigo-50">
          <div class="flex items-center gap-2 mb-3">
            <span class="text-xl">📦</span>
            <span class="font-black text-purple-700 text-sm">Toplu Ekle</span>
            <span class="text-xs text-purple-400 font-semibold">— Seçili yılın tümünü tek seferde ekle</span>
          </div>
          <div class="flex items-center gap-2">
            <select id="pmBulkYear" onchange="_updateBulkInfo()"
                    class="border-2 border-purple-200 rounded-xl px-3 py-2 font-bold text-purple-700
                           focus:outline-none focus:border-purple-500 bg-white text-sm">
              ${(() => {
                const cy = new Date().getFullYear();
                return Array.from({length: 7}, (_,i) => cy - 2 + i)
                  .map(y => `<option value="${y}" ${y === cy ? 'selected' : ''}>${y}</option>`)
                  .join('');
              })()}
            </select>
            <button id="pmBulkBtn" type="button" onclick="bulkAddPeriods()"
                    class="flex-1 flex items-center justify-center gap-2 bg-purple-600
                           hover:bg-purple-700 text-white font-bold px-4 py-2 rounded-xl
                           text-sm transition-all hover:scale-105 active:scale-95">
              📦 Tümünü Ekle
            </button>
          </div>
          <p id="pmBulkInfo" class="text-xs text-purple-500 font-semibold mt-2"></p>
        </div>

        <!-- Ad -->
        <label class="block text-sm font-bold text-gray-600 mb-1">Dönem Adı <span class="text-red-400">*</span></label>
        <input id="pmName" type="text" placeholder="Örn: Mayıs 2026, 1. Hafta…"
               oninput="this.dataset.auto='false'"
               class="w-full border-2 border-purple-200 rounded-2xl px-4 py-3 font-semibold
                      focus:outline-none focus:border-purple-500 mb-3 text-base">

        <!-- Tarih aralığı -->
        <div class="grid grid-cols-2 gap-3 mb-5">
          <div>
            <label class="block text-sm font-bold text-gray-600 mb-1">📅 Başlangıç <span class="text-red-400">*</span></label>
            <input id="pmStart" type="date"
                   class="w-full border-2 border-purple-200 rounded-2xl px-3 py-3 font-semibold
                          focus:outline-none focus:border-purple-500">
          </div>
          <div>
            <label class="block text-sm font-bold text-gray-600 mb-1">📅 Bitiş <span class="text-red-400">*</span></label>
            <input id="pmEnd" type="date"
                   class="w-full border-2 border-purple-200 rounded-2xl px-3 py-3 font-semibold
                          focus:outline-none focus:border-purple-500">
          </div>
        </div>

        <button onclick="savePeriod()"
                class="w-full bg-purple-600 hover:bg-purple-700 text-white font-black text-lg
                       py-4 rounded-2xl transition-all hover:scale-105 active:scale-95 shadow-lg">
          💾 Kaydet
        </button>
      </div>
    </div>

    <!-- Dönem Yönetici Modalı -->
    <div id="periodManagerModal"
         class="fixed inset-0 modal-overlay z-50 hidden flex items-center justify-center p-4">
      <div class="modal-box bg-white rounded-3xl shadow-2xl w-full max-w-md p-6 max-h-[85vh] flex flex-col">
        <div class="flex items-center justify-between mb-5">
          <h3 class="text-2xl font-black text-purple-700">⚙️ Dönemler</h3>
          <div class="flex gap-2">
            <button onclick="closePeriodManager();openAddPeriodModal();"
                    class="bg-purple-100 hover:bg-purple-200 text-purple-700 font-bold
                           px-3 py-1.5 rounded-xl text-sm transition-colors">➕ Ekle</button>
            <button onclick="closePeriodManager()"
                    class="text-gray-400 hover:text-gray-600 text-2xl font-bold">✕</button>
          </div>
        </div>
        <div id="pmListContainer" class="overflow-y-auto flex-1 pr-1"></div>
      </div>
    </div>`;
  document.body.appendChild(wrap);

  /* Modal dışı kapatma */
  ['addPeriodModal','periodManagerModal'].forEach(id => {
    document.getElementById(id).addEventListener('click', e => {
      if (e.target.id === id) document.getElementById(id).classList.add('hidden');
    });
  });

  /* pm-type-btn active stili */
  document.head.insertAdjacentHTML('beforeend',
    `<style>
      .pm-type-btn.active {
        background:#7C3AED; border-color:#7C3AED; color:#fff;
      }
      .pm-type-btn.active span:last-child { color:#fff !important; }
    </style>`);
}
