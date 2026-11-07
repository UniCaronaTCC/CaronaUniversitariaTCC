# BuscaEu — testes no Android em 07/11/2026

Dispositivo modelo **25078RA3EL**, Android 15, tela 720×1600 e densidade 320 dpi. Branch `revisao`, base `83944d8`, com alteracoes locais. A skill `buscaeu-testes` e suas especializadas de perfil/CNH e interface orientaram a separacao das camadas e o uso de dados sinteticos.

O APK normal foi atualizado sem limpar dados. Sua abertura e a restauracao da sessao foram observadas. A bateria automatizada foi executada em uma copia separada, com identificador `com.tcchej.uni_carona.qa` e os mesmos arquivos de produto. Servicos ficticios permitem testar acoes sem criar/excluir registros da conta pessoal.

## Resultados executados

| Rodada | Execucoes de casos | Passaram | Falharam |
| --- | ---: | ---: | ---: |
| 1 | 155 | 139 | 16 |
| 2 | 193 | 184 | 9 |
| 3 | 10 | 5 | 5 |

Foram **358 execucoes de casos** em tres rodadas, correspondendo a **312 casos distintos** por arquivo/titulo (os dois diagnosticos do chat sao reexecutados sob a mesma chave). Estado da evidencia mais recente: `{"PASSOU": 300, "FALHOU": 4, "BLOQUEADO": 8}`. As reexecucoes nao contam como novos casos distintos. Os registros por caso estao em `CASOS.csv`; falhas e mensagens, em `FALHAS.md`.

A tabela das rodadas preserva o resultado bruto do runner. O CSV separa esse resultado do estado da evidencia: `BLOQUEADO` significa que a preparacao/instrumentacao nao permite concluir o comportamento pretendido, inclusive dois casos cujo runner passou usando um mock de GPS inadequado. Nenhuma dessas limitacoes foi promovida a aprovacao. O unico defeito de produto confirmado nesta rodada e o corte de conteudo no estado de carregamento do chat; quatro casos registram duas variantes desse mesmo problema.

**Recursos nativos:** 7/7 aprovados. Incluem renderizacao no Android, ML Kit real com documento inteiramente ficticio em 0°/90°/180°/270°, descarte de arquivos temporarios de OCR, inicializacao/liberacao da camera traseira sem fotografia e resposta do GPS sem salvar coordenadas. A leitura de texto sintetico nao valida autenticidade de CNH nem garante leitura de qualquer foto real.

## Diagnostico das divergencias

Na primeira rodada, callbacks de frames nativos nao herdaram a zona de simulacao HTTP de alguns testes escritos para o computador. Esses casos recebiam a resposta 400 do bloqueador de rede, em vez das fixtures esperadas. O executor ganhou um adaptador global que delega ao MESMO MockClient da fixture e nao faz rede externa. As assercoes de produto foram mantidas. A segunda rodada reproduz busca e detalhes com esse transporte adequado; os resultados concretos por caso constam no CSV.

O teste de perfil inicialmente tentou tocar um texto posicionado sob o cabecalho fixo. Somente na copia QA foi acrescentada rolagem para deixar o alvo visivel antes do toque, mantendo as assercoes de edicao/cadastro de veiculo. Nenhum arquivo de produto foi alterado. O teste de busca de campus que mede exatamente 499/500 ms depende de relogio controlado: em tempo real, a sobrecarga de frames ja pode ultrapassar 500 ms. Essa falha de instrumento foi preservada no registro, sem mudar a expectativa para obter aprovacao; o caso deterministico no computador passou na rodada anterior.

O chat apresentou `RenderFlex overflow` no componente `EstadoConteudoPadrao` em pouco espaco vertical, com fonte ampliada/teclado e durante carregamento. A terceira rodada isolada confirmou **13 px** de excesso com area logica 320×700, fonte 150% e teclado de 300, e **24 px** em conversa encerrada com area 320×560 e fonte 180%. Os dois casos `REPRO` usam uma resposta pendente controlada para conferir esse estado antes da resposta. A primeira rodada tambem registrou o mesmo problema com insets nativos e viewport de teste. Nao foi feita correcao de produto durante a verificacao. Os arquivos do componente e do chat foram mantidos pela limpeza, pois sao utilizados.

O ajuste indicado e permitir acomodacao/rolagem do estado de carregamento/vazio/erro dentro do espaco disponivel, preservando envio e mensagens. Fonte atual: `frontend/lib/widgets/componentes_padrao.dart`, `EstadoConteudoPadrao.build`, em especial o `Column` na linha 38; uso no chat em `frontend/lib/home/conversa_detalhe.dart`, linhas 467–471. Isso e um defeito visual de prioridade media, sem perda de dados reproduzida nesta rodada.

As outras limitacoes foram separadas: o teste de recuperacao usa posicao absoluta ignorando a area de status; o diagnostico adicional leu `MediaQuery` depois de `SafeArea` remover o padding. O retangulo da seta permaneceu fixo na rolagem no teste original antes dessa assercao absoluta. O preview do recorte ficou com 118 em um viewport sintetico cujo teste esperava 160, mas o teste adicional com **rotacao fisica real para paisagem**, fonte 180%, quatro cantos acessiveis e confirmacao passou. Isso nao sustenta uma falha funcional de recorte.

