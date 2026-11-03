# Foto do perfil no Android

O perfil abre um menu com camera, galeria e remocao. Remover exige confirmacao.
Cancelar o menu ou o seletor nao envia requisicao. O image_picker existente
abre a camera nativa, preferindo a frontal; a camera guiada da CNH nao e usada.
Os arquivos sao reduzidos a ate 1024 x 1024, qualidade 80, como no envio anterior.
Nao foram adicionadas dependencias, permissoes Android ou configuracoes iOS.

## Contrato e seguranca

- PATCH /usuarios/perfil/foto: multipart, campo foto, JWT obrigatorio.
- DELETE /usuarios/perfil/foto: JSON { fotoAtual: URL exibida }, JWT obrigatorio.
- Ambos retornam HTTP 200 com sucesso, mensagem e dados completos do perfil.
- DELETE usa somente a identidade do JWT. ID e caminho enviados pelo cliente
  nunca determinam a conta ou arquivo que sera excluido.
- Uma foto diferente da exibida produz 409, sem excluir a foto atual.
- UPDATE altera somente foto_perfil, comparando a URL antiga. Uma alteracao
  concorrente tambem produz 409. CNH, veiculo e instituicao sao preservados.
- DELETE repetido em perfil ja sem foto retorna sucesso, sem outra exclusao.

## Supabase

Reutiliza SUPABASE_URL, SUPABASE_SECRET_KEY e SUPABASE_PROFILE_BUCKET
(padrao fotos-perfil). Nao exige migracao: foto_perfil ja aceita NULL.
Nao exige mudanca no bucket ou abertura de policies para o aplicativo.
O cliente publico nao recebe permissoes de escrita/exclusao.

Novos arquivos usam usuarios/<id>/perfil-<uuid>, sem sobrescrever. Fotos antigas
em usuarios/<id>/perfil continuam compativeis. O backend valida origem, bucket,
pasta da propria conta e nome antes de excluir pela API Storage. Nunca aceita
uma URL arbitraria para excluir objetos de terceiros.

Depois de persistir a nova foto, o backend limpa a anterior. Se um conflito ou
usuario inexistente confirmar que o UPDATE nao gravou, tenta limpar apenas o
novo arquivo. Em falhas ambiguas de conexao, preserva o arquivo novo, pois ele
pode ja estar referenciado pelo banco, e registra a necessidade de verificacao.
Na remocao, limpa a referencia no
banco antes de excluir o arquivo, evitando restaurar uma URL sem arquivo em
caso de falha. Caminhos unicos impedem exclusao atrasada de upload mais recente.

Banco e Storage nao compartilham transacao. Se a limpeza falhar, a resposta
contem aviso explicito de limpeza incompleta, exibido em amarelo, e o backend
registra o ID da conta para verificacao. Nao existe fila automatica de limpeza:
um arquivo orfao pode exigir limpeza administrativa posterior. Como o bucket e
publico, excluir o original nao garante apagar copias/cache ja obtidos.

## Publicacao e validacao

Publicar o backend antes de testar a remocao com o novo APK. O envio antigo
permanece compativel. Sem deploy, a rota DELETE ainda nao existira no Render.

Testes locais: Jest foto-perfil, users.controller e users.service; Flutter
perfil_foto_test, perfil_test, perfil_avisos_test e auth_perfil_erros_test.
Os testes HTTP locais usam banco, autenticacao e Storage simulados.

Teste remoto opt-in: node test/foto-perfil-supabase.cjs --executar, no backend.
Le as credenciais locais sem imprimi-las e confere o projeto do TCC. Exige o ID
2147483000 livre e a pasta usuarios/2147483000 vazia. Usa um usuario sintetico
em transacao com rollback e uma imagem PNG sintetica; limpa os arquivos no fim.
Nao altera contas, imagens reais, bucket ou policies. Interromper o processo
externamente pode exigir conferir a pasta QA e limpar os arquivos sinteticos.

Validacao no celular: camera real, cancelamento, permissao negada, galeria,
remocao, reabertura e conferir foto nos cards e no chat apos atualizar as telas.
Processo Android encerrado durante a camera nao e coberto pelos testes de
widget: nao ha recuperacao automatica nem envio de imagens perdidas ao iniciar.
