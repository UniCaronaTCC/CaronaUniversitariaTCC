# Reputacao nos cards - 08/11/2026

Base local: `633f8cf`, branch `desenvolvimento`. Implementacao em duas etapas,
sem commit, push, deploy, instalacao no celular ou mudanca no schema do banco.

## Etapa 1 - Backend

- Novo modulo de consulta `ReputacoesModule`, sem depender de CaronasModule ou
  AvaliacoesModule. Isso evita a dependencia circular identificada na analise.
- Consulta parametrizada `AVG(nota)` e `COUNT(*)`, agrupada por `id_avaliado`,
  restrita aos IDs das pessoas efetivamente retornadas pela listagem.
- IDs repetidos sao deduplicados. Lista vazia nao consulta o banco.
- Reputacao geral da pessoa, igual a regra atual do perfil: inclui avaliacoes
  recebidas como motorista e passageiro; nao separa notas por papel.
- `usuario.reputacao` em GET de caronas, minhas caronas e detalhes.
- `passageiro.reputacao` em recebidas e recebidas por carona;
  `motorista.reputacao` em enviadas.
- Contrato: `{media: numero, total: inteiro}`. Ausencia confirmada de notas:
  `{media: 0, total: 0}`. Falha de consulta: `null`, sem impedir a listagem.
- Nenhuma consulta adicional de reputacao em POST/PATCH de negocio. A resposta
  dessas operacoes pode trazer `reputacao: null`; a proxima leitura obtem o resumo.
- Nenhuma mudanca em aceite, vagas, pagamentos, CNH ou regras de avaliacao.

Verificacoes da primeira etapa: 59 testes direcionados aprovados (6 suites),
799 testes na regressao completa do backend (53 suites), compilacao Nest aprovada
e ESLint sem `--fix` aprovado nos 12 arquivos de backend desta funcionalidade.

## Etapa 2 - Flutter

- Modelo imutavel `Reputacao` e indicador visual compartilhado.
- Novos campos opcionais em Carona, SolicitacaoRecebida e SolicitacaoEnviada.
- O indicador mostra estrela, media com uma casa decimal e quantidade. Sem notas,
  mostra `Perfil ainda nao avaliado`. Resumo ausente/invalido fica oculto, nao
  e exibido como nota zero nem impede o restante do card.
- Exibicao em Home, busca, publicadas, historico, recebidas, enviadas e detalhes.
- A copia de Carona ao atualizar pontos preserva a reputacao.
- Nenhum service HTTP, contador, cache de sessao ou politica de carregamento do
  app foi alterado. As informacoes acompanham as requisicoes existentes.
- A reputacao e atualizada quando a listagem e consultada novamente; nao foi
  acrescentado polling ou atualizacao instantanea de notas entre aparelhos.

Verificacoes: 140 casos novos funcionais aprovados, mais 3 capturas visuais.
Regressao completa Flutter: 2.165 testes aprovados. Analise estatica completa:
nenhum problema. Capturas de widgets com dados ficticios, tema AppTheme/VisualBuscaEu,
fontes Inter e MaterialIcons carregadas e viewport logico 360 x 800.
Nao sao capturas de um aparelho fisico.

## Cenarios direcionados

| ID | Camada e preparacao | Acao / esperado | Observado | Estado |
| --- | --- | --- | --- | --- |
| REP-01 | Unidade backend, IDs vazios/invalidos | Nao abrir consulta | Nenhuma consulta | PASSOU |
| REP-02 | Unidade backend, usuarios repetidos | Deduplicar e agrupar sem N+1 | Uma consulta; media/total associados por ID | PASSOU |
| REP-03 | Unidade backend, 500 cards e 20 usuarios | Quantidade de consultas independente dos cards | Uma consulta | PASSOU |
| REP-04 | Unidade backend, zero notas / falha | Distinguir nao avaliado de indisponivel | Zero/zero apenas quando consulta confirma; falha nao produz nota | PASSOU |
| REP-05 | Unidade backend, resultados inconsistentes | Nao publicar nota invalida ou de outro ID | Resumo indisponivel, aviso sem dados privados | PASSOU |
| REP-06 | Unidade backend, notas mudam entre chamadas | Nao usar cache global de reputacao | Segunda consulta retorna novo resumo | PASSOU |
| REP-07 | HTTP Nest, repositorio sintetico | Listar caronas/minhas/detalhes | Reputacao correta e dados privados preservados fora da resposta | PASSOU |
| REP-08 | HTTP Nest, pessoas diferentes | Recebidas usam passageiro; enviadas usam motorista | Pessoas corretas em todos os endpoints | PASSOU |
| REP-09 | HTTP Nest, sem sessao | Recusar antes de consultar | HTTP 401, sem consulta de reputacao | PASSOU |
| REP-10 | HTTP Nest, falha no repositorio | Preservar lista de caronas | HTTP 200 com resumo nulo | PASSOU |
| REP-11 | Unidade Flutter, JSON ausente/invalido/legado | Nao quebrar carona ou solicitacao | Modelos preservados, resumo nulo | PASSOU |
| REP-12 | Unidade Flutter, atualizar pontos | Nao perder reputacao ou identidade | Objeto de reputacao preservado | PASSOU |
| REP-13 | HTTP Flutter com MockClient, 6 endpoints e 3 estados | Reputacao na mesma requisicao | Uma chamada por leitura, sem endpoint extra | PASSOU |
| REP-14 | Widgets, 7 contextos, 320/412 px, fonte 100/180%, 3 estados | Texto correto e sem overflow | 84 combinacoes aprovadas | PASSOU |
| REP-15 | Widgets, 7 contextos, nome longo, 320 px, fonte 180% | Reputacao legivel sem overflow | 7 combinacoes aprovadas | PASSOU |
| REP-16 | Widget e semantica | Singular e leitura assistiva | Uma avaliacao e descricao correta | PASSOU |
| REP-17 | Widgets, abrir/aceitar/recusar/Pix | Preservar callbacks e regras existentes | Acoes executadas | PASSOU |
| REP-18 | Widget reconstruido com nova nota | Atualizar resumo sem manter texto anterior | Novo resumo visivel | PASSOU |
| REP-19 | PostgreSQL remoto, transacao READ ONLY | Conferir agregacao e indice | Medias/contagens conferem; indice por avaliado existe | PASSOU |
| REP-20 | PostgreSQL, CTE sintetica sem tabelas novas | Notas 5/4/5 e 1 | Medias 4,666... e 1; totais 3 e 1 | PASSOU |
| REP-21 | Aparelho + Render com versao nova | Validar visual e latencia da jornada real | Sem deploy/instalacao nesta tarefa | NAO_EXECUTADO |

