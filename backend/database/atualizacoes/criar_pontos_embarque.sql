USE carona_universitaria;

CREATE TABLE IF NOT EXISTS pontos_embarque (
  id_ponto_embarque INT AUTO_INCREMENT PRIMARY KEY,
  nome VARCHAR(100) NULL,
  endereco VARCHAR(255) NOT NULL,
  latitude DECIMAL(10, 8) NOT NULL,
  longitude DECIMAL(11, 8) NOT NULL,
  ordem INT UNSIGNED NOT NULL DEFAULT 1,
  id_carona INT NOT NULL,

  INDEX idx_pontos_embarque_carona (id_carona),

  CONSTRAINT fk_pontos_embarque_carona
    FOREIGN KEY (id_carona)
    REFERENCES caronas(id_carona)
    ON UPDATE CASCADE
    ON DELETE CASCADE
) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

ALTER TABLE pontos_embarque
  DROP FOREIGN KEY fk_pontos_embarque_carona;

ALTER TABLE pontos_embarque
  ADD CONSTRAINT fk_pontos_embarque_carona
    FOREIGN KEY (id_carona)
    REFERENCES caronas(id_carona)
    ON UPDATE CASCADE
    ON DELETE CASCADE;
