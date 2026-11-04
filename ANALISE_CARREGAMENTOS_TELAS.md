# BuscaEu: analise dos carregamentos entre telas

Data: 03/11/2026.

Status: investigacao concluida; melhoria ainda nao implementada.

## 1. Objetivo e limites

Reduzir os carregamentos repetidos ao alternar entre Chat, Caronas e Perfil, com uma mudanca controlada e adequada a proximidade da entrega do TCC.

O usuario relatou que a Home conserva seu conteudo, enquanto as demais abas voltam a carregar quando sao abertas. O incomodo tambem ocorre ao retornar de algumas subtelas.

Este documento separa os achados confirmados, os riscos identificados por leitura do codigo e a proposta futura. Nao autoriza a implementacao de todas as etapas.

Na investigacao original, nao houve alteracao de codigo, banco, configuracao de Render ou APK. Foram consultados o repositorio local, o GitHub e o Supabase, e executados testes existentes. Nesta etapa de documentacao, somente este arquivo foi criado.

Nao houve medicao de desempenho no celular, captura de trafego ou instrumentacao do backend em producao. Nao se deve prometer ganho em segundos ou porcentagem.

## 2. Fotografia da versao analisada

- Repositorio: `UniCaronaTCC/CaronaUniversitariaTCC`.
- Branch local: `desenvolvimento`.
- Commit local: `660008d`, merge do remoto com a correcao de cidade na busca.
- Correcao de cidade: `72e0dba`.
- Na consulta ao GitHub, a branch remota apontava para `a3ea228`.
- Esse commit remoto altera bloqueios de Pix e valor minimo, nao a navegacao.
- O repositorio estava limpo, dois commits a frente da referencia remota conhecida.

Essas referencias identificam a fotografia investigada. Nao comprovam a versao implantada no Render ou instalada no celular.

## 3. Conclusao principal

A causa principal identificada e a combinacao de recriacao de telas, carregamento inicial obrigatorio e ausencia de reaproveitamento das listas entre visitas.

A recomendacao e manter a navegacao atual e conservar temporariamente a ultima resposta valida, separada por usuario e sessao. Ao reabrir uma area, mostrar os dados anteriores e buscar uma versao atualizada em segundo plano.

O objetivo principal e melhorar a percepcao de velocidade. Isso nao elimina a necessidade de rede nem garante abertura instantanea na primeira visita.

## 4. Achados confirmados no codigo

### 4.1. Navegacao: por que a Home e diferente

Em [navegacao_principal.dart](C:/TCC/CaronaUniversitariaTCC/frontend/lib/navigation/navegacao_principal.dart:27), Chat, Caronas e Perfil sao abertos com `pushNamedAndRemoveUntil`, preservando apenas a primeira rota anterior.

Ao voltar a Home, o codigo usa `popUntil` ate a primeira rota. A Home normalmente conserva sua instancia, enquanto a aba secundaria anterior e descartada.

As rotas em [main.dart](C:/TCC/CaronaUniversitariaTCC/frontend/lib/main.dart) constroem novas instancias das telas. Cada instancia executa sua inicializacao novamente.

Adicionar `const` ou guardar estaticamente o objeto de um widget nao preserva o estado de uma rota descartada. A proposta e preservar dados, sem depender da instancia da tela.

### 4.2. Chat

Em [conversas.dart](C:/TCC/CaronaUniversitariaTCC/frontend/lib/home/conversas.dart:76):

- A lista comeca vazia e `carregando` comeca verdadeiro.
- `initState` chama `carregarDados()`.
- Existe atualizacao silenciosa, utilizada em alguns eventos e no retorno ao primeiro plano.
- Voltar de uma conversa individual chama a atualizacao sem o modo silencioso.
- Carregamento ou erro substituem o conteudo, mesmo quando ha dados anteriores no estado.
- Nao existe protecao de consulta em andamento equivalente a de Caronas.
- O timer de arquivamento precisa continuar funcionando, mesmo com lista reaproveitada.

Ha listeners para total de mensagens nao lidas e versao das conversas. Eles podem solicitar consultas proximas entre si. A possibilidade de respostas fora de ordem e um risco identificado no codigo; nao foi reproduzida no celular nesta investigacao.

### 4.3. Caronas

Em [minhas_caronas.dart](C:/TCC/CaronaUniversitariaTCC/frontend/lib/home/minhas_caronas.dart:59):

