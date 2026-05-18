-- =====================================================
--  Yıldız Çocuklar - Veritabanı Şeması
-- =====================================================
-- Bu dosyayı Supabase → SQL Editor bölümünde çalıştırın.

-- ── Tablolar ──────────────────────────────────────

CREATE TABLE IF NOT EXISTS children (
  id         UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  name       TEXT NOT NULL,
  avatar     TEXT DEFAULT '🧒',
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS reward_rules (
  id          UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  title       TEXT NOT NULL,
  description TEXT DEFAULT '',
  points      INTEGER NOT NULL DEFAULT 10,
  icon        TEXT DEFAULT '⭐',
  created_at  TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS penalty_rules (
  id          UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  title       TEXT NOT NULL,
  description TEXT DEFAULT '',
  points      INTEGER NOT NULL DEFAULT 10,
  icon        TEXT DEFAULT '⚠️',
  created_at  TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS reward_logs (
  id         UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  child_id   UUID REFERENCES children(id) ON DELETE CASCADE NOT NULL,
  rule_id    UUID REFERENCES reward_rules(id) ON DELETE SET NULL,
  rule_title TEXT NOT NULL,
  rule_icon  TEXT DEFAULT '⭐',
  points     INTEGER NOT NULL,
  note       TEXT DEFAULT '',
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS penalty_logs (
  id         UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  child_id   UUID REFERENCES children(id) ON DELETE CASCADE NOT NULL,
  rule_id    UUID REFERENCES penalty_rules(id) ON DELETE SET NULL,
  rule_title TEXT NOT NULL,
  rule_icon  TEXT DEFAULT '⚠️',
  points     INTEGER NOT NULL,
  note       TEXT DEFAULT '',
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ── Puan Özeti Görünümü ────────────────────────────

CREATE OR REPLACE VIEW children_scores AS
SELECT
  c.id,
  c.name,
  c.avatar,
  c.created_at,
  COALESCE(r.total, 0)                       AS total_reward_points,
  COALESCE(p.total, 0)                       AS total_penalty_points,
  COALESCE(r.total, 0) - COALESCE(p.total, 0) AS net_score
FROM children c
LEFT JOIN (
  SELECT child_id, SUM(points) AS total FROM reward_logs  GROUP BY child_id
) r ON c.id = r.child_id
LEFT JOIN (
  SELECT child_id, SUM(points) AS total FROM penalty_logs GROUP BY child_id
) p ON c.id = p.child_id;

-- ── Aylık Puan Özeti Görünümü (cari ay) ───────────

CREATE OR REPLACE VIEW children_monthly_scores AS
SELECT
  c.id,
  c.name,
  c.avatar,
  COALESCE(r.total, 0)                           AS monthly_reward_points,
  COALESCE(p.total, 0)                           AS monthly_penalty_points,
  COALESCE(r.total, 0) - COALESCE(p.total, 0)   AS monthly_net_score,
  DATE_TRUNC('month', NOW())                     AS period_start
FROM children c
LEFT JOIN (
  SELECT child_id, SUM(points) AS total FROM reward_logs
  WHERE DATE_TRUNC('month', created_at) = DATE_TRUNC('month', NOW())
  GROUP BY child_id
) r ON c.id = r.child_id
LEFT JOIN (
  SELECT child_id, SUM(points) AS total FROM penalty_logs
  WHERE DATE_TRUNC('month', created_at) = DATE_TRUNC('month', NOW())
  GROUP BY child_id
) p ON c.id = p.child_id;

GRANT SELECT ON children_monthly_scores TO authenticated;

-- ── Row Level Security ─────────────────────────────

ALTER TABLE children     ENABLE ROW LEVEL SECURITY;
ALTER TABLE reward_rules ENABLE ROW LEVEL SECURITY;
ALTER TABLE penalty_rules ENABLE ROW LEVEL SECURITY;
ALTER TABLE reward_logs   ENABLE ROW LEVEL SECURITY;
ALTER TABLE penalty_logs  ENABLE ROW LEVEL SECURITY;

-- Giriş yapmış kullanıcı (yönetici) her şeye erişebilir
CREATE POLICY "admin_all" ON children      FOR ALL TO authenticated USING (true) WITH CHECK (true);
CREATE POLICY "admin_all" ON reward_rules  FOR ALL TO authenticated USING (true) WITH CHECK (true);
CREATE POLICY "admin_all" ON penalty_rules FOR ALL TO authenticated USING (true) WITH CHECK (true);
CREATE POLICY "admin_all" ON reward_logs   FOR ALL TO authenticated USING (true) WITH CHECK (true);
CREATE POLICY "admin_all" ON penalty_logs  FOR ALL TO authenticated USING (true) WITH CHECK (true);

GRANT SELECT ON children_scores TO authenticated;

-- ── Örnek Veriler (isteğe bağlı) ───────────────────

INSERT INTO reward_rules (title, description, points, icon) VALUES
  ('Ödevini Yaptı',     'Günlük ödevini eksiksiz tamamladı', 20, '📚'),
  ('Odayı Topladı',     'Odasını düzenli hale getirdi',      15, '🏠'),
  ('Dişlerini Fırçaladı', 'Sabah ve akşam dişlerini fırçaladı', 10, '🦷'),
  ('Yardım Etti',       'Ev işlerinde yardımcı oldu',        15, '🤝'),
  ('Kitap Okudu',       'En az 20 dakika kitap okudu',       20, '📖')
ON CONFLICT DO NOTHING;

INSERT INTO penalty_rules (title, description, points, icon) VALUES
  ('Kardeşiyle Kavga',  'Kardeşiyle tartıştı veya kavga etti', 15, '😤'),
  ('Ekran Süresi Aştı', 'İzin verilen ekran süresini aştı',    10, '📱'),
  ('Yalan Söyledi',     'Ebeveynlerine yalan söyledi',         20, '🤥'),
  ('Lafını Dinlemedi',  'İlk söylendiğinde yapmadı',            10, '🙉')
ON CONFLICT DO NOTHING;
