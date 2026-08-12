CREATE DATABASE IF NOT EXISTS carona_universitaria
  CHARACTER SET utf8mb4
  COLLATE utf8mb4_unicode_ci;

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

CREATE TABLE IF NOT EXISTS instituicoes_campi (
  id_campus INT AUTO_INCREMENT PRIMARY KEY,
  id_instituicao INT NOT NULL,
  nome VARCHAR(150) NOT NULL,
  municipio VARCHAR(100) NOT NULL,
  uf CHAR(2) NOT NULL,
  latitude DECIMAL(10, 8) NULL,
  longitude DECIMAL(11, 8) NULL,
  ativo BOOLEAN NOT NULL DEFAULT TRUE,

  UNIQUE KEY uq_campus_instituicao_municipio (
    id_instituicao,
    nome,
    municipio,
    uf
  ),

  CONSTRAINT fk_campi_instituicoes
    FOREIGN KEY (id_instituicao)
    REFERENCES instituicoes(id_instituicao)
    ON UPDATE CASCADE
    ON DELETE CASCADE
) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS usuarios (
  id_usuario INT AUTO_INCREMENT PRIMARY KEY,
  nome VARCHAR(100) NOT NULL,
  email VARCHAR(100) NOT NULL UNIQUE,
  id_instituicao INT NULL,
  instituicao VARCHAR(255) NULL,
  campus VARCHAR(150) NULL,
  tipo_perfil VARCHAR(20) NOT NULL DEFAULT 'PASSAGEIRO',
  tipo_perfil_solicitado VARCHAR(20) NULL,
  status_verificacao VARCHAR(20) NOT NULL DEFAULT 'NAO_ENVIADO',
  documento_verificacao VARCHAR(255) NULL,
  senha VARCHAR(255) NOT NULL,
  criado_em TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

  INDEX idx_usuarios_instituicao (id_instituicao),

  CONSTRAINT fk_usuarios_instituicoes
    FOREIGN KEY (id_instituicao)
    REFERENCES instituicoes(id_instituicao)
    ON UPDATE CASCADE
    ON DELETE SET NULL
) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS caronas (
  id_carona INT AUTO_INCREMENT PRIMARY KEY,
  origem VARCHAR(255) NOT NULL,
  origem_cidade VARCHAR(100) NULL,
  origem_latitude DECIMAL(10, 8) NULL,
  origem_longitude DECIMAL(11, 8) NULL,
  destino VARCHAR(255) NOT NULL,
  destino_cidade VARCHAR(100) NULL,
  destino_latitude DECIMAL(10, 8) NULL,
  destino_longitude DECIMAL(11, 8) NULL,
  data_inicio DATE NOT NULL,
  data_fim DATE NULL,
  horario TIME NOT NULL,
  vagas INT UNSIGNED NOT NULL,
  valor DECIMAL(10, 2) NOT NULL,
  recorrente BOOLEAN NOT NULL DEFAULT FALSE,
  dias_semana JSON NULL,
  observacoes TEXT NULL,
  status VARCHAR(30) NOT NULL DEFAULT 'ATIVA',
  id_usuario INT NOT NULL,
  criado_em TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

  CONSTRAINT fk_caronas_usuarios
    FOREIGN KEY (id_usuario)
    REFERENCES usuarios(id_usuario)
    ON UPDATE CASCADE
    ON DELETE RESTRICT
) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

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

  CONSTRAINT fk_solicitacoes_caronas
    FOREIGN KEY (id_carona)
    REFERENCES caronas(id_carona)
    ON DELETE RESTRICT,

  CONSTRAINT fk_solicitacoes_usuarios
    FOREIGN KEY (id_passageiro)
    REFERENCES usuarios(id_usuario)
    ON DELETE RESTRICT
) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS veiculos (
  id_veiculo INT AUTO_INCREMENT PRIMARY KEY,
  modelo VARCHAR(100) NOT NULL,
  cor VARCHAR(50) NOT NULL,
  placa VARCHAR(10) NOT NULL UNIQUE,
  id_usuario INT NOT NULL UNIQUE,
  criado_em TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

  CONSTRAINT fk_veiculos_usuarios
    FOREIGN KEY (id_usuario)
    REFERENCES usuarios(id_usuario)
    ON UPDATE CASCADE
    ON DELETE CASCADE
) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS avaliacoes (
  id_avaliacao INT AUTO_INCREMENT PRIMARY KEY,
  id_solicitacao INT NOT NULL,
  id_avaliador INT NOT NULL,
  id_avaliado INT NOT NULL,
  nota TINYINT UNSIGNED NOT NULL,
  comentario VARCHAR(500) NULL,
  criado_em TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

  CONSTRAINT uq_avaliacao_solicitacao_avaliador
    UNIQUE (id_solicitacao, id_avaliador),

  INDEX idx_avaliacoes_avaliado (id_avaliado),

  CONSTRAINT chk_avaliacoes_nota
    CHECK (nota BETWEEN 1 AND 5),

  CONSTRAINT fk_avaliacoes_solicitacao
    FOREIGN KEY (id_solicitacao)
    REFERENCES solicitacoes(id_solicitacao)
    ON DELETE RESTRICT,

  CONSTRAINT fk_avaliacoes_avaliador
    FOREIGN KEY (id_avaliador)
    REFERENCES usuarios(id_usuario)
    ON DELETE RESTRICT,

  CONSTRAINT fk_avaliacoes_avaliado
    FOREIGN KEY (id_avaliado)
    REFERENCES usuarios(id_usuario)
    ON DELETE RESTRICT
) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
