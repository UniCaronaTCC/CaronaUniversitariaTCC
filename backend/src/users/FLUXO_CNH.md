# Conferencia de CNH com ML Kit

O Flutter usa google_mlkit_text_recognition (SDK nativo do Google) no Android e
no iPhone. A leitura usa somente a frente, onde estao nome, CPF, validade e
categoria. Camera guiada e galeria com rotacao/recorte continuam disponiveis.
A imagem e decodificada para normalizar orientacao. Se faltarem rotulos, sao
tentadas ate quatro orientacoes no mesmo leitor. Campos de fotos ou orientacoes
diferentes nunca sao combinados. Nao ha reconhecimento de texto no servidor.

## Contrato

POST /usuarios/cnh/verificar-mlkit, autenticado, Content-Type application/json:
- versaoLeitura: mlkit-v1
- aceitePrivacidade: boolean true
- leitura: { largura, altura, linhas: [{ palavras: [{ texto, x0, y0, x1, y1 }] }] }

O usuario vem do JWT, nunca do corpo. O servidor valida dimensoes, limites,
tipos e coordenadas e extrai os campos pelas posicoes/rotulos. Nao aceita um
objeto com campos ja aprovados nem um status fornecido pelo cliente. O nome é apenas uma extração opcional, sem comparação com o perfil ou com texto
digitado. Caixas de palavras inteiras podem ultrapassar a região estimada sem
recusa; não alteramos letras nem dígitos reconhecidos no nome. CPF passa no
checksum, validade exige calendario real e nao vencida, categoria deve permitir
carro. CPF duplicado entre contas continua bloqueado. Campo ambiguo e recusado.

## Privacidade e limites

Fotos nao sao enviadas ao backend. A foto temporaria local usada pelo plugin e
removida ao concluir, inclusive em falhas. Não persistimos o texto completo da
leitura e não imprimimos dados do documento nos logs. Guardamos CPF, categoria,
validade, consentimento e estado/data da conferência. Os campos opcionais abaixo
exigem uma atualização aditiva do banco antes de publicar esta versão.

IMPORTANTE: o OCR recebido do celular pode ser adulterado. Estas regras conferem
coerencia dos dados para o TCC e nao comprovam autenticidade, titularidade,
suspensao ou autorizacao oficial para dirigir. Nao existe consulta ao Detran.
Uma verificacao de identidade confiavel exige um servico/procedimento proprio.

Nome extraído e número completo de registro são opcionais e salvos em
cnh_nome e cnh_registro, sem modificar o nome do perfil. Registro é extraído
somente abaixo do rótulo REGISTRO, sem reutilizar o CPF como alternativa.
Ausência desses campos não impede a aprovação. GET /usuarios/cnh/dados exige
JWT e devolve esses dois dados apenas da conta autenticada; consultas normais
de usuários omitem as colunas privadas. Reiniciar o teste apaga esses campos.

Antes de publicar esta versão, executar no banco PostgreSQL:
database/postgres/atualizacoes/adicionar_dados_extraidos_cnh.sql.
Não é possível reconstruir esses dados em contas aprovadas anteriormente,
pois a foto e o texto completo do OCR não são guardados. Uma nova leitura é
necessária para preencher campos antigos; não reiniciamos contas automaticamente.

## Publicacao e testes

Publicar backend e reinstalar o app juntos: o antigo envio multipart de fotos
foi removido. Apps antigos recebem orientacao de atualizar; nao ha fallback.
Android: compilar APK apos instalar dependencias Flutter.
iOS: alvo 15.5+, instalar pods e compilar/testar em Mac/Xcode. O plugin Flutter
e mantido pela comunidade; o reconhecimento executa no SDK nativo do Google.

Testes unitarios cobrem extracao espacial, campos ambiguos, CPF, nome, validade,
categoria e privacidade; teste HTTP usa modulos simulados sem banco real.
Testar novas capturas e fotos que falharam anteriormente em aparelhos reais.
Compilacao e testes simulados nao comprovam qualidade do OCR em cada aparelho.

Reinicio de CNH para QA: POST /usuarios/cnh/reiniciar-teste preservado. Continua
bloqueado com ofertas/recorrencias ativas. Remover esse recurso antes da entrega.
