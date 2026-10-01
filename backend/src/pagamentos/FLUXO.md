# Fluxo de pagamentos do TCC

## Aceite e prazo

O motorista aceita a solicitação, a vaga fica reservada provisoriamente e o passageiro tem até 2 horas para pagar, respeitando o limite de 15 minutos antes do início da carona.

## Pix

O Pix é gerado apenas quando o passageiro toca em **Pagar com Pix** e expira junto com o prazo da solicitação. Assim, existe um único prazo de pagamento, de no máximo 2 horas após o aceite e sempre respeitando o início da carona.

## Confirmação

O webhook confirma o pagamento. A vaga e a participação passam a ser definitivas, e a tela mostra a confirmação ao passageiro.

## Expiração

Se o prazo terminar sem pagamento, o backend verifica as cobranças pendentes com a AbacatePay, expira a solicitação e libera a vaga. Se o provedor ainda indicar pagamento pendente ou a criação for incerta, a vaga permanece reservada até haver certeza. Confirmações recebidas após a expiração ainda deverão ser tratadas, evitando que alguém pague sem possuir uma vaga.

## Início do percurso

O motorista pode iniciar o percurso mesmo que existam pagamentos pendentes. O aplicativo avisa sobre passageiros que não pagaram e remove essas participações antes de iniciar.

## Cancelamento

Antes do pagamento, o cancelamento apenas libera a vaga. Depois do pagamento, o sistema solicita o reembolso integral no sandbox e apresenta o resultado.

## Registro mínimo

O banco deve armazenar os prazos e os estados de pagamento, expiração e reembolso, aproveitando o registro de eventos de webhook já existente.

## Fora do escopo

Nesta etapa do TCC, não serão implementados carteira, saque, split, taxa real da plataforma, ambiente de produção ou pagamento de caronas recorrentes.
