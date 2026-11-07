import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uni_carona/home/pagamento_pix.dart';
import 'package:uni_carona/models/pagamento_pix.dart';
import 'package:uni_carona/models/solicitacao_enviada.dart';
import 'package:uni_carona/models/solicitacao_recebida.dart';
import 'package:uni_carona/widgets/dialogo_cancelar_carona.dart';

Map<String, dynamic> pedido(String status) => {
  'id': 20,
  'status': status,
  'motorista': {'nome': 'Motorista fictício'},
  'passageiro': {'nome': 'Passageiro fictício'},
  'embarqueLatitude': -20.0,
  'embarqueLongitude': -50.0,
  'pagamentoConfirmado': true,
  'estornoSimulado': true,
  'carona': {
    'id': 10,
    'destino': 'Destino fictício',
    'dataInicio': '2030-01-01',
    'horario': '18:00',
    'valor': 1,
    'status': 'CANCELADA',
  },
};

void main() {
  test('cancelamento prevalece sobre PAID antigo nas duas visões', () {
    final enviada = SolicitacaoEnviada.fromJson(pedido('CANCELADA_MOTORISTA'));
    final recebida = SolicitacaoRecebida.fromJson(
      pedido('CANCELADA_MOTORISTA'),
    );
    expect(enviada.statusExibicao, 'CANCELADA_MOTORISTA');
    expect(recebida.statusExibicao, 'CANCELADA_MOTORISTA');
    expect(enviada.estornoSimulado, isTrue);
    expect(recebida.estornoSimulado, isTrue);
    expect(enviada.arquivada, isTrue);
    expect(enviada.podePagarPix, isFalse);
    expect(enviada.podeCancelar, isFalse);
    expect(recebida.podeCancelar, isFalse);
  });

  test(
    'carona cancelada não aparece confirmada com pedido ainda desatualizado',
    () {
      expect(
        SolicitacaoEnviada.fromJson(pedido('ACEITA')).statusExibicao,
        'CANCELADA_MOTORISTA',
      );
      expect(
        SolicitacaoRecebida.fromJson(pedido('ACEITA')).statusExibicao,
        'CANCELADA_MOTORISTA',
      );
    },
  );

  testWidgets('tela de estorno preserva PAID mas remove QR e nova simulação', (
    tester,
  ) async {
    final pagamento = PagamentoPix.fromJson({
      'id': 30,
      'idSolicitacao': 20,
      'metodo': 'PIX',
      'valorCentavos': 100,
      'statusCriacao': 'CONFIRMADA',
      'status': 'PAID',
      'modoTeste': true,
      'pixCopiaECola': 'codigo-ficticio',
      'estornoSimuladoEm': '2026-11-06T12:00:00Z',
    });
    expect(pagamento.status, 'PAID');
    expect(pagamento.pago, isFalse);
    expect(pagamento.aguardandoConfirmacao, isFalse);
    await tester.pumpWidget(
      MaterialApp(
        home: PagamentoPixTela(
          pagamento: pagamento,
          atualizarAutomaticamente: false,
        ),
      ),
    );
    expect(find.text('Estorno simulado registrado'), findsOneWidget);
    expect(find.text('Pagamento confirmado'), findsNothing);
    expect(find.text('SIMULAR PAGAMENTO'), findsNothing);
    expect(find.byKey(const ValueKey('codigo-pix')), findsNothing);
  });

  for (final confirmar in [false, true]) {
    testWidgets('diálogo só confirma quando escolhe cancelar: $confirmar', (
      tester,
    ) async {
      bool? resultado;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () async {
                  resultado = await confirmarCancelamentoCarona(context);
                },
                child: const Text('Abrir'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Abrir'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('sem movimentação de dinheiro real'),
        findsOneWidget,
      );
      expect(resultado, isNull);
      await tester.tap(find.text(confirmar ? 'CANCELAR CARONA' : 'VOLTAR'));
      await tester.pumpAndSettle();
      expect(resultado, confirmar);
    });
  }
}