- Cada instancia carrega Recebidas e Enviadas em paralelo.
- As listas comecam vazias.
- O estado geral de carregamento ou erro substitui as abas.
- Eventos e retorno ao primeiro plano ja podem atualizar silenciosamente.
- Aceitar, recusar, cancelar, avaliar e voltar de pagamento/acompanhamento podem acionar novamente o carregamento geral.
- `consultando` impede consultas simultaneas apenas naquela instancia da tela.
- Essa protecao nao compartilha consultas com o contador da barra inferior.

Risco a cobrir: um evento recebido durante uma consulta pode ser ignorado pelo retorno antecipado de `consultando`. Deve-se avaliar uma atualizacao pendente a executar depois, sem criar um ciclo de consultas.

### 4.4. Consultas repetidas dos contadores

Em [barra_navegacao_home.dart](C:/TCC/CaronaUniversitariaTCC/frontend/lib/widgets/barra_navegacao_home.dart), cada nova barra inicia a atualizacao dos contadores quando os totais nao sao fornecidos explicitamente.

Em [solicitacao_service.dart](C:/TCC/CaronaUniversitariaTCC/frontend/lib/services/solicitacao_service.dart:16), a inicializacao do contador consulta Recebidas e Enviadas antes de conferir se o timer ja esta ativo.

Consequencia derivada do codigo: entrar em Caronas pode iniciar um par de consultas para a tela e outro par para o contador. Nao houve captura de trafego no celular para quantificar o efeito real.

O contador tambem atualiza a cada 30 segundos. Compartilhar consultas nao deve eliminar essa atualizacao nem deixar de informar uma acao pendente.

Em [mensagem_service.dart](C:/TCC/CaronaUniversitariaTCC/frontend/lib/services/mensagem_service.dart:86), a inicializacao do contador de mensagens tambem atualiza o total antes de verificar se o canal do usuario ja existe.

### 4.5. Perfil ja reaproveita parte dos dados

Em [perfil.dart](C:/TCC/CaronaUniversitariaTCC/frontend/lib/home/perfil.dart:80):

- `usuario` e inicializado a partir de `AuthService.usuarioLogado`.
- O perfil atualizado e buscado primeiro; depois, as avaliacoes.
- Os novos dados da tela sao aplicados ao final dessas etapas.
- A media e o total de avaliacoes comecam zerados em cada nova instancia.

Importante: o layout atual nao troca todo o Perfil por um spinner. Em [conteudo_perfil_buscaeu.dart](C:/TCC/CaronaUniversitariaTCC/frontend/lib/widgets/conteudo_perfil_buscaeu.dart), os dados basicos permanecem visiveis com um indicador linear, mas alguns controles ficam indisponiveis enquanto `carregando` e verdadeiro.

A melhoria adequada e separar estados de atualizacao, aplicar o perfil assim que chegar e nao fazer toda a tela esperar pelas avaliacoes. Enquanto estas carregam, zero nao deve ser apresentado como se fosse um resultado confirmado.

O backend de perfil nao inclui esse resumo de avaliacoes na resposta atual. Seu reaproveitamento deve partir de uma consulta anterior bem-sucedida da mesma conta.

### 4.6. Protecao de sessao existente

Em [auth_service.dart](C:/TCC/CaronaUniversitariaTCC/frontend/lib/services/auth_service.dart:14), `_versaoSessao` protege contra respostas de operacoes anteriores a uma mudanca de sessao.

`AuthService.sair()` limpa o perfil da sessao. As operacoes de perfil atualizam `usuarioLogado` e sua persistencia quando concluidas com sucesso.

Uma nova memoria de listas deve respeitar essa fronteira. Separar somente por ID e insuficiente: a mesma conta pode sair e entrar enquanto uma consulta antiga ainda esta terminando.

O ponto de limpeza ou uma exposicao controlada da geracao da sessao precisa ser definido na implementacao. Nao e necessario reescrever login ou renovacao de token.

## 5. Backend e Supabase

As consultas ao Supabase foram somente leitura, no projeto `kytkkjvzhvwjqzyaujak`, esquema `unicarona`.

Na fotografia consultada, havia 16 usuarios, 18 conversas, 44 mensagens, 21 solicitacoes e 4 avaliacoes. O volume e pequeno, mas isso nao prova eficiencia nem mede latencia.

Foram confirmados gatilhos de notificacao para mensagens, pagamentos, solicitacoes e caronas. O frontend ja possui canais privados do usuario e caminhos de atualizacao.

O plano nao depende exclusivamente de eventos em tempo real: conserva consultas ao entrar na area, retornar ao aplicativo e concluir operacoes importantes.

O advisor de desempenho apontou:

