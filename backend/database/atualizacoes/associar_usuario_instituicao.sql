USE carona_universitaria;

ALTER TABLE usuarios
  MODIFY COLUMN instituicao VARCHAR(255) NULL,
  ADD COLUMN id_instituicao INT NULL AFTER email,
  ADD INDEX idx_usuarios_instituicao (id_instituicao),
  ADD CONSTRAINT fk_usuarios_instituicoes
    FOREIGN KEY (id_instituicao)
    REFERENCES instituicoes(id_instituicao)
    ON UPDATE CASCADE
    ON DELETE SET NULL;
