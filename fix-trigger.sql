-- ============================================================
-- FIX: Trigger handle_new_user más robusto
-- Ejecuta esto en Supabase → SQL Editor
-- ============================================================

-- Versión corregida: con manejo de excepciones
-- Si algo falla en el trigger NO bloquea el registro del usuario
CREATE OR REPLACE FUNCTION handle_new_user()
RETURNS trigger AS $$
BEGIN
  INSERT INTO profiles (id, email, full_name)
  VALUES (
    new.id,
    COALESCE(new.email, ''),
    COALESCE(
      new.raw_user_meta_data->>'full_name',
      split_part(COALESCE(new.email, 'usuario@app.com'), '@', 1)
    )
  )
  ON CONFLICT (id) DO NOTHING;

  RETURN new;
EXCEPTION
  WHEN OTHERS THEN
    -- Nunca fallar el signup aunque el trigger tenga error
    RAISE WARNING 'handle_new_user error: %', SQLERRM;
    RETURN new;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Recrear el trigger
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION handle_new_user();

-- ============================================================
-- También asegúrate de que la tabla profiles no requiera
-- full_name como NOT NULL (puede fallar al registrar)
-- ============================================================
ALTER TABLE profiles ALTER COLUMN full_name SET DEFAULT '';
ALTER TABLE profiles ALTER COLUMN full_name DROP NOT NULL;

SELECT 'Trigger corregido correctamente ✓' AS resultado;