Os testes direcionados estao incluidos nas suites completas; reexecucoes e
capturas nao devem ser somadas como novos cenarios funcionais distintos.

## Desempenho e banco

Foram feitas apenas leituras no Supabase. Havia 5 avaliacoes no momento da
consulta. As medias agrupadas foram comparadas com consultas individuais e
coincidiram. O indice em `id_avaliado` ja existe, sem migration necessaria.

Um EXPLAIN ANALYZE da agregacao para os usuarios existentes apresentou
`Execution Time: 0.261 ms` e `Planning Time: 9.518 ms`, sem escrita de blocos.
Esse diagnostico usa um subselect de usuarios no filtro, em vez da lista de
parametros do endpoint. Nao e benchmark da latencia HTTP do Render nem do
aplicativo e nao demonstra comportamento sob carga ou com uma base grande.

O custo adicional esperado e uma consulta agregada por listagem nao vazia,
nao uma chamada HTTP por card. Mantidos os caches e o refresh ja existentes.
Referencias: [agregacoes PostgreSQL](https://www.postgresql.org/docs/17/functions-aggregate.html)
e [analise de consultas Supabase](https://supabase.com/docs/guides/database/query-optimization).

## Revisao e limites

- Revisao final: 799 testes backend repetidos e aprovados; 2.165 testes Flutter
  aprovados; 143 verificacoes direcionadas repetidas com tema/fontes reais
  (140 funcionais e 3 capturas). Sao 20 testes novos backend e 140 novos Flutter,
  ja incluidos nos totais completos. Nenhum caso pulado foi contado como aprovado.
- Analise estatica Flutter repetida apos os ajustes finais: nenhum problema.
  Prettier --check e git diff --check aprovados. APK debug compilado sem instalar.
  SHA-256: `56efb5be2d89ba047fb98d3a81de5294b43f7472065db28587dc5b1ef11a36ba`.
- Regras de criacao de avaliacao e restricoes do banco foram preservadas.
- Nenhum segredo, documento pessoal, pagamento real ou localizacao pessoal foi
  usado nos novos testes ou incluido nas capturas.
- Na primeira rodada houve um problema no executor novo de acessibilidade:
  SemanticsHandle era liberado tarde demais. Corrigido com try/finally no teste,
  mantendo a assercao. A bateria foi repetida e aprovada.
- A primeira captura nao carregava a fonte MaterialIcons do executor; o ajuste
  foi somente no teste. As imagens finais foram geradas novamente e inspecionadas.
- A consulta SQL inicial teve erro de sintaxe, sem executar gravacoes; a leitura
  foi corrigida e repetida com sucesso em transacao READ ONLY.
- Para ver a funcionalidade no app normal, sera necessario publicar o backend
  novo e instalar um APK com os modelos/cards novos. APK antigo ignora os campos;
  APK novo contra backend antigo continua utilizavel, mas sem o indicador.
- Nenhuma garantia de ausencia absoluta de bugs: falta validacao integrada no
  celular depois do deploy e nao foi executado teste de carga.

## Roteiro no celular depois do deploy

1. Comparar a media/quantidade do perfil de teste com as exibidas em Home, busca
   e detalhes. A media visual e arredondada para uma casa decimal.
2. Solicitar uma carona com a segunda conta e conferir a reputacao do passageiro
   em Recebidas e no painel de solicitacoes dos detalhes da carona.
3. Conferir a reputacao do motorista em Enviadas e no historico.
4. Conferir uma conta ainda sem notas: `Perfil ainda nao avaliado`, sem nota 0/5.
5. Enviar uma avaliacao elegivel, atualizar a listagem e conferir media/total.
6. Abrir detalhes, aceitar/recusar e acessar o Pix de testes, sem alteracao do
   comportamento anterior. Voltar entre abas deve preservar o cache existente.

Sugestao de commit: `feat: exibe reputacao de motoristas e passageiros nos cards`.
