import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:uni_carona/home/pagamento_pix.dart';
import 'package:uni_carona/models/pagamento_pix.dart';
import 'package:uni_carona/services/auth_service.dart';
import 'package:uni_carona/services/pagamento_service.dart';

void main() {
  tearDown(() {
    AuthService.tokenUsuarioLogado = null;
  });

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
    expect(resultado.aguardandoConfirmacao, isTrue);
    expect(resultado.pago, isFalse);
    expect(resultado.modoTeste, isTrue);
  });

  test('nao disponibiliza o codigo Pix depois da confirmacao', () {
    final resultado = PagamentoPix.fromJson({
      'id': 30,
      'idSolicitacao': 10,
      'metodo': 'PIX',
      'valorCentavos': 1250,
      'statusCriacao': 'CONFIRMADA',
      'status': 'PAID',
      'pixCopiaECola': 'codigo-pix-teste',
      'qrCodeBase64': null,
      'expiraEm': null,
      'modoTeste': true,
    });

    expect(resultado.pago, isTrue);
    expect(resultado.pixDisponivel, isFalse);
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
      const MaterialApp(
        home: PagamentoPixTela(
          pagamento: pagamento,
          atualizarAutomaticamente: false,
        ),
      ),
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

  testWidgets('atualiza a tela quando o backend confirma o Pix', (
    tester,
  ) async {
    AuthService.tokenUsuarioLogado = 'token-teste';
    late http.Request requisicaoRecebida;
    final service = PagamentoService(
      cliente: MockClient((requisicao) async {
        requisicaoRecebida = requisicao;
        return http.Response(
          jsonEncode({
            'sucesso': true,
            'dados': {
              'id': 30,
              'idSolicitacao': 10,
              'metodo': 'PIX',
              'valorCentavos': 1250,
              'statusCriacao': 'CONFIRMADA',
              'status': 'PAID',
              'pixCopiaECola': 'codigo-pix-teste',
              'qrCodeBase64': null,
              'expiraEm': null,
              'modoTeste': true,
            },
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: PagamentoPixTela(
          pagamento: pagamento,
          pagamentoService: service,
          intervaloAtualizacao: const Duration(milliseconds: 100),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Pagamento confirmado'), findsWidgets);
    expect(find.text('COPIAR CÓDIGO PIX'), findsNothing);
    expect(find.byKey(const ValueKey('codigo-pix')), findsNothing);
    expect(requisicaoRecebida.method, 'GET');
    expect(requisicaoRecebida.url.path, '/pagamentos/30');
  });
}
