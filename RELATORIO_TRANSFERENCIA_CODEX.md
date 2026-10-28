# Relatório de transferência — UniCarona

**Atualizado em:** 21/09/2026  
**Projeto local:** `C:\TCC\CaronaUniversitariaTCC`  
**Repositório:** `https://github.com/UniCaronaTCC/CaronaUniversitariaTCC.git`  
**Branch atual:** `integracao-setembro`

Este documento descreve a situação atual para outro Codex continuar o trabalho sem perder contexto. Ele separa o que já foi enviado ao Git do que está somente na máquina local.

## Situação do Git

- O `HEAD` local e `origin/integracao-setembro` estão no mesmo commit: `b1c5f5c` (`fix: preserva acentuacao na documentacao e CI integradas`). Não há commits locais pendentes nem commits remotos ainda não baixados.
- A árvore local está **suja**: há 22 arquivos modificados e 2 testes novos ainda não adicionados ao Git. Esse pacote local contém as melhorias recentes de mapa/GPS e o cadastro de veículo.
- Existem também as pastas não rastreadas `opencode/` e `output/`. Não adicioná-las ao commit sem revisar; não fazem parte do código-fonte da funcionalidade.
- A CI em `.github/workflows/ci.yml` só executa automaticamente em `master` e `desenvolvimento`. Um push isolado para `integracao-setembro` não dispara essa CI.

### Alterações locais que ainda precisam de commit/push

#### GPS, mapa e corrida em andamento

- `frontend/lib/mapa/services/localizacao_service.dart`
- `frontend/lib/mapa/screens/mapa_screen.dart`
- `frontend/lib/mapa/widgets/mapa_navegacao_carona.dart`
- `frontend/lib/home/corrida_em_andamento.dart`
- `frontend/test/localizacao_service_test.dart` (novo)
- `frontend/test/rota_mapa_utils_test.dart` (novo)

O que foi implementado:

- O mapa de seleção abre na localização atual do aparelho; se não conseguir obter GPS, abre uma visão geral do Brasil para o usuário buscar ou marcar manualmente.
- Há botão para usar a localização atual como origem.
- Origem da carona exige ponto específico e coordenadas válidas; cidade/estado genéricos não são aceitos como origem.
- A navegação da corrida começa na localização atual do motorista, não na origem cadastrada da carona.
- O GPS descarta leituras com precisão acima de 40 m, descarta saltos grandes até que uma segunda leitura os confirme e suaviza as posições aceitas.
- A rota é recalculada depois de aproximadamente 50 m de deslocamento, sem abrir várias chamadas ao mesmo tempo.
- O motorista envia ao backend a posição filtrada a cada 5 segundos, somente enquanto a corrida está em andamento.
- Pontos de embarque são considerados alcançados com duas leituras próximas, a até 30 m, e deixam de fazer parte da rota seguinte.

Estado de validação: testes unitários passaram, mas ainda é essencial testar fisicamente em deslocamento real. Houve relatos de saltos de GPS dentro de casa; as correções foram feitas para reduzir esse efeito, mas não substituem teste na rua.

#### Veículo no perfil e ligação com caronas

- `backend/src/users/user.entity.ts`
- `backend/src/users/veiculo.entity.ts`
- `backend/src/users/users.controller.ts`
- `backend/src/users/users.service.ts`
- testes correspondentes em `backend/src/users/*.spec.ts`
- `frontend/lib/home/perfil.dart`
- `frontend/lib/services/auth_service.dart`
- `frontend/lib/home/ofertar_carona.dart`
- `frontend/lib/widgets/formulario_ofertar_carona.dart`
- `frontend/lib/models/carona.dart`
- `frontend/lib/widgets/conteudo_detalhes_carona.dart`
- `backend/src/caronas/caronas.service.ts`
- `backend/src/caronas/caronas.controller.ts`
- testes correspondentes em `backend/src/caronas/*.spec.ts`

O que foi implementado:

- A tabela `unicarona.veiculos` já existia no schema PostgreSQL/Supabase. Ela permite um veículo por usuário e possui índice único para placa normalizada em maiúsculas.
- Perfil possui seção **Meu veículo**, com cadastro/edição de modelo, cor e placa.
- Backend possui `GET /usuarios/perfil` e `PUT /usuarios/perfil/veiculo`; valida modelo, cor, placas antigas (`ABC1234`) e Mercosul (`ABC1D23`), remove espaço/hífen e grava em maiúsculas.
- O motorista vê a própria placa completa no perfil.
- Criar uma carona exige veículo cadastrado no backend e no formulário Flutter. Sem veículo, o botão fica desabilitado e há atalho para o perfil.
- Os detalhes da carona mostram modelo, cor e placa mascarada (`***1D23`) quando a rota passa pelo formatador de carona.

### Privacidade da placa

A correção foi aplicada localmente:

