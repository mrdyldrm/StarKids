-- =====================================================
--  Yıldız Çocuklar — Hedef Kapsam Güncellemesi
-- =====================================================
-- Bu dosyayı Supabase → SQL Editor'de ÇALIŞTIRIN.
-- Ortak hedefler için child_id NULL olabilmeli.
--
-- ⚠️  Bu adımı atlamayın! Çalıştırmadan ortak hedef
--     kaydedemezsiniz ("child_id null olamaz" hatası alırsınız).

-- 1. NOT NULL kısıtını kaldır
ALTER TABLE goals ALTER COLUMN child_id DROP NOT NULL;

-- 2. Mevcut foreign key'i yeniden tanımla (CASCADE korunsun)
ALTER TABLE goals DROP CONSTRAINT IF EXISTS goals_child_id_fkey;
ALTER TABLE goals
  ADD CONSTRAINT goals_child_id_fkey
  FOREIGN KEY (child_id) REFERENCES children(id) ON DELETE CASCADE;
