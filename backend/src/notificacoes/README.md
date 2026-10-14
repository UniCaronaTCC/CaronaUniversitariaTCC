# Central de notificacoes

O sino da Home mostra o total de avisos nao lidos. Ao abrir a central, o app
executa `POST /notificacoes/abrir`, que marca os avisos existentes da propria
conta como lidos. Nao apaga o historico nem marca mensagens/solicitacoes como
lidas em outros modulos. Eventos novos permanecem nao lidos.

Se a abertura falhar, a marcacao continua pendente para a proxima tentativa,
refresh ou retomada do app. Depois da confirmacao, atualizacoes usam somente GET.
Atualizacoes automaticas preservam as paginas antigas ja carregadas e recuperam
eventuais intervalos com mais de 50 avisos novos. O refresh manual reinicia a lista.
Atalhos de carona nao oferecem nova solicitacao a passageiros ja vinculados;
as acoes de gerenciamento do motorista continuam disponiveis.

## API autenticada

- `GET /notificacoes/nao-lidas`: contador, sem alterar leitura.
- `GET /notificacoes?antesDe=<id>`: pagina de 50 itens em ordem decrescente.
- `POST /notificacoes/abrir`: leitura automatica e primeira pagina.

O usuario vem exclusivamente do JWT validado. Nao ha rota para criar avisos
arbitrarios pelo cliente. Campos internos de usuario/evento nao saem na API.

## Banco e publicacao

Para outra instalacao do banco, executar depois de criar o schema do app:
`backend/database/postgres/atualizacoes/criar_notificacoes.sql`.
Nao usar `synchronize=true`. Publicar o backend com `NotificacoesModule` antes
de testar a central no app. A mudanca no banco nao publica o backend.

A tabela tem RLS ativo e nenhum acesso direto para `anon`/`authenticated`.
As funcoes usam `SECURITY INVOKER` e `search_path` vazio. O backend usa sua
role de banco; os triggers persistem avisos na mesma transacao dos eventos.

Fontes: mensagens recebidas; solicitacoes/aceites/recusas/cancelamentos/expiracao;
publicacao, edicao, inicio e encerramento de caronas; estados de pagamentos;
avaliacoes; resultado da CNH/verificacao de perfil; criacao e pausa/retomada
de recorrencias. GPS e mudancas locais de interface nao geram avisos.
Mensagens e documentos nao sao copiados para notificacoes.

O registro unico `(id_usuario, chave_evento)` evita avisos repetidos. Atualizar
um status sem altera-lo nao gera outro aviso. O canal privado ja existente
`usuario:<id>` recebe `NOTIFICACAO_NOVA`, com somente o ID do aviso. O app
consulta a API autenticada e tem fallback de 30 segundos em primeiro plano.
Nao ha push do sistema operacional. Avisos antigos anteriores a implantacao
nao sao importados retroativamente.

Cada resultado de CNH usa tambem a data de aceite gravada pelo servico ao concluir
a tentativa. Assim, duas recusas consecutivas geram dois avisos, mas regravar o
mesmo resultado nao duplica notificacoes. Para bancos ja instalados, reaplicar
`criar_notificacoes.sql` atualiza a funcao sem apagar o historico existente.

## Verificacao

- Jest: `npm test -- --runInBand notificacoes`.
- HTTP: `npm run test:e2e -- --runInBand notificacoes`.
- Banco: `backend/test/notificacoes-banco.sql` usa contas/dados sinteticos
  em transacao com rollback e verifica geracao, duplicidade, leitura, RLS e
  separacao entre usuarios. Nao usa registros reais; sequences podem ter gaps.
- Flutter: testes `notificacao_service_test.dart`, `notificacoes_test.dart` e
  `notificacoes_regressoes_test.dart`.

Nao confundir abertura da central com leitura de chat ou confirmacao de
pagamento. Os atalhos buscam os dados atuais nas telas correspondentes.
