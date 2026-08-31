BEGIN;

ALTER TABLE unicarona.usuarios
  ADD COLUMN auth_id UUID,
  ALTER COLUMN senha DROP NOT NULL,
  ADD CONSTRAINT usuarios_auth_id_key UNIQUE (auth_id),
  ADD CONSTRAINT fk_usuarios_auth
    FOREIGN KEY (auth_id)
    REFERENCES auth.users(id)
    ON DELETE RESTRICT;

CREATE OR REPLACE FUNCTION unicarona.criar_perfil_usuario()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
  IF NEW.email IS NULL THEN
    RETURN NEW;
  END IF;

  UPDATE unicarona.usuarios
  SET auth_id = NEW.id
  WHERE LOWER(email) = LOWER(NEW.email)
    AND auth_id IS NULL;

  IF FOUND THEN
    RETURN NEW;
  END IF;

  INSERT INTO unicarona.usuarios (auth_id, nome, email)
  VALUES (
    NEW.id,
    COALESCE(
      NULLIF(BTRIM(NEW.raw_user_meta_data ->> 'nome'), ''),
      SPLIT_PART(NEW.email, '@', 1)
    ),
    LOWER(NEW.email)
  );

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS criar_perfil_apos_cadastro ON auth.users;

CREATE TRIGGER criar_perfil_apos_cadastro
  AFTER INSERT ON auth.users
  FOR EACH ROW
  EXECUTE FUNCTION unicarona.criar_perfil_usuario();

COMMIT;
