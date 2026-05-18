-- =====================================================
--  Yıldız Çocuklar — Kategoriler Tablosu
-- =====================================================
-- Bu dosyayı Supabase → SQL Editor'de çalıştırın.

CREATE TABLE IF NOT EXISTS categories (
  id         UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  name       TEXT NOT NULL UNIQUE,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE categories ENABLE ROW LEVEL SECURITY;
CREATE POLICY "admin_all" ON categories
  FOR ALL TO authenticated USING (true) WITH CHECK (true);

-- Örnek kategoriler (isteğe bağlı)
INSERT INTO categories (name) VALUES
  ('Küçükler'), ('Büyükler'), ('1. Sınıf'), ('2. Sınıf')
ON CONFLICT DO NOTHING;
