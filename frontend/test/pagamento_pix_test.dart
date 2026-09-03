import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uni_carona/home/pagamento_pix.dart';
import 'package:uni_carona/models/pagamento_pix.dart';

void main() {
  const pagamento = PagamentoPix(
    id: 30,
    idSolicitacao: 10,
    metodo: 'PIX',
    valorCentavos: 1250,
    statusCriacao: 'CONFIRMADA',
    status: 'PENDING',
    pixCopiaECola: 'codigo-pix-teste',
    qrCodeBase64: null,
    expiraEm: null,
    modoTeste: true,
  );

  test('converte a resposta segura do backend', () {
    final resultado = PagamentoPix.fromJson({
      'id': 30,
      'idSolicitacao': 10,
      'metodo': 'PIX',
      'valorCentavos': 1250,
      'statusCriacao': 'CONFIRMADA',
      'status': 'PENDING',
      'pixCopiaECola': 'codigo-pix-teste',
      'qrCodeBase64': null,
      'expiraEm': '2026-09-04T12:00:00.000Z',
      'modoTeste': true,
    });

    expect(resultado.valorCentavos, 1250);
    expect(resultado.pixDisponivel, isTrue);
    expect(resultado.modoTeste, isTrue);
  });

  test('recusa resposta que nao confirma o ambiente de teste', () {
    expect(
      () => PagamentoPix.fromJson({
        'id': 30,
        'idSolicitacao': 10,
        'metodo': 'PIX',
        'valorCentavos': 1250,
        'statusCriacao': 'CONFIRMADA',
        'modoTeste': false,
      }),
      throwsFormatException,
    );
  });

  testWidgets('mostra valor, sandbox, status e codigo Pix', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: PagamentoPixTela(pagamento: pagamento)),
    );

    expect(find.text('AMBIENTE DE TESTE'), findsOneWidget);
    expect(find.text(r'R$ 12,50'), findsOneWidget);
    expect(find.text('Aguardando pagamento'), findsOneWidget);
    expect(find.byKey(const ValueKey('codigo-pix')), findsOneWidget);
    expect(find.text('COPIAR CÓDIGO PIX'), findsOneWidget);
  });

  testWidgets('nao oferece outro Pix quando a tentativa esta incerta', (
    tester,
  ) async {
    const incerto = PagamentoPix(
      id: 31,
      idSolicitacao: 10,
      metodo: 'PIX',
      valorCentavos: 1250,
      statusCriacao: 'INCERTA',
      status: null,
      pixCopiaECola: null,
      qrCodeBase64: null,
      expiraEm: null,
      modoTeste: true,
    );

    await tester.pumpWidget(
      const MaterialApp(home: PagamentoPixTela(pagamento: incerto)),
    );

    expect(find.text('Confirmação pendente'), findsOneWidget);
    expect(find.text('COPIAR CÓDIGO PIX'), findsNothing);
  });
}
