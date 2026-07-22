USE carona_universitaria;

CREATE TABLE IF NOT EXISTS solicitacoes (
  id_solicitacao INT AUTO_INCREMENT PRIMARY KEY,
  id_carona INT NOT NULL,
  id_passageiro INT NOT NULL,
  local_embarque VARCHAR(255) NOT NULL,
  embarque_latitude DECIMAL(10, 8) NOT NULL,
  embarque_longitude DECIMAL(11, 8) NOT NULL,
  status VARCHAR(30) NOT NULL DEFAULT 'PENDENTE',
  criado_em TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  atualizado_em TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
    ON UPDATE CURRENT_TIMESTAMP,

  CONSTRAINT uq_solicitacao_carona_passageiro
    UNIQUE (id_carona, id_passageiro),

  CONSTRAINT fk_solicitacoes_carona
    FOREIGN KEY (id_carona)
    REFERENCES caronas(id_carona)
    ON UPDATE CASCADE
    ON DELETE RESTRICT,

  CONSTRAINT fk_solicitacoes_passageiro
    FOREIGN KEY (id_passageiro)
    REFERENCES usuarios(id_usuario)
    ON UPDATE CASCADE
    ON DELETE RESTRICT
);
