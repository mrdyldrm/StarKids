-- =====================================================
--  Yıldız Çocuklar — Çocuk Kategorisi
-- =====================================================
-- Bu dosyayı Supabase → SQL Editor'de çalıştırın.

-- 1. Sütunları ekle (daha önce eklenmediyse)
ALTER TABLE children ADD COLUMN IF NOT EXISTS photo_url TEXT;
ALTER TABLE children ADD COLUMN IF NOT EXISTS category  TEXT DEFAULT '';

-- 2. Mevcut view'ları sil (CASCADE: bağımlı nesneleri de temizler)
DROP VIEW IF EXISTS children_monthly_scores CASCADE;
DROP VIEW IF EXISTS children_scores         CASCADE;

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

GRANT SELECT ON children_scores         TO authenticated;
GRANT SELECT ON children_monthly_scores TO authenticated;
