-- =====================================================
--  Yıldız Çocuklar — Storage & Yeni Sütunlar
-- =====================================================
-- Bu dosyayı Supabase → SQL Editor'de çalıştırın.

-- ── Yeni sütunlar ─────────────────────────────────

ALTER TABLE children    ADD COLUMN IF NOT EXISTS photo_url TEXT;
ALTER TABLE reward_logs  ADD COLUMN IF NOT EXISTS attachment_url TEXT;
ALTER TABLE penalty_logs ADD COLUMN IF NOT EXISTS attachment_url TEXT;

-- ── Storage bucket'ları ────────────────────────────
-- (bucket'lar daha önce oluşturulmamışsa)

INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES
  ('child-photos',    'child-photos',    true, 5242880,
   ARRAY['image/jpeg','image/png','image/webp','image/gif']),
  ('log-attachments', 'log-attachments', true, 10485760,
   ARRAY['image/jpeg','image/png','image/webp','image/gif',
         'application/pdf','application/msword',
         'application/vnd.openxmlformats-officedocument.wordprocessingml.document'])
ON CONFLICT (id) DO NOTHING;

-- ── Storage RLS politikaları ───────────────────────

-- Herkes okuyabilir (public bucket)
CREATE POLICY "public_read_photos"
  ON storage.objects FOR SELECT
  USING (bucket_id = 'child-photos');

CREATE POLICY "public_read_attachments"
  ON storage.objects FOR SELECT
  USING (bucket_id = 'log-attachments');

-- Giriş yapmış kullanıcı yükleyebilir / güncelleyebilir / silebilir
CREATE POLICY "auth_upload_photos"
  ON storage.objects FOR INSERT TO authenticated
  WITH CHECK (bucket_id = 'child-photos');

CREATE POLICY "auth_update_photos"
  ON storage.objects FOR UPDATE TO authenticated
  USING (bucket_id = 'child-photos');

CREATE POLICY "auth_delete_photos"
  ON storage.objects FOR DELETE TO authenticated
  USING (bucket_id = 'child-photos');

CREATE POLICY "auth_upload_attachments"
  ON storage.objects FOR INSERT TO authenticated
  WITH CHECK (bucket_id = 'log-attachments');

CREATE POLICY "auth_delete_attachments"
  ON storage.objects FOR DELETE TO authenticated
  USING (bucket_id = 'log-attachments');
