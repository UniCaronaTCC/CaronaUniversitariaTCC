# Fluxo de pagamentos do TCC

## Aceite e prazo

O motorista aceita a solicitação, a vaga fica reservada provisoriamente e o passageiro tem até 2 horas para pagar, respeitando o limite de 15 minutos antes do início da carona.

## Pix

O Pix é gerado apenas quando o passageiro toca em **Pagar com Pix** e expira junto com o prazo da solicitação. Assim, existe um único prazo de pagamento, de no máximo 2 horas após o aceite e sempre respeitando o início da carona.

## Confirmação

O webhook confirma o pagamento. A vaga e a participação passam a ser definitivas, e a tela mostra a confirmação ao passageiro.

## Expiração

Se o prazo terminar sem pagamento, o backend verifica as cobranças pendentes com a AbacatePay, expira a solicitação e libera a vaga. Se o provedor ainda indicar pagamento pendente ou a criação for incerta, a vaga permanece reservada até haver certeza. Confirmações recebidas após expiração ou cancelamento registram um estorno simulado, sem reativar a participação. O status PAID recebido do provedor é preservado no histórico.

## Início do percurso

Antes de iniciar, o backend verifica as reservas vencidas daquela carona. Depois, dentro da transação que bloqueia a carona, exige pagamento confirmado (PAID, inclusive simulado no Dev Mode) para todas as solicitações ainda ACEITAS. Havendo reserva não paga ou confirmação incerta, a partida é bloqueada com aviso. Reservas dentro do prazo não são removidas para antecipar a saída. Reservas vencidas só expiram quando for seguro concluir que não houve pagamento.

## Cancelamento

Antes da confirmação do pagamento, o cancelamento individual libera a vaga. Após PAID, motorista e passageiro não podem cancelar apenas aquela participação. O motorista pode cancelar a carona inteira antes de iniciá-la, mediante confirmação no aplicativo. Viagens em andamento ou encerradas não são canceladas por esse fluxo.

O cancelamento integral ocorre em uma transação: encerra pedidos pendentes e aceitos, preserva o histórico, registra estorno simulado de pagamentos Dev Mode confirmados e envia avisos aos passageiros e ao motorista. O aviso identifica claramente que não houve movimentação de dinheiro real. Repetir o cancelamento ou a confirmação não duplica esses registros.

Uma confirmação tardia, recebida por webhook ou conciliação, registra o estorno simulado sem reativar a reserva. A tentativa guarda `participacao_encerrada_em` mesmo antes da confirmação; assim, reutilizar a solicitação não permite pagar a nova reserva com um Pix antigo. `estorno_simulado_em` só é preenchido após PAID em Dev Mode. Confirmação e cancelamento concorrentes bloqueiam a mesma tentativa no PostgreSQL.

Isso não revoga um Pix no provedor e não executa reembolso financeiro real. A implantação exige aplicar `supabase/migrations/20261106120000_cancelamento_estorno_simulado.sql` antes do novo backend. A migração regulariza tentativas de participações já canceladas/expiradas sem emitir avisos retroativos.

## Registro mínimo

O banco armazena prazos, tentativas de pagamento, expiração e eventos de webhook. O estorno do protótipo é um registro local separado do estado do provedor; não existe fluxo financeiro de reembolso real.

## Fora do escopo

Nesta etapa do TCC, não serão implementados carteira, saque, split, taxa real da plataforma, ambiente de produção ou cobrança única de uma programação recorrente. Cada ocorrência moderna é uma carona independente e pode usar o pagamento simulado.

## Paradas após cancelamento ou expiração

Um ponto criado por sugestão de passageiro recebe origem persistente em
`sugerido_por_passageiro`. Em caronas ativas ou em andamento, esse ponto só
participa do percurso se houver solicitação ACEITA vinculada, ou se já tiver
sido percorrido. A reserva aceita mantém o ponto enquanto aguarda pagamento,
inclusive quando o resultado no provedor é incerto. Outro passageiro aceito no
mesmo ponto o preserva após a saída do autor da sugestão.

Pontos originais do motorista e registros do histórico são preservados. A
seleção do percurso é aplicada às listagens, detalhes e progresso, sem apagar
pontos do banco. O motorista sincroniza o progresso a cada 30 segundos e ao
retomar o aplicativo; a navegação recalcula com os pontos recebidos, respeitando
o intervalo de 15 segundos entre cálculos. Falha de rede mantém o último estado
confirmado. O passageiro já consulta o progresso no acompanhamento.

A migração `supabase/migrations/20261105150000_identificar_pontos_sugeridos.sql`
deve ser aplicada antes de publicar o backend. Ela recupera a origem dos pontos
antigos quando ainda existe uma solicitação NOVO_SOLICITADO vinculada. Sem essa
evidência histórica, mantém o ponto como original por segurança.
