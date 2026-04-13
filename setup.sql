-- ============================================================
-- PRODE MUNDIAL 2026 - Setup de Base de Datos Supabase
-- Ejecutar en: Supabase Dashboard → SQL Editor
-- ============================================================

-- ============================================================
-- TABLAS
-- ============================================================

CREATE TABLE IF NOT EXISTS profiles (
  id uuid PRIMARY KEY REFERENCES auth.users ON DELETE CASCADE,
  full_name text NOT NULL DEFAULT '',
  email text,
  created_at timestamptz DEFAULT now() NOT NULL
);

CREATE TABLE IF NOT EXISTS games (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL,
  description text DEFAULT '',
  invite_code text UNIQUE DEFAULT upper(substr(md5(random()::text || clock_timestamp()::text), 1, 6)),
  created_by uuid REFERENCES profiles(id) ON DELETE SET NULL,
  active boolean DEFAULT true NOT NULL,
  created_at timestamptz DEFAULT now() NOT NULL
);

CREATE TABLE IF NOT EXISTS game_members (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  game_id uuid REFERENCES games(id) ON DELETE CASCADE NOT NULL,
  user_id uuid REFERENCES profiles(id) ON DELETE CASCADE NOT NULL,
  role text DEFAULT 'player' NOT NULL CHECK (role IN ('admin','player')),
  active boolean DEFAULT true NOT NULL,
  joined_at timestamptz DEFAULT now() NOT NULL,
  UNIQUE(game_id, user_id)
);

CREATE TABLE IF NOT EXISTS matches (
  id text PRIMARY KEY,
  num integer NOT NULL,
  phase text NOT NULL CHECK (phase IN ('groups','r16','qf','sf','third','final')),
  group_id text,
  matchday integer,
  team1 text NOT NULL,
  team2 text NOT NULL,
  label1 text,
  label2 text,
  scheduled_date timestamptz NOT NULL,
  venue text DEFAULT ''
);

CREATE TABLE IF NOT EXISTS game_results (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  game_id uuid REFERENCES games(id) ON DELETE CASCADE NOT NULL,
  match_id text REFERENCES matches(id) ON DELETE CASCADE NOT NULL,
  team1_name text,
  team2_name text,
  result1 integer,
  result2 integer,
  status text DEFAULT 'upcoming' NOT NULL CHECK (status IN ('upcoming','finished')),
  updated_at timestamptz DEFAULT now() NOT NULL,
  UNIQUE(game_id, match_id)
);

CREATE TABLE IF NOT EXISTS predictions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  game_id uuid REFERENCES games(id) ON DELETE CASCADE NOT NULL,
  user_id uuid REFERENCES profiles(id) ON DELETE CASCADE NOT NULL,
  match_id text REFERENCES matches(id) ON DELETE CASCADE NOT NULL,
  pred1 integer NOT NULL CHECK (pred1 >= 0 AND pred1 <= 30),
  pred2 integer NOT NULL CHECK (pred2 >= 0 AND pred2 <= 30),
  saved_at timestamptz DEFAULT now() NOT NULL,
  UNIQUE(game_id, user_id, match_id)
);

-- ============================================================
-- ÍNDICES
-- ============================================================
CREATE INDEX IF NOT EXISTS idx_game_members_user ON game_members(user_id);
CREATE INDEX IF NOT EXISTS idx_game_members_game ON game_members(game_id);
CREATE INDEX IF NOT EXISTS idx_game_results_game ON game_results(game_id);
CREATE INDEX IF NOT EXISTS idx_predictions_game_user ON predictions(game_id, user_id);
CREATE INDEX IF NOT EXISTS idx_predictions_match ON predictions(match_id);
CREATE INDEX IF NOT EXISTS idx_matches_phase ON matches(phase);

-- ============================================================
-- FUNCIONES AUXILIARES
-- ============================================================

