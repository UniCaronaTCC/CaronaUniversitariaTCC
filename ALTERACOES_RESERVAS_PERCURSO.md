# Alterações de reservas e percurso — BuscaEu

Referência: implementação local sobre o commit 2a2af08, em 05/11/2026.

## Comportamento

- Antes da partida, confere reservas vencidas e exige pagamento confirmado de todos os passageiros ainda aceitos. Pagamento simulado confirmado conta como pago.
- Reservas válidas ou pagamentos incertos são preservados; a partida fica bloqueada enquanto houver pendência.
- Paradas sugeridas sem reservas aceitas deixam de participar do percurso. Pontos compartilhados continuam enquanto houver outro passageiro aceito.
- Pontos originais, pontos já percorridos e dados históricos são preservados.
- O motorista atualiza o progresso a cada 30 segundos e ao retomar o aplicativo. O mapa usa essa lista e descarta respostas de cálculo anteriores à mudança das paradas.

## Banco de dados

Migração aplicada ao banco configurado no backend: `supabase/migrations/20261105150000_identificar_pontos_sugeridos.sql`.
Foram preservados os 87 pontos existentes; seis foram identificados como sugestões. Nenhuma reserva ou pagamento foi alterado para teste.
Pontos legados sem evidência da sugestão são conservados como originais. A origem dos novos pontos passa a ser persistente, inclusive se a solicitação for reutilizada.

## Arquivos desta alteração

| Arquivo | Linhas antes | Linhas depois |
|---|---:|---:|
| [backend/database/postgres/estrutura/schema.sql](C:/TCC/CaronaUniversitariaTCC/backend/database/postgres/estrutura/schema.sql) | 842 | 843 |
| [backend/src/caronas/capacidade-carona.spec.ts](C:/TCC/CaronaUniversitariaTCC/backend/src/caronas/capacidade-carona.spec.ts) | 418 | 422 |
| [backend/src/caronas/caronas.module.ts](C:/TCC/CaronaUniversitariaTCC/backend/src/caronas/caronas.module.ts) | 52 | 56 |
| [backend/src/caronas/caronas.service.spec.ts](C:/TCC/CaronaUniversitariaTCC/backend/src/caronas/caronas.service.spec.ts) | 553 | 563 |
| [backend/src/caronas/caronas.service.ts](C:/TCC/CaronaUniversitariaTCC/backend/src/caronas/caronas.service.ts) | 662 | 671 |
| [backend/src/caronas/inicio-com-pagamentos.spec.ts](C:/TCC/CaronaUniversitariaTCC/backend/src/caronas/inicio-com-pagamentos.spec.ts) | Novo | 116 |
| [backend/src/caronas/pagamentos-inicio.spec.ts](C:/TCC/CaronaUniversitariaTCC/backend/src/caronas/pagamentos-inicio.spec.ts) | Novo | 52 |
| [backend/src/caronas/pagamentos-inicio.ts](C:/TCC/CaronaUniversitariaTCC/backend/src/caronas/pagamentos-inicio.ts) | Novo | 32 |
| [backend/src/caronas/ponto-embarque.entity.ts](C:/TCC/CaronaUniversitariaTCC/backend/src/caronas/ponto-embarque.entity.ts) | 60 | 63 |
| [backend/src/caronas/pontos-percurso.spec.ts](C:/TCC/CaronaUniversitariaTCC/backend/src/caronas/pontos-percurso.spec.ts) | Novo | 92 |
| [backend/src/caronas/pontos-percurso.ts](C:/TCC/CaronaUniversitariaTCC/backend/src/caronas/pontos-percurso.ts) | Novo | 53 |
| [backend/src/caronas/progresso-carona.service.ts](C:/TCC/CaronaUniversitariaTCC/backend/src/caronas/progresso-carona.service.ts) | 78 | 76 |
| [backend/src/pagamentos/FLUXO.md](C:/TCC/CaronaUniversitariaTCC/backend/src/pagamentos/FLUXO.md) | 33 | 54 |
| [backend/src/solicitacoes/expiracao-solicitacoes.service.ts](C:/TCC/CaronaUniversitariaTCC/backend/src/solicitacoes/expiracao-solicitacoes.service.ts) | 174 | 176 |
| [backend/src/solicitacoes/solicitacoes.module.ts](C:/TCC/CaronaUniversitariaTCC/backend/src/solicitacoes/solicitacoes.module.ts) | 29 | 28 |
| [backend/src/solicitacoes/solicitacoes.service.spec.ts](C:/TCC/CaronaUniversitariaTCC/backend/src/solicitacoes/solicitacoes.service.spec.ts) | 549 | 550 |
| [backend/src/solicitacoes/solicitacoes.service.ts](C:/TCC/CaronaUniversitariaTCC/backend/src/solicitacoes/solicitacoes.service.ts) | 523 | 524 |
| [frontend/lib/home/corrida_em_andamento.dart](C:/TCC/CaronaUniversitariaTCC/frontend/lib/home/corrida_em_andamento.dart) | 376 | 378 |
| [frontend/lib/mapa/services/progresso_corrida.dart](C:/TCC/CaronaUniversitariaTCC/frontend/lib/mapa/services/progresso_corrida.dart) | 125 | 140 |
| [frontend/lib/mapa/widgets/mapa_navegacao_carona.dart](C:/TCC/CaronaUniversitariaTCC/frontend/lib/mapa/widgets/mapa_navegacao_carona.dart) | 253 | 278 |
| [frontend/lib/models/carona.dart](C:/TCC/CaronaUniversitariaTCC/frontend/lib/models/carona.dart) | 198 | 228 |
| [frontend/test/mapa_navegacao_carona_test.dart](C:/TCC/CaronaUniversitariaTCC/frontend/test/mapa_navegacao_carona_test.dart) | 197 | 285 |
| [frontend/test/progresso_corrida_test.dart](C:/TCC/CaronaUniversitariaTCC/frontend/test/progresso_corrida_test.dart) | 177 | 196 |
| [supabase/migrations/20261105150000_identificar_pontos_sugeridos.sql](C:/TCC/CaronaUniversitariaTCC/supabase/migrations/20261105150000_identificar_pontos_sugeridos.sql) | Novo | 17 |

Os arquivos de produção que já ultrapassavam 500 linhas são os serviços de caronas e solicitações. As regras novas ficaram em auxiliares pequenos; não houve uma reorganização geral do projeto.

## Verificação

- Backend: 735 testes passaram; build passou.
- Lint dos arquivos TypeScript alterados: sem problemas.
- Flutter: análise sem problemas; 34 testes específicos e a bateria completa com 1.985 testes passaram.
- Consultas novas e mapeamentos TypeORM conferidos no PostgreSQL em transação READ ONLY, com identificadores fictícios.

## Publicação e teste no celular

A migração já foi aplicada antes da publicação do código e é compatível com a versão anterior. Após o push, aguarde a conclusão do deploy do backend antes de testar com o aplicativo atualizado.
Para testar o comportamento novo, é necessário publicar o backend e reinstalar o app atualizado.

Cenários: pagamento simulado confirmado permite iniciar; aceite sem pagamento bloqueia; reserva vencida sem cobrança libera vaga; resultado incerto preserva reserva; cancelamento de quem sugeriu um ponto mantém a parada quando outro aceito a utiliza; saída do último usuário remove a parada do percurso, mantendo originais e histórico.
