# Destinos de Aracatuba: lista e carga municipal

## O que esta preparado

- O aplicativo le `rotuloUnidade` e `enderecoCompleto`, mas continua aceitando a
  resposta anterior da API, sem esses campos.
- A lista mostra unidade e endereco, incluindo a variante de fonte ampliada.
- A pesquisa local encontra nome interno, sigla, unidade, rua, bairro e numero.
- A selecao conserva o ponto existente. Quando nao houver ponto, usa o endereco
  cadastrado para a busca e ainda exige confirmar um resultado; nao escolhe o
  primeiro resultado automaticamente.
- Nomes antigos continuam reconhecidos na deduplicacao de resultados proximos.
- Preferencias antigas nao sao reescritas. Ao selecionar novamente, sao salvos
  o novo titulo e o endereco. Para enderecos extensos, a descricao selecionada
  conserva o formato compacto anterior, respeitando o limite da carona.

## Carga preparada, nao aplicada nesta etapa

Arquivo: `backend/database/postgres/cargas/destinos_campi_aracatuba.sql`.

Identifica cada registro por codigo eMEC, nome interno, municipio e UF, nunca por
um ID gerado fixo. Preenche oito entradas existentes:

| Instituicao/unidade | Endereco | Ponto |
| --- | --- | --- |
| UniSALESIANO | Rodovia Senador Teotonio Vilela, 3821 | Preserva atual |
| UNIP Campus Baguacu | Avenida Baguacu, 1939 | Preserva atual |
| UNIP Polo Planalto | Rua Porangaba, 976 | Preserva atual; acesso ainda nao comprovado |
| UNESP Odontologia | Rua Jose Bonifacio, 1193 | Preserva atual |
| UNESP Veterinaria | Rua Clovis Pestana, 793 | Preserva atual |
| FAC-FEA | Rua Mauricio de Nassau, 1191 | Continua sem ponto aprovado |
| UniToledo Wyden | Rua Antonio Afonso de Toledo, 595 | Preenche par ausente com ponto institucional publicado |
| Fatec | Avenida Prestes Maia, 1764 | Continua sem ponto aprovado |

O SQL preserva os acentos das identidades e dos enderecos. Os rotulos sao de
apresentacao, nao alteram a nomenclatura interna usada pelos perfis.

A UniToledo publica `GeoCoordinates` (-21.21307519555, -50.430531988955) junto do
endereco da unidade. A carga usa o arredondamento de oito casas do esquema:
(-21.21307520, -50.43053199). Esse e um destino institucional, nao uma portaria
ou ponto de embarque comprovado. Se ja existir ponto, ele nao e substituido;
um par parcialmente preenchido tambem nao e combinado com metade do novo par.

A transacao valida que cada alvo exista uma unica vez e esteja ativo. Se houver
metadados diferentes dos propostos, cancela tudo em vez de sobrescrever. Usa
bloqueio curto para manter essas verificacoes e a atualizacao coerentes. Se o
banco estiver ocupado, respeita o timeout e exige nova tentativa. Reaplicada,
nao duplica nem reescreve linhas que ja estejam iguais.

Nao cria campi, nao muda coordenadas existentes, nao altera instituicoes,
usuarios, caronas, ACL/RLS ou registros de outra cidade/UF.

## Fontes institucionais

Conferidas na pesquisa de 01/11/2026; os pontos do UniToledo foram relidos no
JSON-LD da pagina oficial durante esta implementacao.

