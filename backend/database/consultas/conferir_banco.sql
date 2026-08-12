USE carona_universitaria;
SET NAMES utf8mb4;

SHOW TABLES;

SELECT COUNT(*) AS total_instituicoes
FROM instituicoes;

SELECT codigo_emec, nome, sigla, municipio, uf
FROM instituicoes
WHERE codigo_emec = 4522;
