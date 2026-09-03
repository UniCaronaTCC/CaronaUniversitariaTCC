import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uni_carona/models/solicitacao_enviada.dart';
import 'package:uni_carona/widgets/card_solicitacao_enviada.dart';

void main() {
  test('lê o status da carona enviado pelo backend', () {
    final solicitacao = SolicitacaoEnviada.fromJson({
      'id': 1,
      'status': 'ACEITA',
      'localEmbarque': 'Praça central',
      'motorista': {'id': 2, 'nome': 'Henrique'},
      'carona': {
        'id': 3,
        'destino': 'UniSalesiano',
        'dataInicio': '2026-08-10',
        'horario': '19:00:00',
        'valor': 12.5,
        'status': 'FINALIZADA',
      },
    });

    expect(solicitacao.caronaFinalizada, isTrue);
  });

  testWidgets('mostra motorista, status e dados da carona solicitada', (
    tester,
  ) async {
    var avaliou = false;
    final solicitacao = SolicitacaoEnviada(
      id: 1,
      status: 'ACEITA',
      localEmbarque: 'Praça central',
      motorista: 'Henrique',
      idCarona: 2,
      destino: 'UniSalesiano',
      dataInicio: DateTime(2026, 7, 25),
      horario: '19:00:00',
      valor: 12.5,
      podeAvaliar: true,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CardSolicitacaoEnviada(
            solicitacao: solicitacao,
            onAvaliar: () => avaliou = true,
          ),
        ),
      ),
    );

    expect(find.text('Henrique'), findsOneWidget);
    expect(find.text('ACEITA'), findsOneWidget);
    expect(find.text('UniSalesiano'), findsOneWidget);
    expect(find.text('Praça central'), findsOneWidget);
    expect(find.text('R\$ 12,50'), findsOneWidget);
    expect(find.text('AVALIAR'), findsOneWidget);

    await tester.tap(find.text('AVALIAR'));
    expect(avaliou, isTrue);
  });

  testWidgets('deixa cinza a carona finalizada como passageiro', (
    tester,
  ) async {
    final solicitacao = SolicitacaoEnviada(
      id: 3,
      status: 'ACEITA',
      localEmbarque: 'Praça central',
      motorista: 'Henrique',
      idCarona: 4,
      destino: 'UniSalesiano',
      dataInicio: DateTime(2026, 7, 25),
      horario: '19:00:00',
      valor: 12.5,
      statusCarona: 'FINALIZADA',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: CardSolicitacaoEnviada(solicitacao: solicitacao)),
      ),
    );

    final material = tester.widget<Material>(
      find.byKey(const ValueKey('card-pedido-3')),
    );

    expect(material.color, const Color(0xFFF1F1F1));
    expect(find.text('FINALIZADA'), findsOneWidget);
    expect(find.text('ACEITA'), findsNothing);
  });

  testWidgets('permite cancelar participação aceita', (tester) async {
    var cancelou = false;
    final solicitacao = SolicitacaoEnviada(
      id: 5,
      status: 'ACEITA',
      localEmbarque: 'Praça central',
      motorista: 'Henrique',
      idCarona: 6,
      destino: 'UniSalesiano',
      dataInicio: DateTime(2026, 9, 25),
      horario: '19:00:00',
      valor: 12.5,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CardSolicitacaoEnviada(
            solicitacao: solicitacao,
            onCancelar: () => cancelou = true,
          ),
        ),
      ),
    );

    await tester.tap(find.text('CANCELAR PARTICIPAÇÃO'));
    expect(cancelou, isTrue);
  });

  testWidgets('oferece Pix somente para carona avulsa aceita', (tester) async {
    var pagou = false;
    final solicitacao = SolicitacaoEnviada(
      id: 7,
      status: 'ACEITA',
      localEmbarque: 'Praça central',
      motorista: 'Henrique',
      idCarona: 8,
      destino: 'UniSalesiano',
      dataInicio: DateTime(2026, 9, 25),
      horario: '19:00:00',
      valor: 12.5,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CardSolicitacaoEnviada(
            solicitacao: solicitacao,
            onPagarPix: () => pagou = true,
          ),
        ),
      ),
    );

    await tester.tap(find.text('PAGAR COM PIX'));
    expect(pagou, isTrue);
  });

  testWidgets('nao oferece Pix para carona recorrente', (tester) async {
    final solicitacao = SolicitacaoEnviada(
      id: 9,
      status: 'ACEITA',
      localEmbarque: 'Praça central',
      motorista: 'Henrique',
      idCarona: 10,
      destino: 'UniSalesiano',
      dataInicio: DateTime(2026, 9, 25),
      horario: '19:00:00',
      valor: 12.5,
      recorrente: true,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CardSolicitacaoEnviada(
            solicitacao: solicitacao,
            onPagarPix: () {},
          ),
        ),
      ),
    );

    expect(find.text('PAGAR COM PIX'), findsNothing);
  });
}