- [UniSALESIANO: contato](https://unisalesiano.com.br/aracatuba/contato/).
- [UNIP: enderecos](https://www.unip.br/prouni/) e
  [edital 2026/2](https://www.unip.br/regulamentos/assets/download/edital-processo-seletivo-2026-2.pdf).
- [UNESP Odontologia](https://www.foa.unesp.br/).
- [UNESP Veterinaria](https://www.fmva.unesp.br/).
- [FAC-FEA: contato](https://feata.edu.br/fale-conosco/).
- [UniToledo: unidade Jardim Sumare](https://wyden.com.br/polos-e-unidades/unitoledo-wyden-jardim-sumare-aracatuba-sp).
- [Fatec: Centro Paula Souza](https://www.cps.sp.gov.br/fatecs/fatec-aracatuba-prof-fernando-amaral-de-almeida-prado/).

## Pendencias deliberadas

- FAC-FEA e Fatec: endereco confirmado, coordenada ainda nao aprovada. Nao sera
  removida a confirmacao nesses casos apenas para esconder dados incompletos.
- UCESP/ESP: continuam intactas por divergencias de endereco/uso presencial.
- UNESP Odontologia na Rodovia: unidade adicional identificada na pesquisa,
  mas a insercao e o ponto ficam fora desta carga ate concluir a conferencia.
- UNIP Planalto: preservar o ponto atual nao certifica o acesso ao numero 976.

Portanto, esta carga nao promete selecao direta para todos os campi da cidade.

## Implantacao

1. Revisar o lote e conferir se os dados do banco ainda correspondem aos alvos.
2. Guardar os valores anteriores das oito linhas para eventual reversao manual.
3. Aplicar a migration `20261101202707_adicionar_metadados_destinos_campi.sql`.
4. Aplicar a carga municipal em transacao e conferir os oito registros.
5. Publicar o backend desta branch e depois gerar o APK atualizado.
6. No celular, selecionar novamente o destino e testar Home, filtros e oferta.

Nao fazer merge/deploy do backend antes da migration. Nenhum commit, push,
merge, deploy ou aplicacao no Supabase e feito automaticamente por estes arquivos.
Em caso de volta do backend, manter as colunas opcionais. Se desfizer dados,
usar o backup e verificar valores atuais para nao apagar correcoes posteriores.

## Testes reproduziveis

- `flutter test`: inclui formato antigo/novo, filtros por endereco, selecao sem
  consulta externa, confirmacao sem ponto, persistencia ao reabrir e telas
  estreitas com fonte ampliada e teclado.
- `node test/destinos-campi-banco.cjs` em `backend`, com
  `CAMPI_TEST_DATABASE_URL` explicitamente apontando para banco isolado. Nao
  carrega o `.env` do aplicativo. Cria somente um esquema `qa_campi_*` aleatorio
  e o remove ao final; nunca executar contra o banco de producao.
- O mesmo teste de carga foi executado via PGlite 0.5.14 em memoria, sem acesso
  remoto, cobrindo 11 cenarios: identidade por eMEC, preservacao de dados,
  escopo municipal, perfis/caronas, reaplicacao sem reescrita, ponto ja existente,
  ponto parcial, conflito, campus inativo/ausente e metadados vazios.

Teste isolado nao equivale a validacao manual no celular nem a verificacao de
permissoes/latencia do servidor. Aplicacao compartilhada e APK ficam para a
implantacao, apos revisao desta branch.

Resultado final em 01/11/2026, sobre a primeira etapa commitada como `cd12857`:

- 1.232 testes Flutter aprovados na suite completa, repetida apos a revisao.
- 615 testes do backend aprovados em 44 suites.
- 11 cenarios da carga em PostgreSQL em memoria aprovados e repetidos.
- Analise estatica de `lib` e `test` sem problemas; TypeScript de producao
  aprovado sem emissao de arquivos; diff sem marcas de conflito.
- Capturas revisadas em 390px/fonte normal e 320px/fonte 200%, com fontes reais
  de texto e icones. O gerador temporario de capturas foi removido do projeto.
- Nenhum arquivo de tela ou servico do Henrique foi refeito; alteracoes de
  producao do aplicativo ficam no modelo de campus e no componente compartilhado.

Nao houve aplicacao da migration/carga no Supabase, publicacao do backend,
geracao de APK ou teste no celular nesta etapa.
