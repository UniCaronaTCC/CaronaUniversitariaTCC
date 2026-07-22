import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uni_carona/models/solicitacao_enviada.dart';
import 'package:uni_carona/widgets/card_solicitacao_enviada.dart';

void main() {
  testWidgets('mostra motorista, status e dados da carona solicitada', (
    tester,
  ) async {
    final solicitacao = SolicitacaoEnviada(
      id: 1,
      status: 'ACEITA',
      localEmbarque: 'Praça central',
      motorista: 'Henrique',
      idCarona: 2,
      destino: 'UniSalesiano',
      dataInicio: DateTime(2026, 7, 25),
      horario: '19:00:00',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: CardSolicitacaoEnviada(solicitacao: solicitacao)),
      ),
    );

    expect(find.text('Henrique'), findsOneWidget);
    expect(find.text('ACEITA'), findsOneWidget);
    expect(find.text('UniSalesiano'), findsOneWidget);
    expect(find.text('Praça central'), findsOneWidget);
  });
}
