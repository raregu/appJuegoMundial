-- ============================================================
-- Agrega soporte de logo a los juegos
-- Ejecutar en Supabase → SQL Editor
-- ============================================================

ALTER TABLE games ADD COLUMN IF NOT EXISTS logo_url text;

SELECT 'Columna logo_url agregada ✓' AS resultado;
