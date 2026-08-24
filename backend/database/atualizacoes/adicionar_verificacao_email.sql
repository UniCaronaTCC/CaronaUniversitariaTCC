USE carona_universitaria;

-- Execute uma única vez nos bancos que já possuem a tabela usuarios.
ALTER TABLE usuarios
  ADD COLUMN email_verificado BOOLEAN NOT NULL DEFAULT FALSE AFTER email,
  ADD COLUMN codigo_verificacao_email VARCHAR(255) NULL
    AFTER email_verificado,
  ADD COLUMN codigo_verificacao_email_expira_em DATETIME NULL
    AFTER codigo_verificacao_email,
  ADD COLUMN codigo_verificacao_email_enviado_em DATETIME NULL
    AFTER codigo_verificacao_email_expira_em;