- `CaronasController.listarCaronas` e `listarMinhasCaronas` agora passam pelo formatador seguro.
- As respostas de criar, atualizar, iniciar, finalizar e listar caronas devolvem somente os quatro últimos caracteres, por exemplo `***1D23`.
- A placa completa permanece no banco e aparece apenas no perfil do próprio motorista.
- Há teste cobrindo as duas listagens e verificando que a placa completa não aparece no JSON.

## Arquitetura atual

| Camada | Tecnologia e responsabilidade |
|---|---|
| Aplicativo | Flutter/Dart; telas, mapa, GPS, autenticação, caronas, solicitações, chat e Pix de teste. |
| Backend | Node.js, TypeScript e NestJS; validação, regras de negócio, autorização e integração externa. |
| Banco | PostgreSQL em Supabase, schema `unicarona`; TypeORM no backend. |
| Auth | Supabase Auth. O backend valida o token Supabase com `JwtAuthGuard`. |
| Mapa | `flutter_map` + OpenStreetMap no app e OpenRouteService no backend. |
| Chat | Tabelas próprias, API NestJS e broadcast do Supabase Realtime. |
| Pagamentos | Estrutura de Pix via AbacatePay, limitada ao modo de teste. |

## Funcionalidades que já existem

### Conta e perfil

- Cadastro, confirmação por código/e-mail, login, logout e recuperação de senha via Supabase.
- Perfil com instituição/campus, foto, tipo de perfil, verificação e avaliações recebidas.
- Sessão usada separadamente em dispositivos; sair no emulador não encerra automaticamente a sessão do celular físico.
- Veículo, conforme detalhado acima, está pronto localmente mas sem commit.

### Caronas e solicitações

- Criar, editar e cancelar caronas.
- Busca e filtros de caronas.
- Origem/destino com latitude e longitude; origem precisa ser confirmada no mapa ou pelo GPS.
- Pontos de embarque cadastrados pelo motorista e solicitação de novo ponto pelo passageiro.
- Solicitar vaga, aceitar, recusar e cancelar participação.
- Estados principais: `ATIVA`, `LOTADA`, `EM_ANDAMENTO`, `FINALIZADA` e `CANCELADA`.
- A corrida avulsa pode iniciar de 1 hora antes até 2 horas depois do horário marcado.
- Histórico separado para papel de motorista e passageiro.

### Corrida e localização

- Tela de corrida em andamento para o motorista.
- Rota por ruas retornada pelo OpenRouteService e exibida no mapa OSM.
- Persistência de posição atual em `unicarona.posicao_atual_carona`.
- `PUT /caronas/:idCarona/posicao`: somente motorista e somente em corrida em andamento.
- `GET /caronas/:idCarona/posicao`: motorista ou passageiro com solicitação aceita.
- Posição removida ao finalizar a corrida.

### Chat, avaliações e pagamentos

- Conversa associada à solicitação, envio/listagem de mensagens e atualização por Supabase Realtime.
- Avaliações após carona finalizada, com regras de autoria e uma avaliação por solicitação/avaliador.
- Pix possui tela e backend, criação/consulta de cobrança e webhook AbacatePay. Atualmente é uma integração de teste e depende das variáveis de ambiente adequadas.

## Pendências funcionais importantes

### 1. Teste manual de ponta a ponta e depois commit

Testar em dois usuários/dispositivos:

1. Motorista cadastra veículo.
2. Motorista cria carona com origem, destino e ponto de embarque.
3. Passageiro vê veículo com placa mascarada, solicita vaga e é aceito.
4. Motorista inicia corrida na janela permitida.
5. Confirmar que o mapa começa no GPS atual do motorista e que a rota é recalculada sem travar.
6. Testar posições em área externa, pois GPS interno pode saltar.
7. Confirmar que o motorista conclui a corrida e que avaliações/histórico aparecem.

Depois de corrigir a placa e realizar esse teste, separar ou ao menos revisar o pacote local antes de `git add`, `commit` e `push`. O usuário ainda não autorizou commit/push nesta etapa.

### 2. Acompanhamento para o passageiro

O backend está pronto para fornecer a posição do motorista e verifica se o passageiro foi aceito. Porém o Flutter ainda não chama `GET /caronas/:idCarona/posicao` e não há tela de acompanhamento do passageiro.

Próxima implementação sugerida:

- criar método de leitura de posição em `CaronaService`;
- criar tela/mapa para passageiro após a solicitação ser aceita e a corrida iniciar;
- consultar a cada 5 segundos inicialmente, reaproveitando o marcador de motorista;
- exibir estado "aguardando motorista iniciar" e "sem posição recente";
- só depois avaliar migrar essa leitura para Realtime.

### 3. Recorrência deve ser redesenhada

O cadastro de recorrência atual registra dias da semana e período, mas **não cria corridas independentes para cada dia**. Hoje isso causa limitações explícitas:

- iniciar e finalizar caronas recorrentes é bloqueado;
- Pix para recorrentes é bloqueado;
- não há separação limpa entre passageiros/status da corrida de hoje e da corrida de amanhã.

