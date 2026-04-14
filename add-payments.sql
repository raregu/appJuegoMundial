-- ====================================================
-- App Mundial 2026 — Migración: Sistema de Pagos
-- Ejecutar en Supabase SQL Editor
-- ====================================================

ALTER TABLE games
  ADD COLUMN IF NOT EXISTS max_members  integer DEFAULT 10,
  ADD COLUMN IF NOT EXISTS plan         text    DEFAULT 'free',
  ADD COLUMN IF NOT EXISTS payment_status text  DEFAULT 'free',
  ADD COLUMN IF NOT EXISTS payment_id   text;

-- Asegurarse de que los juegos existentes queden en plan free con máx 10
UPDATE games SET
  max_members   = 10,
  plan          = 'free',
  payment_status = 'free'
WHERE plan IS NULL OR plan = '';

-- Comentario: los planes son:
--   free       → max_members = 10,  price = 0
--   starter    → max_members = 50,  price = USD 5
--   pro        → max_members = 100, price = USD 10
--   enterprise → max_members = 999, price = USD 30
