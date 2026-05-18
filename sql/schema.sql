-- =====================================================
--  Yıldız Çocuklar — Tam Veritabanı Şeması
-- =====================================================
--  Bu tek dosyayı Supabase → SQL Editor'de çalıştırın.
--  Tüm migration dosyalarının birleştirilmiş, sıralı halidir:
--    schema.sql · categories.sql · periods.sql · goals.sql
--    goals_update.sql · category.sql · storage.sql · users.sql
-- =====================================================


-- ══════════════════════════════════════════════════════
-- 1. TABLOLAR
-- ══════════════════════════════════════════════════════

-- Çocuklar (photo_url ve category baştan dahil)
CREATE TABLE IF NOT EXISTS children (
  id         UUID    DEFAULT gen_random_uuid() PRIMARY KEY,
  name       TEXT    NOT NULL,
  avatar     TEXT    DEFAULT '🧒',
  photo_url  TEXT,
  category   TEXT    DEFAULT '',
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Ödül kuralları
CREATE TABLE IF NOT EXISTS reward_rules (
  id          UUID    DEFAULT gen_random_uuid() PRIMARY KEY,
  title       TEXT    NOT NULL,
  description TEXT    DEFAULT '',
  points      INTEGER NOT NULL DEFAULT 10,
  icon        TEXT    DEFAULT '⭐',
  created_at  TIMESTAMPTZ DEFAULT NOW()
);

-- Ceza kuralları
CREATE TABLE IF NOT EXISTS penalty_rules (
  id          UUID    DEFAULT gen_random_uuid() PRIMARY KEY,
  title       TEXT    NOT NULL,
  description TEXT    DEFAULT '',
  points      INTEGER NOT NULL DEFAULT 10,
  icon        TEXT    DEFAULT '⚠️',
  created_at  TIMESTAMPTZ DEFAULT NOW()
);

-- Ödül kayıtları (attachment_url baştan dahil)
CREATE TABLE IF NOT EXISTS reward_logs (
  id             UUID    DEFAULT gen_random_uuid() PRIMARY KEY,
  child_id       UUID    REFERENCES children(id) ON DELETE CASCADE NOT NULL,
  rule_id        UUID    REFERENCES reward_rules(id) ON DELETE SET NULL,
  rule_title     TEXT    NOT NULL,
  rule_icon      TEXT    DEFAULT '⭐',
  points         INTEGER NOT NULL,
  note           TEXT    DEFAULT '',
  attachment_url TEXT,
  created_at     TIMESTAMPTZ DEFAULT NOW()
);

-- Ceza kayıtları (attachment_url baştan dahil)
CREATE TABLE IF NOT EXISTS penalty_logs (
  id             UUID    DEFAULT gen_random_uuid() PRIMARY KEY,
  child_id       UUID    REFERENCES children(id) ON DELETE CASCADE NOT NULL,
  rule_id        UUID    REFERENCES penalty_rules(id) ON DELETE SET NULL,
  rule_title     TEXT    NOT NULL,
  rule_icon      TEXT    DEFAULT '⚠️',
  points         INTEGER NOT NULL,
  note           TEXT    DEFAULT '',
  attachment_url TEXT,
  created_at     TIMESTAMPTZ DEFAULT NOW()
);

-- Kategoriler
CREATE TABLE IF NOT EXISTS categories (
  id         UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  name       TEXT NOT NULL UNIQUE,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Dönemler
CREATE TABLE IF NOT EXISTS periods (
  id         UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  name       TEXT NOT NULL,
  type       TEXT NOT NULL CHECK (type IN ('weekly','monthly','custom')),
  start_date DATE NOT NULL,
  end_date   DATE NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Hedefler (child_id NULL olabilir → ortak hedefler için)
CREATE TABLE IF NOT EXISTS goals (
  id           UUID    DEFAULT gen_random_uuid() PRIMARY KEY,
  child_id     UUID    REFERENCES children(id) ON DELETE CASCADE,
  title        TEXT    NOT NULL,
  type         TEXT    NOT NULL CHECK (type IN ('min_reward','max_penalty','min_net')),
  target_value INTEGER NOT NULL CHECK (target_value > 0),
  icon         TEXT    DEFAULT '🎯',
  created_at   TIMESTAMPTZ DEFAULT NOW()
);

-- Profiller (Supabase Auth ile entegre)
CREATE TABLE IF NOT EXISTS profiles (
  id         UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  email      TEXT,
  full_name  TEXT DEFAULT '',
  role       TEXT NOT NULL DEFAULT 'viewer'
               CHECK (role IN ('admin', 'editor', 'viewer')),
  created_at TIMESTAMPTZ DEFAULT NOW()
);


-- ══════════════════════════════════════════════════════
-- 2. FONKSİYONLAR & TETİKLEYİCİLER
-- ══════════════════════════════════════════════════════

-- Mevcut kullanıcının rolünü döndürür (RLS döngüsünü önler)
CREATE OR REPLACE FUNCTION get_my_role()
RETURNS TEXT AS $$
  SELECT role FROM profiles WHERE id = auth.uid();
$$ LANGUAGE sql SECURITY DEFINER STABLE;

-- Admin: başka kullanıcının şifresini değiştirir
CREATE OR REPLACE FUNCTION admin_set_user_password(target_user_id UUID, new_password TEXT)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  IF get_my_role() != 'admin' THEN
    RAISE EXCEPTION 'Yalnızca admin bu işlemi yapabilir';
  END IF;
  IF length(new_password) < 6 THEN
    RAISE EXCEPTION 'Şifre en az 6 karakter olmalı';
  END IF;
  UPDATE auth.users
  SET encrypted_password = crypt(new_password, gen_salt('bf'))
  WHERE id = target_user_id;
END;
$$;

-- Yeni kayıtta otomatik profil oluştur
CREATE OR REPLACE FUNCTION handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.profiles (id, email, full_name, role)
  VALUES (
    NEW.id,
    NEW.email,
    COALESCE(NEW.raw_user_meta_data->>'full_name', ''),
    COALESCE(NEW.raw_user_meta_data->>'role', 'viewer')
  )
  ON CONFLICT (id) DO NOTHING;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION handle_new_user();


-- ══════════════════════════════════════════════════════
-- 3. GÖRÜNÜMLER (VIEWS)
-- ══════════════════════════════════════════════════════

-- Tüm zamanlar puan özeti
CREATE OR REPLACE VIEW children_scores AS
SELECT
  c.id,
  c.name,
  c.avatar,
  c.photo_url,
  c.category,
  c.created_at,
  COALESCE(r.total, 0)                         AS total_reward_points,
  COALESCE(p.total, 0)                         AS total_penalty_points,
  COALESCE(r.total, 0) - COALESCE(p.total, 0) AS net_score
FROM children c
LEFT JOIN (
  SELECT child_id, SUM(points) AS total FROM reward_logs  GROUP BY child_id
) r ON c.id = r.child_id
LEFT JOIN (
  SELECT child_id, SUM(points) AS total FROM penalty_logs GROUP BY child_id
) p ON c.id = p.child_id;

-- Aylık puan özeti (cari ay)
CREATE OR REPLACE VIEW children_monthly_scores AS
SELECT
  c.id,
  c.name,
  c.avatar,
  c.photo_url,
  c.category,
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


-- ══════════════════════════════════════════════════════
-- 4. STORAGE
-- ══════════════════════════════════════════════════════

INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES
  ('child-photos',    'child-photos',    true, 5242880,
   ARRAY['image/jpeg','image/png','image/webp','image/gif']),
  ('log-attachments', 'log-attachments', true, 10485760,
   ARRAY['image/jpeg','image/png','image/webp','image/gif',
         'application/pdf','application/msword',
         'application/vnd.openxmlformats-officedocument.wordprocessingml.document'])
ON CONFLICT (id) DO NOTHING;

-- Storage RLS politikaları
CREATE POLICY "public_read_photos"
  ON storage.objects FOR SELECT
  USING (bucket_id = 'child-photos');

CREATE POLICY "public_read_attachments"
  ON storage.objects FOR SELECT
  USING (bucket_id = 'log-attachments');

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


-- ══════════════════════════════════════════════════════
-- 5. ROW LEVEL SECURITY
-- ══════════════════════════════════════════════════════

ALTER TABLE children      ENABLE ROW LEVEL SECURITY;
ALTER TABLE reward_rules  ENABLE ROW LEVEL SECURITY;
ALTER TABLE penalty_rules ENABLE ROW LEVEL SECURITY;
ALTER TABLE reward_logs   ENABLE ROW LEVEL SECURITY;
ALTER TABLE penalty_logs  ENABLE ROW LEVEL SECURITY;
ALTER TABLE categories    ENABLE ROW LEVEL SECURITY;
ALTER TABLE periods       ENABLE ROW LEVEL SECURITY;
ALTER TABLE goals         ENABLE ROW LEVEL SECURITY;
ALTER TABLE profiles      ENABLE ROW LEVEL SECURITY;

-- ── profiles ────────────────────────────────────────

DROP POLICY IF EXISTS "read_profiles"         ON profiles;
DROP POLICY IF EXISTS "admin_update_profiles" ON profiles;
DROP POLICY IF EXISTS "admin_delete_profiles" ON profiles;
DROP POLICY IF EXISTS "insert_own_profile"    ON profiles;

CREATE POLICY "read_profiles" ON profiles
  FOR SELECT TO authenticated USING (true);
CREATE POLICY "admin_update_profiles" ON profiles
  FOR UPDATE TO authenticated
  USING (get_my_role() = 'admin') WITH CHECK (get_my_role() = 'admin');
CREATE POLICY "admin_delete_profiles" ON profiles
  FOR DELETE TO authenticated
  USING (get_my_role() = 'admin');
CREATE POLICY "insert_own_profile" ON profiles
  FOR INSERT TO authenticated
  WITH CHECK (id = auth.uid());

-- ── children ────────────────────────────────────────

DROP POLICY IF EXISTS "select_children"       ON children;
DROP POLICY IF EXISTS "admin_insert_children" ON children;
DROP POLICY IF EXISTS "admin_update_children" ON children;
DROP POLICY IF EXISTS "admin_delete_children" ON children;

CREATE POLICY "select_children" ON children
  FOR SELECT TO authenticated USING (true);
CREATE POLICY "admin_insert_children" ON children
  FOR INSERT TO authenticated WITH CHECK (get_my_role() = 'admin');
CREATE POLICY "admin_update_children" ON children
  FOR UPDATE TO authenticated
  USING (get_my_role() = 'admin') WITH CHECK (get_my_role() = 'admin');
CREATE POLICY "admin_delete_children" ON children
  FOR DELETE TO authenticated USING (get_my_role() = 'admin');

-- ── reward_rules ─────────────────────────────────────

DROP POLICY IF EXISTS "select_reward_rules"       ON reward_rules;
DROP POLICY IF EXISTS "admin_insert_reward_rules" ON reward_rules;
DROP POLICY IF EXISTS "admin_update_reward_rules" ON reward_rules;
DROP POLICY IF EXISTS "admin_delete_reward_rules" ON reward_rules;

CREATE POLICY "select_reward_rules" ON reward_rules
  FOR SELECT TO authenticated USING (true);
CREATE POLICY "admin_insert_reward_rules" ON reward_rules
  FOR INSERT TO authenticated WITH CHECK (get_my_role() = 'admin');
CREATE POLICY "admin_update_reward_rules" ON reward_rules
  FOR UPDATE TO authenticated
  USING (get_my_role() = 'admin') WITH CHECK (get_my_role() = 'admin');
CREATE POLICY "admin_delete_reward_rules" ON reward_rules
  FOR DELETE TO authenticated USING (get_my_role() = 'admin');

-- ── penalty_rules ────────────────────────────────────

DROP POLICY IF EXISTS "select_penalty_rules"       ON penalty_rules;
DROP POLICY IF EXISTS "admin_insert_penalty_rules" ON penalty_rules;
DROP POLICY IF EXISTS "admin_update_penalty_rules" ON penalty_rules;
DROP POLICY IF EXISTS "admin_delete_penalty_rules" ON penalty_rules;

CREATE POLICY "select_penalty_rules" ON penalty_rules
  FOR SELECT TO authenticated USING (true);
CREATE POLICY "admin_insert_penalty_rules" ON penalty_rules
  FOR INSERT TO authenticated WITH CHECK (get_my_role() = 'admin');
CREATE POLICY "admin_update_penalty_rules" ON penalty_rules
  FOR UPDATE TO authenticated
  USING (get_my_role() = 'admin') WITH CHECK (get_my_role() = 'admin');
CREATE POLICY "admin_delete_penalty_rules" ON penalty_rules
  FOR DELETE TO authenticated USING (get_my_role() = 'admin');

-- ── reward_logs (editor de ekleyebilir) ─────────────

DROP POLICY IF EXISTS "select_reward_logs"        ON reward_logs;
DROP POLICY IF EXISTS "editor_insert_reward_logs" ON reward_logs;
DROP POLICY IF EXISTS "admin_update_reward_logs"  ON reward_logs;
DROP POLICY IF EXISTS "admin_delete_reward_logs"  ON reward_logs;

CREATE POLICY "select_reward_logs" ON reward_logs
  FOR SELECT TO authenticated USING (true);
CREATE POLICY "editor_insert_reward_logs" ON reward_logs
  FOR INSERT TO authenticated WITH CHECK (get_my_role() IN ('admin', 'editor'));
CREATE POLICY "admin_update_reward_logs" ON reward_logs
  FOR UPDATE TO authenticated
  USING (get_my_role() = 'admin') WITH CHECK (get_my_role() = 'admin');
CREATE POLICY "admin_delete_reward_logs" ON reward_logs
  FOR DELETE TO authenticated USING (get_my_role() = 'admin');

-- ── penalty_logs (editor de ekleyebilir) ────────────

DROP POLICY IF EXISTS "select_penalty_logs"        ON penalty_logs;
DROP POLICY IF EXISTS "editor_insert_penalty_logs" ON penalty_logs;
DROP POLICY IF EXISTS "admin_update_penalty_logs"  ON penalty_logs;
DROP POLICY IF EXISTS "admin_delete_penalty_logs"  ON penalty_logs;

CREATE POLICY "select_penalty_logs" ON penalty_logs
  FOR SELECT TO authenticated USING (true);
CREATE POLICY "editor_insert_penalty_logs" ON penalty_logs
  FOR INSERT TO authenticated WITH CHECK (get_my_role() IN ('admin', 'editor'));
CREATE POLICY "admin_update_penalty_logs" ON penalty_logs
  FOR UPDATE TO authenticated
  USING (get_my_role() = 'admin') WITH CHECK (get_my_role() = 'admin');
CREATE POLICY "admin_delete_penalty_logs" ON penalty_logs
  FOR DELETE TO authenticated USING (get_my_role() = 'admin');

-- ── categories ───────────────────────────────────────

DROP POLICY IF EXISTS "select_categories"       ON categories;
DROP POLICY IF EXISTS "admin_insert_categories" ON categories;
DROP POLICY IF EXISTS "admin_update_categories" ON categories;
DROP POLICY IF EXISTS "admin_delete_categories" ON categories;

CREATE POLICY "select_categories" ON categories
  FOR SELECT TO authenticated USING (true);
CREATE POLICY "admin_insert_categories" ON categories
  FOR INSERT TO authenticated WITH CHECK (get_my_role() = 'admin');
CREATE POLICY "admin_update_categories" ON categories
  FOR UPDATE TO authenticated
  USING (get_my_role() = 'admin') WITH CHECK (get_my_role() = 'admin');
CREATE POLICY "admin_delete_categories" ON categories
  FOR DELETE TO authenticated USING (get_my_role() = 'admin');

-- ── periods ──────────────────────────────────────────

DROP POLICY IF EXISTS "select_periods"       ON periods;
DROP POLICY IF EXISTS "admin_insert_periods" ON periods;
DROP POLICY IF EXISTS "admin_update_periods" ON periods;
DROP POLICY IF EXISTS "admin_delete_periods" ON periods;

CREATE POLICY "select_periods" ON periods
  FOR SELECT TO authenticated USING (true);
CREATE POLICY "admin_insert_periods" ON periods
  FOR INSERT TO authenticated WITH CHECK (get_my_role() = 'admin');
CREATE POLICY "admin_update_periods" ON periods
  FOR UPDATE TO authenticated
  USING (get_my_role() = 'admin') WITH CHECK (get_my_role() = 'admin');
CREATE POLICY "admin_delete_periods" ON periods
  FOR DELETE TO authenticated USING (get_my_role() = 'admin');

-- ── goals ────────────────────────────────────────────

DROP POLICY IF EXISTS "select_goals"       ON goals;
DROP POLICY IF EXISTS "admin_insert_goals" ON goals;
DROP POLICY IF EXISTS "admin_update_goals" ON goals;
DROP POLICY IF EXISTS "admin_delete_goals" ON goals;

CREATE POLICY "select_goals" ON goals
  FOR SELECT TO authenticated USING (true);
CREATE POLICY "admin_insert_goals" ON goals
  FOR INSERT TO authenticated WITH CHECK (get_my_role() = 'admin');
CREATE POLICY "admin_update_goals" ON goals
  FOR UPDATE TO authenticated
  USING (get_my_role() = 'admin') WITH CHECK (get_my_role() = 'admin');
CREATE POLICY "admin_delete_goals" ON goals
  FOR DELETE TO authenticated USING (get_my_role() = 'admin');


-- ══════════════════════════════════════════════════════
-- 6. GRANT'LAR
-- ══════════════════════════════════════════════════════

GRANT SELECT, INSERT, UPDATE, DELETE ON profiles      TO authenticated;
GRANT SELECT ON children_scores         TO authenticated;
GRANT SELECT ON children_monthly_scores TO authenticated;


-- ══════════════════════════════════════════════════════
-- 7. BAŞLANGIÇ VERİLERİ
-- ══════════════════════════════════════════════════════

-- Mevcut auth kullanıcıları için profil oluştur
-- (ilk oluşturulan kullanıcı admin, diğerleri viewer)
INSERT INTO profiles (id, email, full_name, role)
SELECT
  id,
  email,
  COALESCE(raw_user_meta_data->>'full_name', ''),
  CASE
    WHEN id = (SELECT id FROM auth.users ORDER BY created_at ASC LIMIT 1) THEN 'admin'
    ELSE 'viewer'
  END
FROM auth.users
ON CONFLICT (id) DO NOTHING;

-- Örnek kategoriler
INSERT INTO categories (name) VALUES
  ('Küçükler'), ('Büyükler'), ('1. Sınıf'), ('2. Sınıf')
ON CONFLICT DO NOTHING;

-- Örnek ödül kuralları
INSERT INTO reward_rules (title, description, points, icon) VALUES
  ('Ödevini Yaptı',       'Günlük ödevini eksiksiz tamamladı',     20, '📚'),
  ('Odayı Topladı',       'Odasını düzenli hale getirdi',          15, '🏠'),
  ('Dişlerini Fırçaladı', 'Sabah ve akşam dişlerini fırçaladı',   10, '🦷'),
  ('Yardım Etti',         'Ev işlerinde yardımcı oldu',            15, '🤝'),
  ('Kitap Okudu',         'En az 20 dakika kitap okudu',           20, '📖')
ON CONFLICT DO NOTHING;

-- Örnek ceza kuralları
INSERT INTO penalty_rules (title, description, points, icon) VALUES
  ('Kardeşiyle Kavga',  'Kardeşiyle tartıştı veya kavga etti',  15, '😤'),
  ('Ekran Süresi Aştı', 'İzin verilen ekran süresini aştı',     10, '📱'),
  ('Yalan Söyledi',     'Ebeveynlerine yalan söyledi',           20, '🤥'),
  ('Lafını Dinlemedi',  'İlk söylendiğinde yapmadı',             10, '🙉')
ON CONFLICT DO NOTHING;