-- Verifica si el usuario actual es admin de un juego
CREATE OR REPLACE FUNCTION is_game_admin(p_game_id uuid)
RETURNS boolean AS $$
  SELECT EXISTS (
    SELECT 1 FROM game_members
    WHERE game_id = p_game_id
      AND user_id = auth.uid()
      AND role = 'admin'
      AND active = true
  );
$$ LANGUAGE sql SECURITY DEFINER STABLE;

-- Verifica si el usuario actual es miembro de un juego
CREATE OR REPLACE FUNCTION is_game_member(p_game_id uuid)
RETURNS boolean AS $$
  SELECT EXISTS (
    SELECT 1 FROM game_members
    WHERE game_id = p_game_id
      AND user_id = auth.uid()
      AND active = true
  );
$$ LANGUAGE sql SECURITY DEFINER STABLE;

-- ============================================================
-- ROW LEVEL SECURITY (RLS)
-- ============================================================
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE games ENABLE ROW LEVEL SECURITY;
ALTER TABLE game_members ENABLE ROW LEVEL SECURITY;
ALTER TABLE matches ENABLE ROW LEVEL SECURITY;
ALTER TABLE game_results ENABLE ROW LEVEL SECURITY;
ALTER TABLE predictions ENABLE ROW LEVEL SECURITY;

-- PROFILES
DROP POLICY IF EXISTS "profiles_select" ON profiles;
DROP POLICY IF EXISTS "profiles_insert" ON profiles;
DROP POLICY IF EXISTS "profiles_update" ON profiles;
CREATE POLICY "profiles_select" ON profiles FOR SELECT TO authenticated USING (true);
CREATE POLICY "profiles_insert" ON profiles FOR INSERT TO authenticated WITH CHECK (id = auth.uid());
CREATE POLICY "profiles_update" ON profiles FOR UPDATE TO authenticated USING (id = auth.uid()) WITH CHECK (id = auth.uid());

-- GAMES
DROP POLICY IF EXISTS "games_select" ON games;
DROP POLICY IF EXISTS "games_insert" ON games;
DROP POLICY IF EXISTS "games_update" ON games;
CREATE POLICY "games_select" ON games FOR SELECT TO authenticated USING (is_game_member(id));
CREATE POLICY "games_insert" ON games FOR INSERT TO authenticated WITH CHECK (created_by = auth.uid());
CREATE POLICY "games_update" ON games FOR UPDATE TO authenticated USING (is_game_admin(id));

-- GAME_MEMBERS
DROP POLICY IF EXISTS "gm_select" ON game_members;
DROP POLICY IF EXISTS "gm_insert" ON game_members;
DROP POLICY IF EXISTS "gm_update" ON game_members;
DROP POLICY IF EXISTS "gm_delete" ON game_members;
CREATE POLICY "gm_select" ON game_members FOR SELECT TO authenticated USING (is_game_member(game_id));
CREATE POLICY "gm_insert" ON game_members FOR INSERT TO authenticated WITH CHECK (user_id = auth.uid() OR is_game_admin(game_id));
CREATE POLICY "gm_update" ON game_members FOR UPDATE TO authenticated USING (is_game_admin(game_id));
CREATE POLICY "gm_delete" ON game_members FOR DELETE TO authenticated USING (is_game_admin(game_id) OR user_id = auth.uid());

-- MATCHES (lectura pública para autenticados)
DROP POLICY IF EXISTS "matches_select" ON matches;
CREATE POLICY "matches_select" ON matches FOR SELECT TO authenticated USING (true);

-- GAME_RESULTS
DROP POLICY IF EXISTS "gr_select" ON game_results;
DROP POLICY IF EXISTS "gr_insert" ON game_results;
DROP POLICY IF EXISTS "gr_update" ON game_results;
DROP POLICY IF EXISTS "gr_delete" ON game_results;
CREATE POLICY "gr_select" ON game_results FOR SELECT TO authenticated USING (is_game_member(game_id));
CREATE POLICY "gr_insert" ON game_results FOR INSERT TO authenticated WITH CHECK (is_game_admin(game_id));
CREATE POLICY "gr_update" ON game_results FOR UPDATE TO authenticated USING (is_game_admin(game_id));
CREATE POLICY "gr_delete" ON game_results FOR DELETE TO authenticated USING (is_game_admin(game_id));

