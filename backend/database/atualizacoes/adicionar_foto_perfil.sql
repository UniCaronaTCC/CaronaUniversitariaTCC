USE carona_universitaria;

ALTER TABLE usuarios
  ADD COLUMN foto_perfil VARCHAR(500) NULL AFTER campus;
