BEGIN;

CREATE OR REPLACE FUNCTION unicarona.normalizar_nome_usuario(nome TEXT)
RETURNS TEXT
LANGUAGE sql
IMMUTABLE
STRICT
SET search_path = ''
AS $$
  SELECT UPPER(LEFT(nome_limpo, 1)) || SUBSTRING(nome_limpo FROM 2)
  FROM (
    SELECT REGEXP_REPLACE(nome, '^[[:space:]]+|[[:space:]]+$', '', 'g') AS nome_limpo
  ) nomes;
$$;

CREATE OR REPLACE FUNCTION unicarona.normalizar_nome_antes_gravar()
RETURNS TRIGGER
LANGUAGE plpgsql
SET search_path = ''
AS $$
BEGIN
  NEW.nome := unicarona.normalizar_nome_usuario(NEW.nome);
  RETURN NEW;
END;
$$;

REVOKE ALL ON FUNCTION unicarona.normalizar_nome_antes_gravar() FROM PUBLIC;

DROP TRIGGER IF EXISTS normalizar_nome_usuario ON unicarona.usuarios;
CREATE TRIGGER normalizar_nome_usuario
  BEFORE INSERT OR UPDATE OF nome ON unicarona.usuarios
  FOR EACH ROW
  EXECUTE FUNCTION unicarona.normalizar_nome_antes_gravar();

UPDATE unicarona.usuarios
SET nome = unicarona.normalizar_nome_usuario(nome)
WHERE nome IS DISTINCT FROM unicarona.normalizar_nome_usuario(nome);

COMMIT;
