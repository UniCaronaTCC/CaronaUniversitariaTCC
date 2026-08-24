USE carona_universitaria;

-- Execute uma única vez nos bancos que já possuem a tabela usuarios.
ALTER TABLE usuarios
  ADD COLUMN codigo_redefinicao_senha VARCHAR(255) NULL
    AFTER codigo_verificacao_email_enviado_em,
  ADD COLUMN codigo_redefinicao_senha_expira_em DATETIME NULL
    AFTER codigo_redefinicao_senha,
  ADD COLUMN codigo_redefinicao_senha_enviado_em DATETIME NULL
    AFTER codigo_redefinicao_senha_expira_em;
