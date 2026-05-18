-- =====================================================
--  Yıldız Çocuklar — Kullanıcı Yönetimi
-- =====================================================
-- Bu dosyayı Supabase → SQL Editor bölümünde çalıştırın.
-- Önemli: schema.sql VE diğer migration dosyaları daha önce çalıştırılmış olmalıdır.

-- ── Profil tablosu ─────────────────────────────────

CREATE TABLE IF NOT EXISTS profiles (
  id         UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  email      TEXT,
  full_name  TEXT DEFAULT '',
  role       TEXT NOT NULL DEFAULT 'viewer' CHECK (role IN ('admin', 'editor', 'viewer')),
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ── Rol sorgulama fonksiyonu (RLS döngüsünü önler) ─

CREATE OR REPLACE FUNCTION get_my_role()
RETURNS TEXT AS $$
  SELECT role FROM profiles WHERE id = auth.uid();
$$ LANGUAGE sql SECURITY DEFINER STABLE;

-- ── Admin: başka kullanıcının şifresini değiştir ──
-- pgcrypto uzantısı gerekli (Supabase'de varsayılan olarak etkin)

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

-- ── Yeni kayıtta otomatik profil oluştur ───────────

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

-- ── Mevcut kullanıcılar için profil oluştur ────────
-- İlk oluşturulan kullanıcı admin, diğerleri viewer olur.

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

-- ── RLS — profiles ─────────────────────────────────

ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "read_profiles"          ON profiles;
DROP POLICY IF EXISTS "admin_update_profiles"  ON profiles;
DROP POLICY IF EXISTS "admin_delete_profiles"  ON profiles;
DROP POLICY IF EXISTS "insert_own_profile"     ON profiles;

CREATE POLICY "read_profiles" ON profiles
  FOR SELECT TO authenticated USING (true);

CREATE POLICY "admin_update_profiles" ON profiles
  FOR UPDATE TO authenticated
  USING (get_my_role() = 'admin')
  WITH CHECK (get_my_role() = 'admin');

CREATE POLICY "admin_delete_profiles" ON profiles
  FOR DELETE TO authenticated
  USING (get_my_role() = 'admin');

CREATE POLICY "insert_own_profile" ON profiles
  FOR INSERT TO authenticated
  WITH CHECK (id = auth.uid());

GRANT SELECT, INSERT, UPDATE, DELETE ON profiles TO authenticated;

-- ── RLS — mevcut politikaları kaldır ───────────────

DROP POLICY IF EXISTS "admin_all" ON children;
DROP POLICY IF EXISTS "admin_all" ON reward_rules;
DROP POLICY IF EXISTS "admin_all" ON penalty_rules;
DROP POLICY IF EXISTS "admin_all" ON reward_logs;
DROP POLICY IF EXISTS "admin_all" ON penalty_logs;
DROP POLICY IF EXISTS "admin_all" ON goals;
DROP POLICY IF EXISTS "admin_all" ON categories;
DROP POLICY IF EXISTS "admin_all" ON periods;

-- ── RLS — children ─────────────────────────────────

DROP POLICY IF EXISTS "select_children"        ON children;
DROP POLICY IF EXISTS "admin_insert_children"  ON children;
DROP POLICY IF EXISTS "admin_update_children"  ON children;
DROP POLICY IF EXISTS "admin_delete_children"  ON children;

CREATE POLICY "select_children" ON children
  FOR SELECT TO authenticated USING (true);
CREATE POLICY "admin_insert_children" ON children
  FOR INSERT TO authenticated WITH CHECK (get_my_role() = 'admin');
CREATE POLICY "admin_update_children" ON children
  FOR UPDATE TO authenticated
  USING (get_my_role() = 'admin') WITH CHECK (get_my_role() = 'admin');
CREATE POLICY "admin_delete_children" ON children
  FOR DELETE TO authenticated USING (get_my_role() = 'admin');

-- ── RLS — reward_rules ─────────────────────────────

DROP POLICY IF EXISTS "select_reward_rules"        ON reward_rules;
DROP POLICY IF EXISTS "admin_insert_reward_rules"  ON reward_rules;
DROP POLICY IF EXISTS "admin_update_reward_rules"  ON reward_rules;
DROP POLICY IF EXISTS "admin_delete_reward_rules"  ON reward_rules;

CREATE POLICY "select_reward_rules" ON reward_rules
  FOR SELECT TO authenticated USING (true);
CREATE POLICY "admin_insert_reward_rules" ON reward_rules
  FOR INSERT TO authenticated WITH CHECK (get_my_role() = 'admin');
CREATE POLICY "admin_update_reward_rules" ON reward_rules
  FOR UPDATE TO authenticated
  USING (get_my_role() = 'admin') WITH CHECK (get_my_role() = 'admin');
CREATE POLICY "admin_delete_reward_rules" ON reward_rules
  FOR DELETE TO authenticated USING (get_my_role() = 'admin');

-- ── RLS — penalty_rules ────────────────────────────

DROP POLICY IF EXISTS "select_penalty_rules"        ON penalty_rules;
DROP POLICY IF EXISTS "admin_insert_penalty_rules"  ON penalty_rules;
DROP POLICY IF EXISTS "admin_update_penalty_rules"  ON penalty_rules;
DROP POLICY IF EXISTS "admin_delete_penalty_rules"  ON penalty_rules;

CREATE POLICY "select_penalty_rules" ON penalty_rules
  FOR SELECT TO authenticated USING (true);
CREATE POLICY "admin_insert_penalty_rules" ON penalty_rules
  FOR INSERT TO authenticated WITH CHECK (get_my_role() = 'admin');
CREATE POLICY "admin_update_penalty_rules" ON penalty_rules
  FOR UPDATE TO authenticated
  USING (get_my_role() = 'admin') WITH CHECK (get_my_role() = 'admin');
CREATE POLICY "admin_delete_penalty_rules" ON penalty_rules
  FOR DELETE TO authenticated USING (get_my_role() = 'admin');

-- ── RLS — reward_logs ──────────────────────────────
-- Admin: tam erişim | Editör: SELECT + INSERT | İzleyici: sadece SELECT

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

-- ── RLS — penalty_logs ─────────────────────────────

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

-- ── RLS — goals ────────────────────────────────────

DROP POLICY IF EXISTS "select_goals"        ON goals;
DROP POLICY IF EXISTS "admin_insert_goals"  ON goals;
DROP POLICY IF EXISTS "admin_update_goals"  ON goals;
DROP POLICY IF EXISTS "admin_delete_goals"  ON goals;

CREATE POLICY "select_goals" ON goals
  FOR SELECT TO authenticated USING (true);
CREATE POLICY "admin_insert_goals" ON goals
  FOR INSERT TO authenticated WITH CHECK (get_my_role() = 'admin');
CREATE POLICY "admin_update_goals" ON goals
  FOR UPDATE TO authenticated
  USING (get_my_role() = 'admin') WITH CHECK (get_my_role() = 'admin');
CREATE POLICY "admin_delete_goals" ON goals
  FOR DELETE TO authenticated USING (get_my_role() = 'admin');

-- ── RLS — categories ───────────────────────────────

DROP POLICY IF EXISTS "select_categories"        ON categories;
DROP POLICY IF EXISTS "admin_insert_categories"  ON categories;
DROP POLICY IF EXISTS "admin_update_categories"  ON categories;
DROP POLICY IF EXISTS "admin_delete_categories"  ON categories;

CREATE POLICY "select_categories" ON categories
  FOR SELECT TO authenticated USING (true);
CREATE POLICY "admin_insert_categories" ON categories
  FOR INSERT TO authenticated WITH CHECK (get_my_role() = 'admin');
CREATE POLICY "admin_update_categories" ON categories
  FOR UPDATE TO authenticated
  USING (get_my_role() = 'admin') WITH CHECK (get_my_role() = 'admin');
CREATE POLICY "admin_delete_categories" ON categories
  FOR DELETE TO authenticated USING (get_my_role() = 'admin');

-- ── RLS — periods ──────────────────────────────────

DROP POLICY IF EXISTS "select_periods"        ON periods;
DROP POLICY IF EXISTS "admin_insert_periods"  ON periods;
DROP POLICY IF EXISTS "admin_update_periods"  ON periods;
DROP POLICY IF EXISTS "admin_delete_periods"  ON periods;

CREATE POLICY "select_periods" ON periods
  FOR SELECT TO authenticated USING (true);
CREATE POLICY "admin_insert_periods" ON periods
  FOR INSERT TO authenticated WITH CHECK (get_my_role() = 'admin');
CREATE POLICY "admin_update_periods" ON periods
  FOR UPDATE TO authenticated
  USING (get_my_role() = 'admin') WITH CHECK (get_my_role() = 'admin');
CREATE POLICY "admin_delete_periods" ON periods
  FOR DELETE TO authenticated USING (get_my_role() = 'admin');
