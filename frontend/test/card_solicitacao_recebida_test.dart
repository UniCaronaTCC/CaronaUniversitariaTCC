import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uni_carona/models/solicitacao_recebida.dart';
import 'package:uni_carona/widgets/card_solicitacao_recebida.dart';

void main() {
  test('lê o status da carona na solicitação recebida', () {
    final solicitacao = SolicitacaoRecebida.fromJson({
      'id': 1,
      'status': 'ACEITA',
      'localEmbarque': 'Rua A, 100',
      'embarqueLatitude': -21.2,
      'embarqueLongitude': -50.4,
      'passageiro': {'id': 2, 'nome': 'Maria'},
      'carona': {
        'id': 3,
        'destino': 'UniSalesiano',
        'dataInicio': '2026-08-10',
        'horario': '19:00:00',
        'status': 'FINALIZADA',
      },
    });

    expect(solicitacao.caronaFinalizada, isTrue);
  });

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

  testWidgets('permite avaliar passageiro depois da carona', (tester) async {
    var avaliou = false;
    final solicitacao = SolicitacaoRecebida(
      id: 1,
      status: 'ACEITA',
      localEmbarque: 'Rua A, 100',
      embarqueLatitude: -21.2,
      embarqueLongitude: -50.4,
      passageiro: 'Maria',
      idCarona: 2,
      destino: 'UniSalesiano',
      dataInicio: DateTime(2026, 7, 22),
      horario: '19:00:00',
      podeAvaliar: true,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CardSolicitacaoRecebida(
            solicitacao: solicitacao,
            processando: false,
            onAceitar: () {},
            onRecusar: () {},
            onAvaliar: () => avaliou = true,
          ),
        ),
      ),
    );

    await tester.tap(find.text('AVALIAR'));

    expect(avaliou, isTrue);
    expect(find.text('ACEITAR'), findsNothing);
    expect(find.text('RECUSAR'), findsNothing);
  });

  testWidgets('deixa cinza a solicitação de uma carona finalizada', (
    tester,
  ) async {
    final solicitacao = SolicitacaoRecebida(
      id: 3,
      status: 'PENDENTE',
      localEmbarque: 'Rua A, 100',
      embarqueLatitude: -21.2,
      embarqueLongitude: -50.4,
      passageiro: 'Maria',
      idCarona: 4,
      destino: 'UniSalesiano',
      dataInicio: DateTime(2026, 7, 22),
      horario: '19:00:00',
      statusCarona: 'FINALIZADA',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CardSolicitacaoRecebida(
            solicitacao: solicitacao,
            processando: false,
            onAceitar: () {},
            onRecusar: () {},
          ),
        ),
      ),
    );

    final material = tester.widget<Material>(
      find.byKey(const ValueKey('card-solicitacao-3')),
    );

    expect(material.color, const Color(0xFFF1F1F1));
    expect(find.text('FINALIZADA'), findsOneWidget);
    expect(find.text('ACEITAR'), findsNothing);
    expect(find.text('RECUSAR'), findsNothing);
  });
}