Regra de negócio acordada anteriormente: recorrência serve somente para evitar que o motorista cadastre o mesmo trajeto todo dia. Cada dia precisa ter sua própria carona, com data, status, passageiros, posição, pagamento e avaliação independentes.

Modelo recomendado:

```text
template de recorrência (trajeto, horário, dias, vigência, motorista)
        └─ ocorrência diária da carona (data, status, vagas, solicitações, GPS)
```

Não tentar liberar início/finalização das recorrentes atuais sem essa separação. Isso deve ser um projeto próprio, com migração, geração diária de ocorrências e migração/aposentadoria gradual do campo atual.

### 4. Mapa e GPS ainda precisam de acabamento

- O motorista possui visual de navegação aproximado, mas não é navegação curva a curva como Waze/Google Maps.
- O passageiro ainda não acompanha o motorista.
- OpenRouteService pode responder 504/429/5xx; o backend tenta novamente uma vez, com timeout de 18 s por tentativa e espera de 500 ms. O app pode aguardar até 40 s. Isso é funcional, mas precisa de teste em rede móvel e de uma UX mais rápida se os erros forem frequentes.
- A rota `POST /rotas/calcular` está sem autenticação e sem limite de pontos. Antes de produção, proteger com `JwtAuthGuard`, validar quantidade/faixa de coordenadas e aplicar limite de requisições.

## Questões de segurança e produção

Há um relatório local de segurança em `opencode/skills/avaliar-seguranca-tcc/relatorio-seguranca.md` (não rastreado no Git). Principais itens úteis:

1. Mover chave HMAC de webhook AbacatePay que está no código para variável de ambiente e rotacioná-la se já foi publicada.
2. Servir a API por HTTPS em produção. O padrão atual de `API_BASE_URL` é `http://10.0.2.2:3000`, adequado somente ao emulador Android.
3. Adicionar rate limiting para mensagens, Pix, posições e rotas.
4. Remover segredo de webhook da query string e preferir cabeçalho ou HMAC.
5. Rever RLS/permissões do Supabase e manter tabelas de negócio acessíveis só pelo backend.
6. Considerar desabilitar persistência paralela do SDK Supabase, mantendo tokens apenas no `flutter_secure_storage`.

Esses itens não precisam bloquear a apresentação do TCC, mas devem ser tratados antes de lançamento público.

## Configuração de execução local

### Backend

```powershell
cd C:\TCC\CaronaUniversitariaTCC\backend
npm run start:dev
```

O backend precisa escutar em `0.0.0.0:3000` para celular físico na mesma rede. Se a porta 3000 já estiver em uso, encerrar o processo anterior em vez de iniciar uma segunda instância.

### Flutter no emulador Android

```powershell
cd C:\TCC\CaronaUniversitariaTCC\frontend
flutter run -d emulator-5554 --dart-define=API_BASE_URL=http://10.0.2.2:3000
```

### Flutter no celular físico

Usar o IP local atual do computador, não `10.0.2.2` nem `localhost`:

```powershell
flutter run -d "ID_DO_CELULAR" --dart-define=API_BASE_URL=http://IP_DO_COMPUTADOR:3000
```

Celular e computador precisam estar na mesma rede Wi-Fi; firewall deve permitir a porta 3000.

## Verificação atual

Executada em 21/09/2026, com todas as alterações locais presentes:

| Verificação | Resultado |
|---|---|
| `backend: npm test -- --runInBand` | 20 suítes, 161 testes aprovados |
| `backend: npm run build` | aprovado |
| `frontend: flutter analyze --no-pub` | sem problemas |
| `frontend: flutter test --no-pub -r compact` | 74 testes aprovados |

Não foram executados testes E2E nem teste físico nesta verificação.

## Ordem recomendada de trabalho

1. Fazer teste manual de dois usuários, de preferência celular físico como motorista e emulador como passageiro.
2. Revisar as alterações locais, fazer commit e push em uma branch que passe pela CI/PR.
3. Implementar a tela de acompanhamento do passageiro com consulta de posição a cada 5 segundos.
4. Planejar e implementar recorrência com templates e ocorrências diárias separadas.
5. Melhorar resiliência/UX do mapa e aplicar os itens de segurança antes de qualquer publicação pública.

## Contexto adicional

- Houve uma conversa compartilhada indicada pelo usuário: `https://chatgpt.com/s/cx_6aab256bdfe481919f082de61edc5d80`. O conteúdo não ficou disponível para extração automática, então este relatório usa o histórico de desenvolvimento e a inspeção atual do repositório.
- A regra de recorrência e a arquitetura de ocorrências diárias foram discutidas, mas ainda não foram implementadas.
- Não criar contas de teste por e-mail enquanto o envio de e-mails/Resend estiver temporariamente desativado; usar contas existentes ou reativar a configuração antes de testar passageiro e motorista juntos.
