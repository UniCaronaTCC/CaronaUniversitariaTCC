USE carona_universitaria;

-- Execute uma única vez nos bancos que já possuem a tabela solicitacoes.
ALTER TABLE solicitacoes
  ADD COLUMN id_ponto_embarque INT NULL AFTER id_passageiro,
  ADD COLUMN tipo_ponto_embarque VARCHAR(30) NOT NULL DEFAULT 'EXISTENTE'
    AFTER id_ponto_embarque,
  ADD INDEX idx_solicitacoes_ponto_embarque (id_ponto_embarque),
  ADD CONSTRAINT fk_solicitacoes_pontos_embarque
    FOREIGN KEY (id_ponto_embarque)
    REFERENCES pontos_embarque(id_ponto_embarque)
    ON UPDATE CASCADE
    ON DELETE SET NULL;

-- Corrige solicitações criadas antes da escolha do ponto de embarque.
UPDATE solicitacoes
SET tipo_ponto_embarque = 'NOVO_SOLICITADO'
WHERE tipo_ponto_embarque = 'EXISTENTE'
  AND id_ponto_embarque IS NULL;
