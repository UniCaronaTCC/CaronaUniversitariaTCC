# Conferencia de CNH do TCC

## Fluxo

O usuario abre Perfil > Habilitacao > Verificar CNH, ou tenta oferecer uma
carona. Aceita o uso dos dados, fotografa frente e verso pela camera e envia.
Pode revisar e refazer as fotos antes de enviar.

Na verificacao, informa `nomeCompleto` conforme o documento. Esse nome e
comparado integralmente com o OCR, tolerando acentos, espacos e quebras de
linha. Nao altera o nome de exibicao do perfil e nao e persistido nem logado.
O endpoint exige esse campo multipart junto com `aceitePrivacidade`.
Atualizar backend e app juntos; clientes antigos recebem orientacao para
atualizar. A conferencia continua sem comprovar titularidade ou autenticidade.

Recusas retornam `dados.motivo` e uma `mensagem` especifica para o campo.
Logs contem apenas etapas, codigo de recusa e duracao, nunca texto do OCR,
nome, CPF ou fotos. O app exibe a mensagem da resposta. O motivo nao e salvo
no banco; ao reabrir o perfil, apenas o status permanece disponivel.

O Flutter envia as duas imagens e `aceitePrivacidade=true` para
`POST /usuarios/cnh/verificar` com o token da sessao. O backend confere os dados
por OCR, grava APROVADA ou RECUSADA e descarta as imagens. O app atualiza o perfil.
Falha de conexao permite repetir o envio; recusa exige novas fotos.

## Publicacao

O backend exige CNH APROVADA, categoria B/C/D/E (ou AB/AC/AD/AE) e validade
vigente para criar caronas avulsas ou programacoes recorrentes. Usa o dia de
Sao Paulo. Retorna HTTP 403 com `codigo=CNH_NAO_APROVADA` quando nao autorizado.

A geracao automatica de novas datas tambem confere a CNH. Programacoes sem
habilitacao vigente nao geram novas caronas. Pausar continua permitido; retomar
uma programacao ativa exige a conferencia. Caronas ja criadas sao preservadas.

## Teste manual no celular

1. Atualize e rode o backend e o app. Nao precisa de ngrok para a CNH.
2. Com um usuario sem CNH aprovada, tente oferecer uma carona: deve aparecer
   a entrada para verificar a CNH.
3. Abra a verificacao. Sem aceitar o aviso, a camera e o envio ficam desativados.
4. Aceite, fotografe a frente e o verso completos, nitidos e sem reflexos.
5. Confira as previas e envie. Com dados compativeis, aparece CNH conferida.
6. Conclua: o formulario de oferta deve abrir. Ainda e necessario ter veiculo.
7. No perfil, confira categoria e validade. Abrir novamente nao exige novas fotos.
8. Teste fotos ilegiveis: deve pedir novas fotos. Teste sem rede: deve permitir
   tentar novamente. A aprovacao fica no banco e continua apos reiniciar o app.

Fotos de teste usadas por testes automatizados sao sinteticas. Nao coloque
fotos reais, CPF, token ou documentos pessoais no repositorio.

## Limite desta etapa

OCR confere o texto apresentado; autenticidade oficial fica para a futura
integracao com o Vio. O teste manual com CNH real ainda e necessario para
avaliar a leitura nos modelos fisicos de documento usados pelos participantes.
