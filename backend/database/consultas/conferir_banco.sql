USE carona_universitaria;

SHOW TABLES;

DESCRIBE usuarios;
DESCRIBE caronas;
DESCRIBE pontos_embarque;
DESCRIBE solicitacoes;

SELECT COUNT(*) AS total_usuarios FROM usuarios;
SELECT COUNT(*) AS total_caronas FROM caronas;
SELECT COUNT(*) AS total_solicitacoes FROM solicitacoes;
