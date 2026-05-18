-- =====================================================
--  Yıldız Çocuklar — Hedefler Tablosu (ek migrasyon)
-- =====================================================
-- Bu dosyayı Supabase → SQL Editor'de çalıştırın.
-- (schema.sql'i daha önce çalıştırdıysanız bu ek dosyayı çalıştırın)

CREATE TABLE IF NOT EXISTS goals (
  id           UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  child_id     UUID REFERENCES children(id) ON DELETE CASCADE NOT NULL,
  title        TEXT NOT NULL,
  type         TEXT NOT NULL CHECK (type IN ('min_reward','max_penalty','min_net')),
  target_value INTEGER NOT NULL CHECK (target_value > 0),
  icon         TEXT DEFAULT '🎯',
  created_at   TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE goals ENABLE ROW LEVEL SECURITY;
CREATE POLICY "admin_all" ON goals FOR ALL TO authenticated USING (true) WITH CHECK (true);

-- Örnek hedefler (isteğe bağlı — mevcut çocuklar için çalıştırabilirsiniz)
-- INSERT INTO goals (child_id, title, type, target_value, icon)
-- SELECT id, 'Aylık Ödül Hedefi', 'min_reward', 100, '⭐' FROM children LIMIT 1;
