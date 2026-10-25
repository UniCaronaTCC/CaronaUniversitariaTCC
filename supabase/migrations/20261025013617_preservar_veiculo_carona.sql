-- Aplicar antes do backend que le veiculo_publicado.
-- Backfill usa o veiculo disponivel hoje; nao reconstrui trocas anteriores.
ALTER TABLE unicarona.caronas ADD COLUMN veiculo_publicado JSONB;

UPDATE unicarona.caronas c
SET veiculo_publicado = jsonb_build_object('modelo', v.modelo, 'cor', v.cor, 'placa', v.placa)
FROM unicarona.veiculos v WHERE v.id_usuario = c.id_usuario;

CREATE FUNCTION unicarona.preservar_veiculo_carona()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY INVOKER SET search_path = '' AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    -- O bloqueio serializa a publicacao com a edicao do veiculo pelo backend.
    -- Nao confia em um snapshot fornecido pelo cliente.
    SELECT jsonb_build_object('modelo', v.modelo, 'cor', v.cor, 'placa', v.placa)
      INTO NEW.veiculo_publicado
      FROM unicarona.veiculos v WHERE v.id_usuario = NEW.id_usuario FOR SHARE;
  ELSIF NEW.veiculo_publicado IS DISTINCT FROM OLD.veiculo_publicado
     OR NEW.id_usuario IS DISTINCT FROM OLD.id_usuario THEN
    RAISE EXCEPTION 'O veiculo e o motorista publicados nao podem ser substituidos'
      USING ERRCODE = '23514';
  END IF;
  RETURN NEW;
END;
$$;

REVOKE ALL ON FUNCTION unicarona.preservar_veiculo_carona() FROM PUBLIC, anon, authenticated;
CREATE TRIGGER preservar_veiculo_publicado
BEFORE INSERT OR UPDATE OF veiculo_publicado, id_usuario ON unicarona.caronas
FOR EACH ROW EXECUTE FUNCTION unicarona.preservar_veiculo_carona();

COMMENT ON COLUMN unicarona.caronas.veiculo_publicado IS
  'Veiculo na publicacao. Legado preenchido com dados disponiveis na migracao; sem veiculo permanece NULL.';