-- PREDICTIONS
DROP POLICY IF EXISTS "pred_select" ON predictions;
DROP POLICY IF EXISTS "pred_insert" ON predictions;
DROP POLICY IF EXISTS "pred_update" ON predictions;
CREATE POLICY "pred_select" ON predictions FOR SELECT TO authenticated USING (is_game_member(game_id));
CREATE POLICY "pred_insert" ON predictions FOR INSERT TO authenticated
  WITH CHECK (user_id = auth.uid() AND is_game_member(game_id));
CREATE POLICY "pred_update" ON predictions FOR UPDATE TO authenticated
  USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());

-- ============================================================
-- TRIGGER: Crear perfil automáticamente al registrarse
-- ============================================================
CREATE OR REPLACE FUNCTION handle_new_user()
RETURNS trigger AS $$
BEGIN
  INSERT INTO profiles (id, email, full_name)
  VALUES (
    new.id,
    new.email,
    COALESCE(new.raw_user_meta_data->>'full_name', split_part(new.email, '@', 1))
  )
  ON CONFLICT (id) DO UPDATE
    SET full_name = COALESCE(EXCLUDED.full_name, profiles.full_name),
        email = COALESCE(EXCLUDED.email, profiles.email);
  RETURN new;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION handle_new_user();

-- ============================================================
-- DATOS INICIALES: Todos los partidos del Mundial 2026
-- ============================================================
INSERT INTO matches (id,num,phase,group_id,matchday,team1,team2,label1,label2,scheduled_date,venue) VALUES
('M001',1,'groups','A',1,'México','Corea del Sur',NULL,NULL,'2026-06-11T18:00:00+00',''),
('M002',2,'groups','A',1,'Sudáfrica','República Checa',NULL,NULL,'2026-06-11T21:00:00+00',''),
('M003',3,'groups','A',2,'México','Sudáfrica',NULL,NULL,'2026-06-20T18:00:00+00',''),
('M004',4,'groups','A',2,'Corea del Sur','República Checa',NULL,NULL,'2026-06-20T21:00:00+00',''),
('M005',5,'groups','A',3,'México','República Checa',NULL,NULL,'2026-06-27T21:00:00+00',''),
('M006',6,'groups','A',3,'Corea del Sur','Sudáfrica',NULL,NULL,'2026-06-27T21:00:00+00',''),
('M007',7,'groups','B',1,'Canadá','Bosnia y Herzegovina',NULL,NULL,'2026-06-12T18:00:00+00',''),
('M008',8,'groups','B',1,'Qatar','Suiza',NULL,NULL,'2026-06-12T21:00:00+00',''),
('M009',9,'groups','B',2,'Canadá','Qatar',NULL,NULL,'2026-06-21T18:00:00+00',''),
('M010',10,'groups','B',2,'Bosnia y Herzegovina','Suiza',NULL,NULL,'2026-06-21T21:00:00+00',''),
('M011',11,'groups','B',3,'Canadá','Suiza',NULL,NULL,'2026-06-28T21:00:00+00',''),
('M012',12,'groups','B',3,'Bosnia y Herzegovina','Qatar',NULL,NULL,'2026-06-28T21:00:00+00',''),
('M013',13,'groups','C',1,'Brasil','Marruecos',NULL,NULL,'2026-06-13T18:00:00+00',''),
('M014',14,'groups','C',1,'Haití','Escocia',NULL,NULL,'2026-06-13T21:00:00+00',''),
('M015',15,'groups','C',2,'Brasil','Haití',NULL,NULL,'2026-06-23T18:00:00+00',''),
('M016',16,'groups','C',2,'Marruecos','Escocia',NULL,NULL,'2026-06-23T21:00:00+00',''),
('M017',17,'groups','C',3,'Brasil','Escocia',NULL,NULL,'2026-06-30T21:00:00+00',''),
('M018',18,'groups','C',3,'Marruecos','Haití',NULL,NULL,'2026-06-30T21:00:00+00',''),
('M019',19,'groups','D',1,'Estados Unidos','Paraguay',NULL,NULL,'2026-06-13T18:00:00+00',''),
('M020',20,'groups','D',1,'Australia','Turquía',NULL,NULL,'2026-06-13T21:00:00+00',''),
('M021',21,'groups','D',2,'Estados Unidos','Australia',NULL,NULL,'2026-06-21T18:00:00+00',''),
('M022',22,'groups','D',2,'Paraguay','Turquía',NULL,NULL,'2026-06-21T21:00:00+00',''),
('M023',23,'groups','D',3,'Estados Unidos','Turquía',NULL,NULL,'2026-06-29T21:00:00+00',''),
('M024',24,'groups','D',3,'Paraguay','Australia',NULL,NULL,'2026-06-29T21:00:00+00',''),
('M025',25,'groups','E',1,'Alemania','Curazao',NULL,NULL,'2026-06-14T18:00:00+00',''),
('M026',26,'groups','E',1,'Costa de Marfil','Ecuador',NULL,NULL,'2026-06-14T21:00:00+00',''),
('M027',27,'groups','E',2,'Alemania','Costa de Marfil',NULL,NULL,'2026-06-22T18:00:00+00',''),
('M028',28,'groups','E',2,'Curazao','Ecuador',NULL,NULL,'2026-06-22T21:00:00+00',''),
('M029',29,'groups','E',3,'Alemania','Ecuador',NULL,NULL,'2026-06-29T21:00:00+00',''),
('M030',30,'groups','E',3,'Curazao','Costa de Marfil',NULL,NULL,'2026-06-29T21:00:00+00',''),
('M031',31,'groups','F',1,'Países Bajos','Japón',NULL,NULL,'2026-06-15T18:00:00+00',''),
('M032',32,'groups','F',1,'Suecia','Túnez',NULL,NULL,'2026-06-15T21:00:00+00',''),
('M033',33,'groups','F',2,'Países Bajos','Suecia',NULL,NULL,'2026-06-22T18:00:00+00',''),
('M034',34,'groups','F',2,'Japón','Túnez',NULL,NULL,'2026-06-22T21:00:00+00',''),
('M035',35,'groups','F',3,'Países Bajos','Túnez',NULL,NULL,'2026-06-30T21:00:00+00',''),
('M036',36,'groups','F',3,'Japón','Suecia',NULL,NULL,'2026-06-30T21:00:00+00',''),
('M037',37,'groups','G',1,'Bélgica','Irán',NULL,NULL,'2026-06-16T18:00:00+00',''),
('M038',38,'groups','G',1,'Egipto','Nueva Zelanda',NULL,NULL,'2026-06-16T21:00:00+00',''),
('M039',39,'groups','G',2,'Bélgica','Egipto',NULL,NULL,'2026-06-23T18:00:00+00',''),
('M040',40,'groups','G',2,'Irán','Nueva Zelanda',NULL,NULL,'2026-06-23T21:00:00+00',''),
('M041',41,'groups','G',3,'Bélgica','Nueva Zelanda',NULL,NULL,'2026-07-01T21:00:00+00',''),
('M042',42,'groups','G',3,'Irán','Egipto',NULL,NULL,'2026-07-01T21:00:00+00',''),
('M043',43,'groups','H',1,'España','Cabo Verde',NULL,NULL,'2026-06-16T18:00:00+00',''),
('M044',44,'groups','H',1,'Arabia Saudita','Uruguay',NULL,NULL,'2026-06-16T21:00:00+00',''),
('M045',45,'groups','H',2,'España','Arabia Saudita',NULL,NULL,'2026-06-24T18:00:00+00',''),
('M046',46,'groups','H',2,'Cabo Verde','Uruguay',NULL,NULL,'2026-06-24T21:00:00+00',''),
('M047',47,'groups','H',3,'España','Uruguay',NULL,NULL,'2026-07-01T21:00:00+00',''),
('M048',48,'groups','H',3,'Cabo Verde','Arabia Saudita',NULL,NULL,'2026-07-01T21:00:00+00',''),
('M049',49,'groups','I',1,'Francia','Senegal',NULL,NULL,'2026-06-17T18:00:00+00',''),
('M050',50,'groups','I',1,'Noruega','Irak',NULL,NULL,'2026-06-17T21:00:00+00',''),
('M051',51,'groups','I',2,'Francia','Noruega',NULL,NULL,'2026-06-25T18:00:00+00',''),
('M052',52,'groups','I',2,'Senegal','Irak',NULL,NULL,'2026-06-25T21:00:00+00',''),
('M053',53,'groups','I',3,'Francia','Irak',NULL,NULL,'2026-07-02T21:00:00+00',''),
('M054',54,'groups','I',3,'Senegal','Noruega',NULL,NULL,'2026-07-02T21:00:00+00',''),
('M055',55,'groups','J',1,'Argentina','Argelia',NULL,NULL,'2026-06-18T18:00:00+00',''),
('M056',56,'groups','J',1,'Austria','Jordania',NULL,NULL,'2026-06-18T21:00:00+00',''),
('M057',57,'groups','J',2,'Argentina','Austria',NULL,NULL,'2026-06-25T18:00:00+00',''),
('M058',58,'groups','J',2,'Argelia','Jordania',NULL,NULL,'2026-06-25T21:00:00+00',''),
('M059',59,'groups','J',3,'Argentina','Jordania',NULL,NULL,'2026-07-02T21:00:00+00',''),
('M060',60,'groups','J',3,'Argelia','Austria',NULL,NULL,'2026-07-02T21:00:00+00',''),
('M061',61,'groups','K',1,'Portugal','Colombia',NULL,NULL,'2026-06-19T18:00:00+00',''),
('M062',62,'groups','K',1,'Uzbekistán','RD Congo',NULL,NULL,'2026-06-19T21:00:00+00',''),
('M063',63,'groups','K',2,'Portugal','Uzbekistán',NULL,NULL,'2026-06-26T18:00:00+00',''),
('M064',64,'groups','K',2,'Colombia','RD Congo',NULL,NULL,'2026-06-26T21:00:00+00',''),
('M065',65,'groups','K',3,'Portugal','RD Congo',NULL,NULL,'2026-07-02T21:00:00+00',''),
('M066',66,'groups','K',3,'Colombia','Uzbekistán',NULL,NULL,'2026-07-02T21:00:00+00',''),
('M067',67,'groups','L',1,'Inglaterra','Croacia',NULL,NULL,'2026-06-20T18:00:00+00',''),
('M068',68,'groups','L',1,'Panamá','Ghana',NULL,NULL,'2026-06-20T21:00:00+00',''),
('M069',69,'groups','L',2,'Inglaterra','Panamá',NULL,NULL,'2026-06-26T18:00:00+00',''),
('M070',70,'groups','L',2,'Croacia','Ghana',NULL,NULL,'2026-06-26T21:00:00+00',''),
('M071',71,'groups','L',3,'Inglaterra','Ghana',NULL,NULL,'2026-07-02T21:00:00+00',''),
('M072',72,'groups','L',3,'Croacia','Panamá',NULL,NULL,'2026-07-02T21:00:00+00',''),
('M073',73,'r16',NULL,NULL,'TBD','TBD','1A','2C','2026-07-04T21:00:00+00',''),
('M074',74,'r16',NULL,NULL,'TBD','TBD','1B','2D','2026-07-04T21:00:00+00',''),
('M075',75,'r16',NULL,NULL,'TBD','TBD','1E','2G','2026-07-05T21:00:00+00',''),
('M076',76,'r16',NULL,NULL,'TBD','TBD','1F','2H','2026-07-05T21:00:00+00',''),
('M077',77,'r16',NULL,NULL,'TBD','TBD','1I','2K','2026-07-06T21:00:00+00',''),
('M078',78,'r16',NULL,NULL,'TBD','TBD','1J','2L','2026-07-06T21:00:00+00',''),
('M079',79,'r16',NULL,NULL,'TBD','TBD','1C','2A','2026-07-07T21:00:00+00',''),
('M080',80,'r16',NULL,NULL,'TBD','TBD','1D','2B','2026-07-07T21:00:00+00',''),
('M081',81,'r16',NULL,NULL,'TBD','TBD','1G','2E','2026-07-08T21:00:00+00',''),
('M082',82,'r16',NULL,NULL,'TBD','TBD','1H','2F','2026-07-08T21:00:00+00',''),
('M083',83,'r16',NULL,NULL,'TBD','TBD','1K','2I','2026-07-09T21:00:00+00',''),
('M084',84,'r16',NULL,NULL,'TBD','TBD','1L','2J','2026-07-09T21:00:00+00',''),
('M085',85,'r16',NULL,NULL,'TBD','TBD','M3-1','M3-2','2026-07-10T21:00:00+00',''),
('M086',86,'r16',NULL,NULL,'TBD','TBD','M3-3','M3-4','2026-07-10T21:00:00+00',''),
('M087',87,'r16',NULL,NULL,'TBD','TBD','M3-5','M3-6','2026-07-11T21:00:00+00',''),
('M088',88,'r16',NULL,NULL,'TBD','TBD','M3-7','M3-8','2026-07-11T21:00:00+00',''),
('M089',89,'qf',NULL,NULL,'TBD','TBD','Ganador R16-1','Ganador R16-2','2026-07-12T21:00:00+00',''),
('M090',90,'qf',NULL,NULL,'TBD','TBD','Ganador R16-3','Ganador R16-4','2026-07-12T21:00:00+00',''),
('M091',91,'qf',NULL,NULL,'TBD','TBD','Ganador R16-5','Ganador R16-6','2026-07-13T21:00:00+00',''),
('M092',92,'qf',NULL,NULL,'TBD','TBD','Ganador R16-7','Ganador R16-8','2026-07-13T21:00:00+00',''),
('M093',93,'qf',NULL,NULL,'TBD','TBD','Ganador R16-9','Ganador R16-10','2026-07-14T21:00:00+00',''),
('M094',94,'qf',NULL,NULL,'TBD','TBD','Ganador R16-11','Ganador R16-12','2026-07-14T21:00:00+00',''),
('M095',95,'qf',NULL,NULL,'TBD','TBD','Ganador R16-13','Ganador R16-14','2026-07-15T21:00:00+00',''),
('M096',96,'qf',NULL,NULL,'TBD','TBD','Ganador R16-15','Ganador R16-16','2026-07-15T21:00:00+00',''),
('M097',97,'sf',NULL,NULL,'TBD','TBD','Ganador QF-1','Ganador QF-2','2026-07-16T21:00:00+00',''),
('M098',98,'sf',NULL,NULL,'TBD','TBD','Ganador QF-3','Ganador QF-4','2026-07-16T21:00:00+00',''),
('M099',99,'sf',NULL,NULL,'TBD','TBD','Ganador QF-5','Ganador QF-6','2026-07-17T21:00:00+00',''),
('M100',100,'sf',NULL,NULL,'TBD','TBD','Ganador QF-7','Ganador QF-8','2026-07-17T21:00:00+00',''),
('M101',101,'third',NULL,NULL,'TBD','TBD','Perdedor SF1','Perdedor SF2','2026-07-19T18:00:00+00',''),
('M102',102,'final',NULL,NULL,'TBD','TBD','Ganador SF1','Ganador SF2','2026-07-19T21:00:00+00','')
ON CONFLICT (id) DO NOTHING;
-- ¡Setup completado! Ya puedes usar la aplicación.
