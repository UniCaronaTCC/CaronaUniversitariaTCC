import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uni_carona/models/solicitacao_recebida.dart';
import 'package:uni_carona/widgets/card_solicitacao_recebida.dart';

void main() {
  testWidgets('permite aceitar e recusar solicitação pendente', (tester) async {
    var aceitou = false;
    var recusou = false;
    final solicitacao = SolicitacaoRecebida(
      id: 1,
      status: 'PENDENTE',
      localEmbarque: 'Rua A, 100',
      embarqueLatitude: -21.2,
      embarqueLongitude: -50.4,
      passageiro: 'Maria',
      idCarona: 2,
      destino: 'UniSalesiano',
      dataInicio: DateTime(2026, 7, 22),
      horario: '19:00:00',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CardSolicitacaoRecebida(
            solicitacao: solicitacao,
            processando: false,
            onAceitar: () => aceitou = true,
            onRecusar: () => recusou = true,
          ),
        ),
      ),
    );

    await tester.tap(find.text('ACEITAR'));
    await tester.tap(find.text('RECUSAR'));

    expect(aceitou, isTrue);
    expect(recusou, isTrue);
  });
}
