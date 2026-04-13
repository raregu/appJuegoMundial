-- ============================================================
-- FIX: RLS para tabla games
-- Ejecuta esto en Supabase → SQL Editor
-- ============================================================

-- 1. INSERT: cualquier usuario autenticado puede crear un juego
DROP POLICY IF EXISTS "games_insert" ON games;
CREATE POLICY "games_insert" ON games
  FOR INSERT TO authenticated
  WITH CHECK (true);

-- 2. Trigger que fuerza created_by = auth.uid() del lado del servidor
CREATE OR REPLACE FUNCTION set_game_created_by()
RETURNS trigger AS $$
BEGIN
  NEW.created_by := auth.uid();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS games_set_created_by ON games;
CREATE TRIGGER games_set_created_by
  BEFORE INSERT ON games
  FOR EACH ROW EXECUTE FUNCTION set_game_created_by();

-- 3. SELECT: cualquier usuario autenticado puede ver TODOS los juegos
--    Esto es necesario para poder buscar un juego por invite_code al unirse
--    (antes de ser miembro, no puede ver nada → "Código no encontrado")
DROP POLICY IF EXISTS "games_select" ON games;
CREATE POLICY "games_select" ON games
  FOR SELECT TO authenticated
  USING (true);

-- 4. UPDATE: solo el creador puede modificar el juego
DROP POLICY IF EXISTS "games_update" ON games;
CREATE POLICY "games_update" ON games
  FOR UPDATE TO authenticated
  USING (created_by = auth.uid());

-- 5. DELETE: solo el creador puede eliminar el juego
DROP POLICY IF EXISTS "games_delete" ON games;
CREATE POLICY "games_delete" ON games
  FOR DELETE TO authenticated
  USING (created_by = auth.uid());

-- 6. game_members INSERT: cualquier autenticado puede insertarse como miembro
DROP POLICY IF EXISTS "game_members_insert" ON game_members;
CREATE POLICY "game_members_insert" ON game_members
  FOR INSERT TO authenticated
  WITH CHECK (true);

SELECT 'RLS de games corregido correctamente ✓' AS resultado;
