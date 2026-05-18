// ── Supabase Storage yardımcıları ───────────────────

const MAX_PHOTO_MB      = 5;
const MAX_ATTACHMENT_MB = 10;
const IMAGE_EXTS = ['jpg','jpeg','png','webp','gif','bmp','svg'];

/**
 * Dosyanın resim olup olmadığını URL'den kontrol eder.
 */
function isImageUrl(url) {
  if (!url) return false;
  const ext = url.split('?')[0].split('.').pop().toLowerCase();
  return IMAGE_EXTS.includes(ext);
}

/**
 * Dosyanın resim olup olmadığını File nesnesinden kontrol eder.
 */
function isImageFile(file) {
  return file && file.type.startsWith('image/');
}

/**
 * Dosya boyutu kontrolü (MB cinsinden).
 * true → geçerli, false → fazla büyük.
 */
function checkFileSize(file, maxMb) {
  return file.size <= maxMb * 1024 * 1024;
}

/**
 * Çocuk profil fotoğrafı yükler.
 * @param {File}   file     — seçilen dosya
 * @param {string} childId  — çocuk ID'si
 * @returns {string} publicUrl
 */
async function uploadChildPhoto(file, childId) {
  if (!checkFileSize(file, MAX_PHOTO_MB)) {
    throw new Error(`Fotoğraf en fazla ${MAX_PHOTO_MB} MB olabilir.`);
  }
  const ext  = file.name.split('.').pop().toLowerCase();
  const path = `${childId}.${ext}`;

  const { error } = await supabaseClient.storage
    .from('child-photos')
    .upload(path, file, { upsert: true, cacheControl: '3600' });

  if (error) throw new Error('Fotoğraf yüklenemedi: ' + error.message);

  const { data: { publicUrl } } = supabaseClient.storage
    .from('child-photos').getPublicUrl(path);

  return publicUrl;
}

/**
 * Çocuk fotoğrafını storage'dan siler.
 * @param {string} photoUrl — mevcut public URL
 */
async function deleteChildPhoto(photoUrl) {
  if (!photoUrl) return;
  // URL'den path'i çıkar: .../child-photos/XXXX.jpg → XXXX.jpg
  const path = photoUrl.split('/child-photos/').pop().split('?')[0];
  await supabaseClient.storage.from('child-photos').remove([path]);
}

/**
 * Log eki yükler (ödül/ceza).
 * @param {File} file
 * @returns {string} publicUrl
 */
async function uploadLogAttachment(file) {
  if (!checkFileSize(file, MAX_ATTACHMENT_MB)) {
    throw new Error(`Dosya en fazla ${MAX_ATTACHMENT_MB} MB olabilir.`);
  }
  const ext  = file.name.split('.').pop().toLowerCase();
  const uid  = `${Date.now()}_${Math.random().toString(36).slice(2, 8)}`;
  const path = `${uid}.${ext}`;

  const { error } = await supabaseClient.storage
    .from('log-attachments')
    .upload(path, file, { upsert: false, cacheControl: '86400' });

  if (error) throw new Error('Dosya yüklenemedi: ' + error.message);

  const { data: { publicUrl } } = supabaseClient.storage
    .from('log-attachments').getPublicUrl(path);

  return publicUrl;
}

/**
 * Log ekini storage'dan siler.
 */
async function deleteLogAttachment(attachmentUrl) {
  if (!attachmentUrl) return;
  const path = attachmentUrl.split('/log-attachments/').pop().split('?')[0];
  await supabaseClient.storage.from('log-attachments').remove([path]);
}
