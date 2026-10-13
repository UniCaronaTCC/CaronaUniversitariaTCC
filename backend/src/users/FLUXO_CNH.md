# Conferencia de CNH do TCC

## Reinicio temporario para testes

Recurso de QA a retirar antes da entrega: GET /usuarios/cnh/testes e
POST /usuarios/cnh/reiniciar-teste, autenticados e sem ID no corpo.
Por padrao fica desativado. No backend de testes do Render, habilitar:

```text
CNH_TEST_RESET_ENABLED=true
CNH_TEST_RESET_USER_IDS=1
```

A lista aceita IDs autorizados separados por virgula; nao sao tokens/chaves.
O botao "Reiniciar CNH (teste)" aparece na tela aprovada somente quando o
backend autoriza a conta. Exige confirmacao. Limpa somente campos de CNH
e consentimento; preserva usuario, foto, veiculo, pagamentos e historico.
Bloqueia enquanto houver leitura/reset em andamento neste processo,
ofertas ATIVA/LOTADA/EM_ANDAMENTO ou recorrencias ativas como motorista.
Nao cancela nem pausa nada automaticamente. Para testar nessa conta,
pausar recorrencias e resolver ofertas ativas primeiro.
Nao testar a mesma conta simultaneamente por dois backends diferentes.
A atualizacao usa transacao, bloqueio da linha e confere linhas afetadas.
Nao exige migracao. A configuracao precisa do deploy atualizado e o botao
precisa do app recompilado. Antes da entrega, remover rotas, metodos,
botao e variaveis; nao apenas esconder o botao.

## Fluxo

O usuario aceita o uso dos dados, informa o nome completo e escolhe fotos da
camera ou galeria. Depois de cada escolha, ajusta os quatro cantos do recorte
para deixar somente o documento inteiro, com letras na posicao de leitura.
Cancelar o recorte preserva a foto anterior. O original da galeria nao e apagado.
As setas de rotacao giram 90 graus e preservam a mesma area selecionada.
O recorte e feito em memoria, sem biblioteca nativa adicional. Exige ao menos
600 pixels no lado maior, 400 no menor e no maximo 5 MB por imagem.

O app continua enviando frente, verso, nomeCompleto e aceitePrivacidade para
POST /usuarios/cnh/verificar, com o token da sessao. O backend valida os dois
arquivos, mas le apenas a frente, onde ficam os quatro campos necessarios.
Nao exige nem extrai registro. A coluna cnh_registro_final continua nullable;
novas verificacoes gravam null. Nao e necessario executar migracao ou apagar
registros existentes.

## Leitura

O Tesseract usa segmentacao automatica e contraste adaptativo (Sauvola),
preservando a imagem colorida. As coordenadas dos rotulos delimitam nome,
CPF, validade e categoria, sem posicoes fixas para uma foto especifica.
Rotulos duplicados ou valores cortados/ambiguos sao recusados.

Se faltar um campo, ocorre no maximo uma releitura do pequeno recorte desse
campo, com ate duas tentativas de contraste no mesmo worker. CPF que falha no
checksum tambem recebe essa releitura. O recorte respeita rotulos unicos,
colunas vizinhas e molduras reconhecidas; nao estreita o campo horizontalmente
pelos digitos reconhecidos, pois a primeira leitura pode ter omitido digitos.
Todos os recortes recebem margem branca. Nome usa contraste Otsu; categoria
usa canal vermelho e a segunda tentativa de validade usa canal verde.
Nao ha substituicao de digitos,
preenchimento pelo nome informado ou escolha de datas sem rotulo.
Pequenas variacoes do rotulo de categoria podem localizar o recorte; a releitura
aceita valor sem repetir o rotulo somente dentro dessa regiao confirmada.
Valores ambiguos, linhas adicionais e rotulos duplicados continuam recusados.

Sem rotulos horizontais suficientes (nome e pelo menos dois outros campos),
o backend tenta ate quatro orientacoes da mesma frente. Nao combina campos
de orientacoes diferentes, nao usa o nome digitado para escolher a orientacao
e mantem o limite de dois workers simultaneos. Os buffers sao limpos ao final.

Nome deve corresponder integralmente ao informado, tolerando acentos e espacos.
CPF exige 11 digitos e checksum valido. Validade exige data real e nao vencida.
Categoria deve permitir carro: B/C/D/E ou AB/AC/AD/AE. O nome de perfil nao muda;
nome informado e fotos nao sao persistidos. Os buffers de preparo e recorte sao
limpos ao encerrar, inclusive em falhas.

O parser textual permanece para compatibilidade interna e testes. A leitura
real usa os campos espaciais e nao procura um campo ausente no texto geral.

## Logs e publicacao

CNH: campos_lidos informa somente true/false para cada campo.
CNH: diagnostico_nome informa contagens e resultado da comparacao.
Os logs nao incluem texto OCR, nomes, CPF, coordenadas ou fotos.
Falhas do processamento continuam distintas de uma recusa dos dados.

Atualizar backend e app para usar o recorte. O tempo em computador local nao
preve o tempo do Render gratuito; testar uma tentativa depois de deploy Live.
O fluxo nao consulta uma base oficial nem comprova autenticidade ou suspensao.
Outros modelos de documento e condicoes de captura ainda precisam de testes.

## Teste manual

1. Aceitar o aviso e escolher frente e verso na camera ou galeria.
2. Recortar o fundo sem cortar bordas, textos ou numeros da CNH.
3. Cancelar uma nova escolha e conferir que a previa anterior permanece.
4. Informar o nome completo e enviar; acompanhar campos_lidos nos logs.
5. Conferir aprovacao, categoria e validade no perfil.
6. Conferir recusa para nome divergente, CPF invalido, categoria A e vencimento.
7. Conferir nova tentativa apos falha de rede.
8. Girar uma selecao, conferir bordas e confirmar que o arquivo original nao muda.

Os testes automatizados usam dados sinteticos. Fotos reais autorizadas para
investigacao local nao devem ir para o repositorio, logs ou fixtures.
