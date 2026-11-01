# Corridas encerradas por tempo

Aplicar somente `supabase/migrations/20261030140000_encerrar_corridas_por_tempo.sql`
antes do deploy do backend. A migracao adiciona `caronas.iniciada_em`, um gatilho
que registra o inicio real e a funcao usada na limpeza. O backend anterior
continua compativel com essa estrutura. Nao executar `supabase db push` para
aplicar outras migracoes por engano.

O banco registra o primeiro inicio pelo horario do servidor e impede que uma
edicao ou um reenvio reinicie a contagem. Depois de 12 horas a corrida passa
para `ENCERRADA_POR_TEMPO`, preservando passageiros aceitos, pagamentos e os
pontos efetivamente percorridos. Pedidos ainda pendentes expiram. A posicao
atual e removida; novas atualizacoes de GPS ou progresso sao bloqueadas.

Corridas antigas sem `iniciada_em` usam o horario agendado acrescido de duas
horas (ultimo inicio permitido pela regra existente), mais as 12 horas de
duracao. O fuso da agenda e America/Sao_Paulo. O horario original de inicio
dessas corridas permanece nulo, pois nao pode ser reconstruido.

A verificacao ocorre na inicializacao do backend, a cada minuto e antes de
consultas/operacoes de corrida. Se a hospedagem suspender o servidor, a limpeza
ocorre quando ele voltar. Nao e necessario manter o aplicativo aberto.

Instalar tambem o frontend atualizado, que retira essas corridas da lista de
ativas, mostra o motivo no historico e encerra o acompanhamento da viagem.
O status automatico e diferente de FINALIZADA e nao habilita avaliacao de
viagem concluida. Os gatilhos de estado das conversas ja existentes reconhecem
esse status como encerrado.

Validacao: `npm test -- --runInBand` e
`node test/encerramento-corridas-banco.cjs`, executados em backend/.
O segundo teste usa PostgreSQL com um esquema isolado, dados ficticios e
ROLLBACK inclusive da estrutura, sem consultar ou alterar corridas reais.
