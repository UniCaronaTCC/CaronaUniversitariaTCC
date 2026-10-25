# Veiculo publicado

Aplicar `supabase/migrations/20261025013617_preservar_veiculo_carona.sql`
antes de implantar o backend que utiliza `Carona.veiculoPublicado`.
A migracao e aditiva e deve ser aplicada uma unica vez, em transacao.
O backend anterior continua funcionando com a coluna adicional.
Nao usar `supabase db push` indiscriminadamente: as demais atualizacoes deste
projeto foram mantidas nos scripts SQL anteriores.

Cada nova carona, inclusive ocorrencias geradas, captura modelo, cor e placa
do perfil. Caronas ja publicadas nunca recebem alteracoes do veiculo do perfil.
A API continua devolvendo `usuario.veiculo`, com a placa mascarada.

O preenchimento inicial das caronas existentes utiliza o cadastro disponivel
na migracao. Nao e possivel reconstruir trocas feitas antes dela. Se nao ha
veiculo associado, o registro permanece nulo e a API nao inventa um substituto.

O backend impede a troca quando existem caronas em andamento ou caronas
validas com passageiros aceitos. Salvar os mesmos dados continua permitido.
Caronas encerradas, canceladas ou vencidas nao bloqueiam novas alteracoes.
O teste `backend/test/veiculo-publicado-banco.sql` usa fixtures sinteticas
e ROLLBACK, sem manter dados de teste.
O teste opt-in `node -r ts-node/register test/veiculo-service-banco.ts`,
executado na pasta backend, verifica tambem o UsersService real usando o .env
local. Ele nao inicia os jobs do app e reverte suas fixtures em finally.

Validacao no celular, apos deploy e atualizacao do APK:
1. Publicar carona com veiculo A, sem passageiros aceitos.
2. Trocar para veiculo B: a carona anterior continua A; nova publicacao usa B.
3. Aceitar passageiro em carona valida: trocar o veiculo deve exibir bloqueio.
4. Iniciar carona: a troca continua bloqueada.
5. Encerrar/cancelar as caronas impeditivas: a troca volta a ser permitida.
6. Conferir detalhes e historico em ambas as contas: nao exibir placa completa.
