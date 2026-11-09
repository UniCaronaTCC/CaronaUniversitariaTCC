# BuscaEu

Aplicativo de caronas universitárias desenvolvido como Trabalho de Conclusão de Curso de **Tecnologia em Desenvolvimento de Sistemas (TDS)**. Conecta estudantes para publicar e buscar caronas, solicitar vagas, combinar embarques, acompanhar viagens e avaliar os participantes.

> A versão utilizada na preparação da pré-banca está na branch `desenvolvimento`.

## Comece por aqui

- [Guia da Parte 4 — implementação e códigos](docs/PARTE_4_IMPLEMENTACAO.md)
- [Índice da documentação](docs/README.md)
- [Backend: módulos, configuração e testes](backend/README.md)
- [Aplicativo Flutter: estrutura e execução](frontend/README.md)
- [Banco de dados e histórico de scripts](backend/database/README.md)

## Tecnologias e responsabilidades

| Camada | Tecnologias | Responsabilidade |
|---|---|---|
| Aplicativo | Flutter e Dart | Interface, navegação, validações de entrada e consumo da API |
| Backend | Node.js, TypeScript e NestJS | Endpoints, autorização, regras de negócio e integrações |
| Persistência | TypeORM e PostgreSQL no Supabase | Entidades, relacionamentos, consultas e transações |
| Serviços gerenciados | Supabase Auth, Storage e Realtime | Autenticação e sessão, fotos e comunicação |
| Mapas e localização | OpenStreetMap, Photon, OpenRouteService e GPS | Mapa, pesquisa de locais, cálculo de rotas e acompanhamento |
| Leitura de CNH | Google ML Kit | OCR no dispositivo e conferência interna dos dados |
| Pagamento do protótipo | AbacatePay API v2 em Dev Mode | Pix simulado, confirmação e tratamento de reservas |

O aplicativo consome a API para as operações de negócio. O backend usa TypeORM para acessar o PostgreSQL; Auth, Storage e Realtime possuem responsabilidades próprias na integração com o Supabase.

## Organização

```text
frontend/              Aplicativo Flutter, recursos e testes
backend/src/           Módulos da API e testes unitários
backend/test/          Testes HTTP
backend/database/      Estrutura PostgreSQL, cargas e scripts históricos
supabase/migrations/   Migrações incrementais versionadas
docs/                  Índice técnico e guia de apresentação
entregas/              Relatórios de testes e evidências por data
output/diagramas/      Diagramas exportados
design/                Referências visuais
.github/workflows/     Integração contínua
```

## Funcionalidades

- Cadastro, confirmação de e-mail, login e recuperação de acesso.
- Perfil acadêmico, veículo, foto e conferência de CNH por OCR.
- Publicação, busca e programação de caronas recorrentes.
- Solicitação e aceite de vagas, pontos de embarque e prazos de reserva.
- Pix em ambiente de testes, mensagens e notificações internas.
- Acompanhamento de percurso, histórico e avaliações entre participantes.

## Executar e verificar

Consulte os pré-requisitos e a configuração nos READMEs do [backend](backend/README.md) e do [Flutter](frontend/README.md).

Backend:

```bash
cd backend
npm ci
npm test -- --runInBand
npm run test:cnh:http
npm run build
```

Aplicativo:

```bash
cd frontend
flutter pub get
flutter test
flutter analyze
flutter build apk --debug
```

O [workflow de CI](.github/workflows/ci.yml) executa testes unitários do backend, testes HTTP da CNH com dependências simuladas, build do backend, testes Flutter e build de APK debug. A análise estática do Flutter é um comando local separado no workflow atual. CI verde não substitui a validação integrada dos serviços externos.

## Limites da entrega acadêmica

O Pix opera em Dev Mode, sem dinheiro real; o estorno simulado é um registro local, sem reembolso financeiro. A CNH passa por OCR e conferência interna, sem consulta oficial de autenticidade. A placa recebe validação de formato. O acompanhamento GPS depende das permissões e do aplicativo em uso; não se presume rastreamento contínuo em segundo plano.

O nome BuscaEu identifica o produto. Identificadores técnicos existentes, como o pacote Dart `uni_carona` e o schema PostgreSQL `unicarona`, são mantidos por compatibilidade.
