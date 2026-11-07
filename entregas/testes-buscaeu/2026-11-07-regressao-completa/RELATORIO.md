# Regressão automatizada completa — BuscaEu

Execução de 07/11/2026, fuso America/Sao_Paulo. Branch `revisao`, base Git `83944d8`, com as alterações locais de cancelamento/estorno, manutenção do teste CNH e limpeza de código. As regras atuais aprovadas pelo usuário substituem os pontos históricos do escopo de 05/11/2026: partida exige confirmação de pagamento e o protótipo registra estorno simulado após cancelamento/expiração.

## Resultado

Não foi encontrada regressão funcional na bateria automatizada executada após a limpeza. Os **2.770 testes/cenários** registrados passaram nas camadas indicadas abaixo. A análise estática completa do backend ainda apresenta pendências anteriores à limpeza; por isso esta rodada não é um selo geral de qualidade ou de funcionamento em serviços/aparelhos reais.

| Verificação | Resultado | Estado | Evidência |
| --- | --- | --- | --- |
| Backend: unidade e HTTP com mocks | 751 testes, 51 suítes, zero falhas | PASSOU | CASOS.csv / BACK-0001 a BACK-0751 |
| HTTP adicional: CNH e notificações | 20 testes, duas suítes, zero falhas | PASSOU | CASOS.csv / BACK-0752 a BACK-0771 |
| Flutter: unidade e widgets | 1.990 testes, 136 arquivos, zero falhas; rodada completa sem reexecução | PASSOU | CASOS.csv / FLUT-0001 a FLUT-1990 |
| SQL: cancelamento, estorno e confirmação tardia | Nove cenários em tabelas temporárias PostgreSQL, todos aprovados | PASSOU | CASOS.csv / SQL-01 a SQL-09 |
| Compilação do backend | npm run build concluído | PASSOU | RESUMO.json / backend-build |
| Tipagem do código de produção | tsc tsconfig.build.json sem emissão, aprovado | PASSOU | RESUMO.json / backend-types-build |
| Análise do Flutter | No issues found | PASSOU | RESUMO.json / flutter-analyze |
| APK Android de teste | build debug concluído com API_BASE_URL do Render Henrique | PASSOU | build/app/outputs/flutter-apk/app-debug.apk |
| Metadados do banco atual | 16 entidades, 169 colunas mapeadas presentes e quatro gatilhos da alteração ativos | PASSOU | RESUMO.json / estrutura_banco |
| ESLint global do backend, sem --fix | 12 erros e 11 avisos | FALHOU | ANALISE_BACKEND.json |
| Tipagem incluindo arquivos de testes | 12 diagnósticos TypeScript | FALHOU | TIPAGEM_TESTES.txt |
| Código e arquivos de configuração | Conteúdo conferido antes/depois; preservado | PASSOU | Integridade abaixo |

Os nove cenários SQL usam participantes e pagamentos fictícios. O cenário que protege estados encerrados contém três variantes. Não foram enviados broadcasts por esses cenários. A consulta aos metadados foi feita em transação READ ONLY; ela verifica nomes de colunas e presença de gatilhos, sem comprovar todas as constraints, tipos, RLS ou regras funcionais.

## Áreas exercitadas

A tabela organiza os casos por arquivo de teste e domínio principal. A contagem não mede percentual de cobertura de requisitos, rotas ou linhas e não transforma testes com mocks em validação de um provedor real. Cada caso e sua fonte estão no CSV.

| Área | Casos aprovados nesta rodada | Referência do escopo |
| --- | ---: | --- |
| Autenticação e sessão | 263 | RF01–RF02; sessão, confirmação e recuperação |
| Caronas e solicitações | 532 | RF03–RF07, RF10 e RF12 |
| Conversas e notificações | 171 | RF09; central de avisos |
| Histórico e avaliações | 40 | RF08 e RF16 |
| Interface e componentes gerais | 254 | RNF01 e RNF05; navegação, tamanhos e mensagens |
| Mapas, destinos e viagem | 666 | RF12–RF15; cidades, campi e endereços |
| Pagamentos e reservas | 208 | Pix Dev Mode adicional; prazo, início e estorno simulado |
| Perfil, foto, veículo e CNH | 594 | Perfil acadêmico, privacidade e conferência local da CNH |
| Recorrências | 42 | RF11 |

Identidade/permissões, entradas inválidas, isolamento por sessão e respostas atrasadas são transversais: há casos desses comportamentos em diferentes áreas. Não são contados outra vez como um domínio adicional.

## Pendências de análise estática

Os testes executados passaram e o backend compilou. A verificação estática mais ampla detectou os seguintes apontamentos de qualidade já presentes:

| Arquivo | ESLint: erros | ESLint: avisos |
| --- | ---: | ---: |
| backend/src/users/foto-perfil-http.spec.ts | 4 | 8 |
| backend/src/users/foto-perfil.service.spec.ts | 2 | 0 |
| backend/src/users/foto-perfil.service.ts | 3 | 3 |
| backend/src/users/users.controller.spec.ts | 3 | 0 |

