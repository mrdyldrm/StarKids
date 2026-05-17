// ── Toast bildirimleri ───────────────────────────────

function showToast(message, type = 'success') {
  const colors = {
    success: 'bg-green-500',
    error:   'bg-red-500',
    info:    'bg-purple-600',
    warning: 'bg-yellow-500',
  };
  const icons = { success: '✅', error: '❌', info: 'ℹ️', warning: '⚠️' };

  const el = document.createElement('div');
  el.className = `toast ${colors[type]} text-white px-5 py-4 rounded-2xl shadow-2xl flex items-center gap-3 font-bold text-base`;
  el.innerHTML = `<span class="text-xl">${icons[type]}</span> <span>${message}</span>`;
  document.body.appendChild(el);

  setTimeout(() => {
    el.classList.add('hiding');
    el.addEventListener('animationend', () => el.remove());
  }, 3000);
}