Os testes `mapa_encontro_sem_gps_test.dart` substituem `flutter.baseflow.com/geolocator`, enquanto o plugin Android instalado (`geolocator_android 5.0.3`) registra `flutter.baseflow.com/geolocator_android`. Por isso as quatro variantes sinteticas de GPS nao foram aprovadas nesta camada, independentemente do resultado bruto. O GPS nativo real, exercitado antes dessas fixtures, respondeu. A rota de acompanhamento do passageiro passou na terceira rodada apos criar o Completer ficticio na zona dos callbacks nativos, mantendo assercoes; o erro de teste entre zonas havia interrompido o binding na segunda rodada. Os testes de percurso do motorista passaram.

## Areas e limites

| Area | Camada efetivamente exercitada / limite |
| --- | --- |
| Acesso | Login, cadastro, recuperacao e confirmacao de codigo com callback ficticio em widgets no Android; sem enviar OTP/e-mail ou trocar senha de conta real. Confirmacao de e-mail real nao foi integrada. |
| Perfil, veiculo e CNH | Formularios/consentimento/status/edicao com callbacks ficticios; camera e OCR reais separados; recorte com imagem sintetica. Sem reset da CNH pessoal, Storage real ou validacao oficial. |
| Oferta, busca, detalhes e solicitacoes | Telas/estados, filtros, navegacao e regras expostas nos casos, com clientes sinteticos. Nao comprova disputa da ultima vaga no servidor. |
| Pagamentos/cancelamento | Pix, aviso de estorno e confirmacoes de tela com fixtures. Nao cria cobranca, nao simula junto ao provedor e nao faz estorno real. |
| Recorrencias | Exibicao/pausa/retomada com callbacks de teste; sem acionar gerador remoto ou agendamento real. |
| Mapas e viagem | Renderizacao/logica de percurso e encontros com rotas/posicoes simuladas; GPS real parado em caso separado. Sem trafegar em estrada/ponte, provar recalculo externo, rastrear em segundo plano ou iniciar/finalizar carona pessoal. |
| Comunicacao | Chat e central de avisos com dados ficticios; nao marca mensagens/avisos pessoais como lidos. Realtime entre duas contas reais nao foi validado. |
| Historico e avaliacoes | Listas por papel, estados, fonte e navegacao com fixtures; nao envia avaliacao de usuarios reais. |
| Seguranca e integridade | Nesta etapa nao houve jornada remota M/P/X ou escrita em banco. Casos isolados anteriores permanecem na rodada `2026-11-07-regressao-completa`; nao contam como novos testes no celular. |

Os testes anteriores de computador (2.770 cenarios/casos aprovados) e as pendencias de lint/tipagem estao no relatorio proprio. Os resultados no aparelho nao os apagam nem comprovam todas as integracoes reais.

## Preparacao, integridade e encerramento

O Xiaomi inicialmente recusou eventos de toque (`INJECT_EVENTS`) e algumas instalacoes (`INSTALL_FAILED_USER_RESTRICTED`) com tela apagada/confirmacao ausente. Tambem houve uma tentativa de preparo que inicializava o binding de testes duas vezes; o executor foi corrigido para reutilizar o binding padrao. Esses erros anteriores ao inicio dos casos sao problemas de preparacao e nao contam como falhas funcionais do app. As rodadas registradas acima iniciaram e finalizaram no aparelho.

A copia QA usa `integration_test` do SDK Flutter 3.38.9, sem atualizar dependencias do projeto. O teclado dos formularios e controlado pelo executor; camera, OCR e GPS usam os plugins nativos. Os tamanhos/fontes/teclado dos casos visuais sao configuracoes de teste no mesmo aparelho e nao equivalem a testar outros modelos ou iPhone. A Activity QA manteve a tela acesa durante a bateria; essa configuracao nao foi adicionada ao app normal.

Integridade: **439 arquivos conferidos, 0 alterados durante os testes**. Os transportes e a rolagem ajustados existem apenas na copia temporaria. `ADAPTACOES_EXECUTOR.json` e `harness/` documentam a preparacao. Nao houve commit, push, deploy, alteracao de schema/guardas ou alteracao de regra para tornar os testes verdes.

O app normal usa `https://buscaeu-api-henrique.onrender.com`. O backend local nao foi publicado nesta rodada; uma jornada completa com as regras locais exige verificar essa versao remota. A limpeza da copia QA e a reabertura do app normal sao verificadas ao final em `ENCERRAMENTO.json`. Logs brutos de depuracao/acessibilidade, tokens, documentos e coordenadas pessoais nao foram copiados para esta entrega.

Verificacao final: copia QA ausente, pacote normal instalado e Activity normal em foco. A configuracao global de manter tela ficou em 0, o mesmo valor inicial. A classe EstadoConteudoPadrao e o arquivo do chat coincidem com o HEAD anterior a limpeza; o defeito de layout encontrado ja existia nessa base. Nenhuma foto foi tirada, nenhum documento/CNH foi redefinido e nenhum registro de carona foi alterado.
