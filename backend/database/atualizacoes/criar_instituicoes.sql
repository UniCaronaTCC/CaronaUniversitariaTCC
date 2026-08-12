USE carona_universitaria;
SET NAMES utf8mb4;

CREATE TABLE IF NOT EXISTS instituicoes (
  id_instituicao INT AUTO_INCREMENT PRIMARY KEY,
  codigo_emec INT NOT NULL UNIQUE,
  nome VARCHAR(255) NOT NULL,
  sigla VARCHAR(50) NULL,
  municipio VARCHAR(100) NOT NULL,
  uf CHAR(2) NOT NULL,
  ativa BOOLEAN NOT NULL DEFAULT TRUE,
  INDEX idx_instituicoes_nome (nome),
  INDEX idx_instituicoes_sigla (sigla)
) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
