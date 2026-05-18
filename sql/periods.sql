-- =====================================================
--  Yıldız Çocuklar — Dönemler Tablosu
-- =====================================================
-- Bu dosyayı Supabase → SQL Editor'de çalıştırın.

CREATE TABLE IF NOT EXISTS periods (
  id         UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  name       TEXT NOT NULL,
  type       TEXT NOT NULL CHECK (type IN ('weekly','monthly','custom')),
  start_date DATE NOT NULL,
  end_date   DATE NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE periods ENABLE ROW LEVEL SECURITY;
CREATE POLICY "admin_all" ON periods
  FOR ALL TO authenticated USING (true) WITH CHECK (true);