Os apontamentos envolvem tipos any e retornos/mocks sem tipagem, além de uma função async de teste sem await. A checagem de tipos de todos os testes encontra fixtures incompletas, acessos possivelmente nulos e a tipagem genérica do aplicativo de teste CNH. A configuração de compilação de produção exclui os testes, por isso a compilação do backend passa.

Para verificar regressão, foi recompilada em memória a versão imediatamente anterior à limpeza, usando a cópia do controller preservada antes das remoções e o mesmo ambiente. Resultado: **12 diagnósticos antes, os mesmos 12 depois**. Os arquivos de foto/perfil e os demais arquivos com apontamentos não foram alterados pela limpeza.

Esta rodada registrou os diagnósticos e manteve o código e as expectativas dos testes.

## Limites e etapas não executadas

| Área/caso | Estado | Motivo e limite |
| --- | --- | --- |
| Câmera, OCR ML Kit nativo, GPS em trajeto real e interação no Android | NAO_EXECUTADO | O usuário escolheu apenas testes automatizados; nenhum aparelho estava conectado. Os testes Flutter usam simulações. |
| iPhone/iOS | NAO_EXECUTADO | Ambiente Windows, sem compilação ou execução em iPhone. |
| Login/OTP, Storage e Realtime contra serviços reais | NAO_EXECUTADO | Não há contas/ambiente descartável preparados para essa integração nesta rodada. Mocks e HTTP isolados não comprovam a rede real. |
| AbacatePay Dev Mode real e webhook externo | NAO_EXECUTADO | Nenhuma cobrança foi criada ou simulada no provedor; os clientes e respostas externos foram substituídos nos testes. |
| Concorrência real da última vaga, partida e confirmação/cancelamento | NAO_EXECUTADO | A rodada SQL atual utiliza uma conexão e pg_temp. Mocks não comprovam bloqueios. Testes de duas conexões da rodada anterior não são contados como executados hoje. |
| AppModule e jornada integrada contra o banco compartilhado | NAO_EXECUTADO | O teste app.e2e-spec.ts inicia o módulo real e os jobs de expiração/encerramento/recorrência. Não foi executado contra os dados compartilhados. |
| Nova versão no Render e workflow no GitHub | NAO_EXECUTADO | As alterações continuam locais. Nenhum commit, push ou deploy foi feito nesta rodada. |
| Autenticidade oficial da CNH, dinheiro real e reembolso financeiro | FORA_DO_ESCOPO | A CNH é conferência interna e o pagamento/estorno é simulado no escopo do protótipo. |

A [skill de testes do BuscaEu](C:/Users/henri/.codex/skills/buscaeu-testes/SKILL.md) determina: “Não inicie API/jobs, teste mutações remotas ou provedores sem que alvo e escopo estejam autorizados”. O alvo configurado é compartilhado. A aplicação dessa regra nesta rodada foi selecionar os testes isolados e os dados temporários, preservando os registros existentes. O HTTP de CNH e notificações foi executado selecionando os dois arquivos, sem carregar AppModule.

A proteção do cálculo de rotas permanece adiada por decisão do usuário. Os testes atuais desse serviço não comprovam autenticação nesse endpoint. O botão/rota de reinício de CNH para testes e a URL do APK gerado pelo workflow também permanecem itens de preparação da entrega; esta rodada não altera essas regras.

## Ambiente, comandos e evidências

- Windows; Node v24.13.0; Flutter 3.38.9; Dart 3.10.8. O workflow versionado usa Node 22; ele não foi executado nesta rodada local.
- Backend: Jest em série; suítes HTTP explicitamente selecionadas; npm run build; ESLint sem --fix; tsc com noEmit e incremental=false.
- Frontend: flutter analyze --no-pub; flutter test --no-pub --concurrency=2 --reporter=json; flutter build apk --debug --no-pub --dart-define=API_BASE_URL=https://buscaeu-api-henrique.onrender.com.
- SQL: node test/cancelamento-estorno-temporario.cjs, somente tabelas temporárias; sem a opção --concorrencia.
- Na primeira chamada do Jest, o PowerShell interpretou o caminho do JSON como filtro e não selecionou testes. O comando foi corrigido no executor, usando --outputFile e o caminho como argumentos separados. A execução válida de 751 testes foi concluída em seguida; nenhum teste do projeto foi alterado.
- CASOS.csv contém uma linha por caso, com requisito/fonte, camada, preparação, ação, esperado, observado, estado e evidência.
- RESUMO.json contém totais e códigos de saída efetivos; ANALISE_BACKEND.json e TIPAGEM_TESTES.txt registram as pendências estáticas.
- Os casos utilizam dados fictícios. Os nomes de casos exportados tiveram e-mails, documentos e cabeçalhos de token mascarados.

## Integridade do código

Os arquivos do projeto fora da pasta de relatórios foram comparados por SHA-256 antes e depois da rodada. Conteúdo preservado; somente os relatórios desta execução foram acrescentados. Nenhum dado pessoal ou de pagamento foi alterado.