- Duas FKs sem indice de cobertura: avaliador em `avaliacoes` e remetente em `mensagens`.
- Tres indices sem uso registrado na fotografia consultada.

Sao avisos informativos, sem causalidade comprovada com o carregamento relatado. Nao criar ou remover indices como primeira medida, nem excluir um indice apenas por estar sem uso em um banco de testes pequeno.

Referencias: [FKs sem indice](https://supabase.com/docs/guides/database/database-linter?lint=0001_unindexed_foreign_keys) e [indices sem uso](https://supabase.com/docs/guides/database/database-linter?lint=0005_unused_index).

Em [mensagens.service.ts](C:/TCC/CaronaUniversitariaTCC/backend/src/mensagens/mensagens.service.ts:83), depois de listar conversas, ha duas consultas adicionais por conversa: ultima mensagem e total nao lido. Isso pode merecer otimizacao quando o volume crescer, mas nao precisa ser alterado na primeira etapa.

Nao foram medidos tempo de rede, inicializacao do Render, pool de conexoes, decodificacao ou renderizacao no aparelho. Esses fatores sao possibilidades adicionais, nao causas confirmadas.

## 6. Alternativas avaliadas

| Alternativa | Vantagem | Limite ou risco | Recomendacao |
| --- | --- | --- | --- |
| Atualizacao silenciosa nas instancias atuais | Mudanca pequena; evita esconder listas ao voltar de subtelas | Nao preserva dados apos descarte da aba | Incluir na primeira etapa |
| Ultima resposta valida em memoria por sessao | Reabertura rapida sem trocar a navegacao | Exige isolamento, invalidacao e protecao contra respostas antigas | Opcao principal |
| Compartilhar GETs identicos em andamento | Reduz duplicacao entre tela e contador | Alteracoes exigem consulta posterior, nao reaproveitamento cego | Aplicar pontualmente |
| Manter abas em `IndexedStack` | Preserva os estados das telas | Muda navegacao, observadores, rotas e ciclo de vida | Adiar |
| Cache persistente de chats e caronas | Sobrevive ao encerramento do processo | Amplia privacidade, validade, limpeza e migracao | Fora desta etapa |
| Trocar spinner por shimmer ou animacao | Muda a aparencia da espera | Nao evita consulta nem recriacao de dados | Insuficiente |
| Otimizar consultas e indices do backend | Pode ajudar desempenho real | Amplia escopo e exige medicao para priorizar | Avaliar depois |

`AutomaticKeepAliveClientMixin` isoladamente nao resolve uma rota removida. Manter todas as abas abertas tambem pode iniciar diversas consultas juntas e deixar listeners de telas ocultas trabalhando.

Nao ha necessidade inicial de instalar uma biblioteca de estado, adicionar banco local, alterar schema ou configurar novos servicos.

## 7. Comportamento proposto

| Situacao | Resultado esperado |
| --- | --- |
| Primeira visita, sem dados anteriores | Carregamento inicial normal |
| Reabrir na mesma sessao | Mostrar ultimo conteudo valido e buscar atualizacao |
| Atualizacao com dados disponiveis | Manter os cards visiveis |
| Resposta nova | Substituir os dados antigos, inclusive removendo itens ausentes |
| Lista vazia bem-sucedida | Tratar o vazio como resultado valido |
| Falha com dados anteriores | Manter conteudo, avisar e oferecer nova tentativa |
| Falha sem dados anteriores | Mostrar erro, nao fingir uma lista vazia |
| Logout ou sessao definitivamente invalida | Descartar dados privados |
| Encerrar o processo do app | Perder as novas listas em memoria; primeira visita pode carregar novamente |

A proposta nao e ignorar o servidor por um periodo longo. Revalidar ao reabrir continua fazendo parte do fluxo.

## 8. Contrato de consistencia e seguranca

1. Guardar apenas respostas bem-sucedidas e validadas; erro, HTML ou JSON incompleto nao substituem dados validos.
2. Distinguir lista vazia valida de ausencia de carregamento anterior.
3. Separar por usuario e geracao da sessao, com limpeza no logout e em sessao definitivamente invalida.
4. Nao usar o texto do token como identidade principal da memoria: renovar token pode ocorrer dentro da mesma sessao.
5. Ignorar respostas antigas mesmo quando a mesma conta entra novamente.
6. Usar copias ou colecoes nao modificaveis para evitar alteracao acidental dos dados compartilhados.
7. Substituir listas completas na consulta completa; apenas unir resultados pode ressuscitar itens cancelados, expirados ou removidos.
8. Atualizar ou invalidar os dados apos operacoes que mudam seu estado.
9. Nao permitir que GET anterior a uma alteracao sobrescreva a resposta posterior a ela.
10. Registrar uma atualizacao pendente quando um evento relevante chegar durante outra consulta.
11. Preservar arquivamento por tempo, contadores e retorno ao primeiro plano.
12. Nao tratar 401 definitivo como simples falha de rede nem esconder logout com dados antigos.

Aceitar, recusar, solicitar, cancelar, pagar, iniciar/finalizar e oferecer carona continuam passando pelas rotas e validacoes atuais. Dados anteriores servem para exibicao, nunca para autorizar uma operacao ou confirmar pagamento.

Ficam fora dessa memoria: QR Code, Pix copia e cola, confirmacao local de pagamento, GPS ao vivo, documentos/imagens da CNH e permissoes baseadas apenas em dados antigos.

## 9. Execucao em etapas

### Etapa 1: Chat

Comprovar a melhora em uma area delimitada antes de envolver Caronas.

- Guardar e restaurar a ultima lista valida da mesma sessao.
- Buscar uma versao atualizada ao entrar.
- Atualizar silenciosamente ao voltar da conversa individual.
- Conservar conteudo e apresentar aviso em falha de atualizacao.
- Controlar consultas simultaneas e respostas antigas.
- Preservar nao lidas e arquivamento.

Estimativa inicial: de 3 a 5 arquivos de implementacao, mais testes. Nao e um numero fechado.

Arquivos candidatos: `conversas.dart`, `mensagem_service.dart`, uma pequena estrutura de memoria e um ponto de integracao com a sessao em `auth_service.dart`. Nao e necessario alterar a navegacao.

Criar estrutura compartilhada apenas se simplificar o isolamento e os testes; nao transformar a tarefa em um cache generico para todos os endpoints.

### Etapa 2: Caronas

- Reaproveitar Recebidas e Enviadas da mesma sessao.
- Manter as abas visiveis durante atualizacoes com dados anteriores.
- Compartilhar consultas identicas em andamento com contadores, quando seguro.
- Reconsultar apos aceite, recusa, cancelamento, avaliacao, pagamento e acompanhamento.
- Remover da apresentacao o que a resposta nova informar como expirado/encerrado.
- Tratar falha parcial: uma das listas com erro nao pode virar uma lista vazia valida.
- Preservar a aba inicial ao abrir Caronas por notificacao.

Complexidade moderada, com revisao mais sensivel por envolver vaga e pagamento. Nao misturar com mudanca do prazo de pagamento ou correcao de pontos de encontro.

### Etapa 3: Perfil

- Reaproveitar o perfil valido ja presente em `AuthService.usuarioLogado`.
- Aplicar a resposta de perfil antes de terminar a consulta de avaliacoes.
- Separar estados de perfil, avaliacoes e operacoes de edicao.
- Evitar piscar nota zero como se fosse resultado real.
- Refletir alteracao/remocao de foto, veiculo e situacao da CNH ao reabrir.
- Manter a autorizacao de oferecer carona no servidor.

### Subtelas

Nao incluir todas no primeiro pacote. Tornar o retorno a lista silencioso nao exige cachear pagamento, acompanhamento, historico ou mensagens individuais.

## 10. Riscos e mitigacoes

| Risco | Mitigacao |
| --- | --- |
| Conta B ver dados da A | Separacao por conta/sessao, limpeza e testes com duas contas |
| Consulta antiga preencher apos novo login | Conferir geracao da sessao antes de guardar/aplicar |
| Item cancelado ou expirado reaparecer | Substituir listas e invalidar apos alteracoes |
| Mensagem nova/leitura nao refletir | Eventos mais revalidacao; nao depender apenas do total numerico |
| Resposta anterior a pagamento sobrescrever a seguinte | Geracao/invalidacao e consulta posterior obrigatoria |
| Evento perdido durante consulta | Atualizacao pendente, sem sobreposicao desnecessaria |
| Erro apagar cards | Separar erro inicial de erro de atualizacao |
| Atualizacao silenciosa permitir acao repetida | Preservar bloqueio por item e validacao no backend |
| Memoria crescer indefinidamente | Guardar apenas os conjuntos necessarios da sessao atual |
| Outras telas serem afetadas | Executar por area, sem trocar a navegacao global |

O risco nao e zero. A mudanca nao precisa alterar regras financeiras ou banco, mas altera a logica de carregamento e apresentacao.

## 11. Testes necessarios para a implementacao

1. Primeira abertura com sucesso e sem dados anteriores.
2. Primeiro carregamento com erro e nova tentativa funcional.
3. Trocar de aba e voltar, mostrando dados antes da resposta nova.
4. Atualizar lista nao vazia e receber vazio valido.
5. Falhar atualizacao sem apagar conteudo anterior.
6. Desligar internet, reabrir e informar falha de atualizacao.
7. Religar internet e atualizar sem duplicar itens.
8. Sair da conta A e entrar na B sem limpar dados manualmente.
9. Sair e entrar na mesma conta durante consulta antiga.
10. Inverter ordem das respostas e manter a mais atual aplicavel.
11. Fechar tela com consulta pendente.
12. Receber evento durante consulta e nao perder a atualizacao.
13. Tocar rapidamente e nao multiplicar consultas identicas.
14. Preservar nova mensagem, ultimo texto, nao lidas e leitura.
15. Arquivar corretamente com passagem do tempo e lista reaproveitada.
16. Aceitar, recusar, cancelar, expirar e pagar; conferir listas e contadores.
17. Abrir Caronas por notificacao na aba correta.
18. Alterar/remover foto, editar veiculo e aprovar/remover CNH; reabrir Perfil.
19. Receber 401 definitivo sem manter dados privados como sessao ativa.
20. No celular fisico, repetir Home > Chat > Caronas > Perfil > Chat, antes e depois de alteracoes feitas pela outra conta.

Verificar quantidade de chamadas, nao apenas ausencia de spinner. Compartilhar um GET iniciado antes de uma alteracao nao pode substituir a consulta nova obrigatoria.

## 12. Validacao ja realizada

Foram executados 178 testes existentes, todos aprovados, nestes arquivos:

```text
frontend/test/conversas_test.dart
frontend/test/minhas_caronas_test.dart
frontend/test/perfil_test.dart
frontend/test/perfil_cnh_test.dart
frontend/test/perfil_foto_test.dart
frontend/test/perfil_tipo_cnh_test.dart
frontend/test/perfil_selo_cnh_test.dart
frontend/test/auth_perfil_erros_test.dart
frontend/test/sessao_renovacao_test.dart
frontend/test/barra_navegacao_home_test.dart
frontend/test/app_inicializacao_test.dart
```

Log local: `C:/Users/Usuario/AppData/Local/Temp/buscaeu-analise-carregamentos.log`.

Esses testes validam a base atual. Nao aprovam uma memoria de listas ainda nao implementada, nao medem ganho de desempenho e nao substituem a bateria especifica acima.

Antes de entregar uma implementacao, repetir testes focados, analise estatica e suite completa do frontend, alem da validacao no celular fisico.

## 13. Criterios de aceite da primeira entrega

- Chat reabre sem esconder uma lista valida da mesma sessao.
- O servidor continua sendo consultado.
- Conversas expiradas/encerradas mantem suas regras.
- Falha de rede nao apaga lista nem aparece como ausencia de conversas.
- Logout e troca de conta nao reaproveitam dados privados anteriores.
- Respostas antigas nao desfazem atualizacoes recentes.
- Navegacao, voltar e Home conservam o comportamento existente.
- Nao ha mudanca de banco, Render ou regra financeira.

## 14. O que nao prometer

- Carregamento zero na primeira abertura ou apos encerrar o processo.
- Todas as telas e subtelas instantaneas.
- Ganho exato sem medir no aparelho.
- Ausencia total de risco.
- Menos requisicoes apenas por esconder o indicador.
- Estado permanentemente atualizado sem rede.

## 15. Recomendacao final

Comecar somente pelo Chat, mantendo a navegacao atual e limitando a mudanca ao reaproveitamento de dados, atualizacao silenciosa e protecoes de sessao/concorrencia.

Validar no celular antes de levar o mecanismo a Caronas. Melhorar Perfil separadamente, aproveitando o que ele ja conserva.

Nao misturar com prazo de pagamento, pontos de encontro expirados, mudancas visuais amplas ou otimizacao de banco. Cada frente exige validacoes proprias.

Referencias oficiais consultadas:

- [Flutter: dados locais e atualizacao pela rede](https://docs.flutter.dev/app-architecture/design-patterns/offline-first).
- [Flutter: IndexedStack](https://api.flutter.dev/flutter/widgets/IndexedStack-class.html).
- [Supabase: FKs sem indice](https://supabase.com/docs/guides/database/database-linter?lint=0001_unindexed_foreign_keys).
- [Supabase: indices sem uso](https://supabase.com/docs/guides/database/database-linter?lint=0005_unused_index).
