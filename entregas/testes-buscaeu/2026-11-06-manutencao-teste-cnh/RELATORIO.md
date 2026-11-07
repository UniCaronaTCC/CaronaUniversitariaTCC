# Manutenção do teste HTTP da CNH

Data: 06/11/2026. Base local: `desenvolvimento`, commit `83944d8`, com os ajustes anteriores de cancelamento/estorno ainda locais e preservados. A referência histórica da skill foi adaptada ao contrato atual, que já não pede nome digitado.

## Alteração

O teste HTTP ainda exigia que o serviço recebesse o nome digitado como terceiro argumento. Foi reproduzida uma falha: esperado `(42, leitura, nome)`, recebido `(42, leitura)`. Os outros cinco testes existentes passaram. O contrato atual do aplicativo usa a leitura ML Kit e a conta autenticada, conforme o controller.

A expectativa foi atualizada e foram cobertos os dois endereços compatíveis de envio, um nome legado ignorado e as três formas inválidas de aceite. A nova tarefa `npm run test:cnh:http` executa exclusivamente esse arquivo; o workflow do GitHub a chama depois dos testes habituais.

O módulo de teste usa o controller e o guard reais, com autenticação e serviço de CNH simulados. Os exemplos são inteiramente fictícios. A aprovação retornada pelo serviço é um mock: esta suíte verifica o recebimento HTTP, não a extração real da imagem ou a autenticidade de uma CNH. Não inicializa AppModule, banco, jobs ou serviços externos.

## Resultados

| ID | Requisito/fonte | Camada | Preparação | Ação | Esperado | Observado | Estado | Evidência |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| CNH-HTTP-01 | Contrato atual / controller | HTTP com serviços simulados | Conta fictícia autenticada e leitura sem nome digitado | POST verificar | 201, serviço recebe conta 42 e leitura | Resultado esperado | PASSOU | `test:cnh:http` |
| CNH-HTTP-02 | Compatibilidade / controller | HTTP com serviços simulados | Mesmo exemplo | POST verificar-mlkit | 201, serviço recebe conta 42 e leitura | Resultado esperado | PASSOU | `test:cnh:http` |
| CNH-HTTP-03 | Remoção do nome digitado | HTTP com serviços simulados | Nome legado adicional no corpo | POST verificar-mlkit | Nome não é repassado para comparar com a CNH | Serviço recebe apenas dois argumentos | PASSOU | `test:cnh:http` |
| CNH-HTTP-04 | Aceite / PER-07 | HTTP com serviços simulados | Aceite ausente | Enviar leitura | 400, serviço não chamado | Resultado esperado | PASSOU | `test:cnh:http` |
| CNH-HTTP-05 | Aceite / PER-07 | HTTP com serviços simulados | Aceite false | Enviar leitura | 400, serviço não chamado | Resultado esperado | PASSOU | `test:cnh:http` |
| CNH-HTTP-06 | Aceite / PER-07 | HTTP com serviços simulados | Aceite como texto true | Enviar leitura | 400, serviço não chamado | Resultado esperado | PASSOU | `test:cnh:http` |
| CNH-HTTP-07 | Conta autenticada / PER-11 | HTTP com serviços simulados | Corpo tenta indicar outra conta | POST reiniciar-teste | Usa conta 42 da sessão fictícia | Resultado esperado | PASSOU | `test:cnh:http` |
| CNH-HTTP-08 | Autenticação / PER-11 | HTTP com serviços simulados | Sem autorização | POST reiniciar-teste | 401 e serviço não chamado | Resultado esperado | PASSOU | `test:cnh:http` |
| CNH-HTTP-09 | Autenticação / PER-11 | HTTP com serviços simulados | Basic inválido | POST reiniciar-teste | 401 e serviço não chamado | Resultado esperado | PASSOU | `test:cnh:http` |
| CNH-HTTP-10 | Autenticação / PER-11 | HTTP com serviços simulados | Bearer inválido | POST reiniciar-teste | 401 e serviço não chamado | Resultado esperado | PASSOU | `test:cnh:http` |
| CNH-HTTP-11 | Migração do envio antigo | HTTP com serviços simulados | Multipart com bytes fictícios | POST verificar | 400 e serviço não chamado | Resultado esperado | PASSOU | `test:cnh:http` |
| CNH-CI-01 | Inclusão na automação | Análise estática da configuração | JSON e YAML carregados com parser | Conferir script e passo | Executar somente o arquivo isolado | Configuração válida, comando exato confirmado | PASSOU | Verificação local da configuração |
| CNH-CI-02 | Execução no GitHub | GitHub Actions | Após publicação das alterações | Executar workflow remoto | Novo passo da CNH executado | Ainda sem commit/push nesta etapa | NAO_EXECUTADO | Depende de push |
| CNH-APP-01 | Leitura no celular | E2E físico | Foto e aparelho reais | Executar OCR e envio completo | Fora da manutenção do teste | Não executado | FORA_DO_ESCOPO | Não é teste de OCR |

## Verificações complementares

- `npm run test:cnh:http`: 11 testes, 1 suíte, aprovados em 1,69 s.
- `node node_modules/jest/bin/jest.js --runInBand`: 751 testes, 51 suítes, aprovados em 9,66 s.
- `npm run build`: aprovado.
- ESLint e Prettier do arquivo de teste: aprovados.
- JSON de package.json e YAML do workflow: válidos. Nenhuma dependência alterada.
- Comparação SHA-256 dos arquivos existentes de controller, serviço, leitor e tela da CNH antes/depois: idênticos.
- Nenhuma conta, foto, registro de banco ou regra funcional foi alterada nesta manutenção.

## Arquivos alterados nesta etapa

1. `backend/test/verificacao-cnh.e2e-spec.ts`: contrato atual e regressões HTTP.
2. `backend/package.json`: comando dedicado e isolado.
3. `.github/workflows/ci.yml`: novo passo para esse comando.
4. `README.md`: explicação e comando local.

Os demais arquivos locais pertencem à alteração anterior de pagamento/cancelamento. A tipagem das fotos de perfil e a proteção do cálculo de rotas não foram modificadas. Nenhum commit, push, deploy ou reinstalação foi realizado nesta etapa.
