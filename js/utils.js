// ── Ay yardımcıları ─────────────────────────────────

/**
 * Bir ay için yerel saat diliminde başlangıç / bitiş ISO stringleri döner.
 * month: 0-indexed (JS Date gibi)
 * Not: new Date(y,m,1,0,0,0) yerel gece yarısı → toISOString UTC'ye çevirir,
 *      UTC+3'te bu önceki günün 21:00'ı olur ve filtre kayar.
 *      Bu nedenle sınırları günün başı/sonu olarak local time'da inşa ediyoruz.
 */
function getMonthRange(year, month) {
  // Ayın 1. günü 00:00:00 yerel
  const startDate = new Date(year, month, 1, 0, 0, 0, 0);
  // Ayın son günü 23:59:59 yerel
  const endDate   = new Date(year, month + 1, 0, 23, 59, 59, 999);
  const label     = startDate.toLocaleString('tr-TR', { month: 'long', year: 'numeric' });
  return { start: startDate.toISOString(), end: endDate.toISOString(), label };
}

/**
 * Şimdiki ay/yıl
 */
function nowYM() {
  const d = new Date();
  return { year: d.getFullYear(), month: d.getMonth() };
}

/**
 * Verilen ay/yıl kombinasyonu bu ayki mi?
 */
function isCurrentMonth(year, month) {
  const n = nowYM();
  return year === n.year && month === n.month;
}

/**
 * Date → "YYYY-MM-DD" (yerel saat dilimine göre, UTC'ye çevirmez).
 * toISOString() UTC'ye çevirir; UTC+3'te gece yarısı önceki güne düşer.
 */
function formatDateLocal(date) {
  const y = date.getFullYear();
  const m = String(date.getMonth() + 1).padStart(2, '0');
  const d = String(date.getDate()).padStart(2, '0');
  return `${y}-${m}-${d}`;
}

/**
 * Modal için varsayılan tarih değeri (YYYY-MM-DD).
 * Güncel aydaysa bugün, geçmiş aydaysa o ayın son günü.
 */
function getDefaultDate(year, month) {
  if (isCurrentMonth(year, month)) {
    return formatDateLocal(new Date());
  }
  return formatDateLocal(new Date(year, month + 1, 0));
}

/**
 * Ay sınırları — input[type=date] için min/max değerleri.
 */
function getMonthBounds(year, month) {
  const first = formatDateLocal(new Date(year, month, 1));
  const last  = formatDateLocal(new Date(year, month + 1, 0));
  return { first, last };
}

/**
 * "YYYY-MM-DD" → ISO timestamp (öğle vakti → timezone kaymalarını önler)
 */
function dateInputToISO(dateStr) {
  return new Date(dateStr + 'T12:00:00').toISOString();
}
