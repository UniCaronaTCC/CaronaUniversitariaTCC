---
name: avaliar-seguranca-tcc
description: Avalia aspectos de segurança de um sistema de TCC e gera um relatório Markdown com achados, evidências e recomendações.
---

# Avaliação de segurança do sistema de TCC

## Objetivo

Analisar o código-fonte e as configurações do sistema **[NOME DO SISTEMA]** para identificar riscos de segurança e produzir um relatório em Markdown.

## Escopo da análise

Examine, quando existirem no projeto:

- Autenticação e autorização: login, senhas, sessões, perfis e permissões.
- Validação de entradas: formulários, parâmetros de URL, APIs e uploads.
- Proteção de dados: senhas, dados pessoais, tokens, chaves e variáveis de ambiente.
- Banco de dados: risco de SQL Injection, acesso indevido e credenciais expostas.
- APIs: rotas sem autenticação, validação insuficiente e exposição excessiva de dados.
- Frontend: risco de XSS, armazenamento inseguro de tokens e dados sensíveis.
- Configurações: arquivos `.env`, CORS, logs, modo de produção e dependências vulneráveis.
- Upload de arquivos: extensão, tipo, tamanho, local de armazenamento e acesso aos arquivos enviados.

## Regras

- Faça análise estática do código e das configurações disponíveis.
- Não execute ataques, não altere o sistema e não exponha segredos encontrados.
- Caso uma informação não esteja disponível, registre isso como limitação da análise.
- Classifique cada achado como: Crítica, Alta, Média, Baixa ou Informativa.
- Para cada achado, informe evidência no código, impacto e recomendação prática.
- Não invente vulnerabilidades: relate somente o que possuir evidência.

## Entrega

Crie o arquivo `relatorio-seguranca.md` na raiz do projeto com esta estrutura:

# Relatório de Avaliação de Segurança

## 1. Identificação
- Sistema:
- Data:
- Tipo de análise: análise estática de código e configuração.

## 2. Resumo executivo
Explique brevemente o nível geral de segurança e a quantidade de achados por severidade.

## 3. Escopo e limitações
Liste os diretórios, arquivos e tecnologias analisados. Informe limitações.

## 4. Achados

Para cada achado, use:

### [SEVERIDADE] Título do achado
- **Área:** autenticação, API, banco de dados, frontend etc.
- **Evidência:** arquivo e trecho ou comportamento identificado.
- **Impacto:** consequência possível.
- **Recomendação:** como corrigir.
- **Prioridade:** Crítica, Alta, Média, Baixa ou Informativa.

## 5. Pontos positivos
Liste controles de segurança identificados, se houver.

## 6. Recomendações priorizadas
Apresente as correções em ordem de prioridade.

## 7. Conclusão
Apresente uma conclusão curta e objetiva.