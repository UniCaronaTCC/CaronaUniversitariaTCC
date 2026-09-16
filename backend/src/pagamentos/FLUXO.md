# Fluxo de pagamentos do TCC

## Aceite e prazo

O motorista aceita a solicitação, a vaga fica reservada provisoriamente e o passageiro tem até 1 hora para pagar, respeitando o horário de início da carona.

## Pix

O Pix é gerado apenas quando o passageiro toca em **Pagar com Pix**. Após a geração, ele é válido por até 30 minutos, sem ultrapassar o prazo da solicitação.

## Confirmação

O webhook confirma o pagamento. A vaga e a participação passam a ser definitivas, e a tela mostra a confirmação ao passageiro.

## Expiração

Se o prazo terminar sem pagamento, a solicitação expira e a vaga é liberada. Confirmações recebidas após a expiração também deverão ser tratadas, evitando que alguém pague sem possuir uma vaga.

## Início do percurso

O motorista pode iniciar o percurso mesmo que existam pagamentos pendentes. O aplicativo avisa sobre passageiros que não pagaram e remove essas participações antes de iniciar.

## Cancelamento

Antes do pagamento, o cancelamento apenas libera a vaga. Depois do pagamento, o sistema solicita o reembolso integral no sandbox e apresenta o resultado.

## Registro mínimo

O banco deve armazenar os prazos e os estados de pagamento, expiração e reembolso, aproveitando o registro de eventos de webhook já existente.

## Fora do escopo

Nesta etapa do TCC, não serão implementados carteira, saque, split, taxa real da plataforma, ambiente de produção ou pagamento de caronas recorrentes.