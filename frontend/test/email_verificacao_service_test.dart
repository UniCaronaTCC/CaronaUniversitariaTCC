import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uni_carona/auth/esqueci_senha.dart';
import 'package:uni_carona/config/app_theme.dart';
import 'package:uni_carona/services/email_verificacao_service.dart';
import 'package:uni_carona/widgets/aviso_app.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const email = 'usuario@example.test';
  const avisoLimite =
      'Por segurança, aguarde um pouco antes de tentar novamente.';
  var status = 429;
  String? codigo;
  var mensagem = '';
  var primeiroEnvioPermitido = false;
  final pedidos = <http.Request>[];

  setUpAll(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/shared_preferences'),
          (_) async => <String, Object>{},
        );
    await Supabase.initialize(
      url: 'https://supabase.example',
      publishableKey: 'chave-publica-teste',
      authOptions: const FlutterAuthClientOptions(
        persistSession: false,
        autoRefreshToken: false,
        detectSessionInUri: false,
        authFlowType: AuthFlowType.implicit,
      ),
      httpClient: MockClient((pedido) async {
        expect(pedido.url.host, 'supabase.example');
        pedidos.add(pedido);
        final respostaSucesso =
            status == 200 || (primeiroEnvioPermitido && pedidos.length == 1);
        return http.Response(
          jsonEncode(
            respostaSucesso
                ? <String, dynamic>{}
                : {'msg': mensagem, 'code': ?codigo},
          ),
          respostaSucesso ? 200 : status,
          headers: {
            'content-type': 'application/json; charset=utf-8',
            'x-supabase-api-version': '2024-01-01',
          },
        );
      }),
    );
  });

  tearDownAll(() => Supabase.instance.dispose());

  setUp(() {
    status = 429;
    codigo = 'over_email_send_rate_limit';
    mensagem =
        'For security purposes, you can only request this after 60 seconds.';
    primeiroEnvioPermitido = false;
    pedidos.clear();
  });

  final operacoes = [
    (
      nome: 'confirmar email',
      caminho: '/verify',
      executar: () => EmailVerificacaoService.confirmarEmail(email, '001234'),
    ),
    (
      nome: 'reenviar confirmacao',
      caminho: '/resend',
      executar: () => EmailVerificacaoService.reenviarCodigo(email),
    ),
    (
      nome: 'solicitar recuperacao',
      caminho: '/recover',
      executar: () => EmailVerificacaoService.solicitarRedefinicaoSenha(email),
    ),
    (
      nome: 'redefinir senha',
      caminho: '/verify',
      executar: () => EmailVerificacaoService.redefinirSenha(
        email,
        '001234',
        'novaSenha123',
      ),
    ),
  ];

  const casos = [
    (status: 429, codigo: 'over_email_send_rate_limit'),
    (status: 429, codigo: 'over_request_rate_limit'),
    (status: 429, codigo: null),
    (status: 400, codigo: 'over_email_send_rate_limit'),
    (status: 400, codigo: 'over_request_rate_limit'),
  ];

  for (final operacao in operacoes) {
    for (final caso in casos) {
      test(
        '${operacao.nome} traduz limite $caso sem repetir requisicao',
        () async {
          status = caso.status;
          codigo = caso.codigo;
          final resultado = await operacao.executar();
          expect(resultado, {'sucesso': false, 'mensagem': avisoLimite});
          expect(pedidos, hasLength(1));
          expect(pedidos.single.url.path, endsWith(operacao.caminho));
          expect(jsonDecode(pedidos.single.body)['email'], email);
        },
      );
    }

    test('${operacao.nome} preserva mensagens de outros erros', () async {
      status = 403;
      codigo = 'otp_expired';
      mensagem = 'Código inválido ou expirado';
      final resultado = await operacao.executar();
      expect(resultado, {'sucesso': false, 'mensagem': mensagem});
      expect(pedidos, hasLength(1));
    });
  }

  test('reenvio de confirmacao bem-sucedido continua normal', () async {
    status = 200;
    final resultado = await EmailVerificacaoService.reenviarCodigo(email);
    expect(resultado, {'sucesso': true, 'mensagem': 'Novo código enviado'});
    expect(pedidos, hasLength(1));
  });

  test('pedido de recuperacao bem-sucedido continua normal', () async {
    status = 200;
    final resultado = await EmailVerificacaoService.solicitarRedefinicaoSenha(
      email,
    );
    expect(resultado, {
      'sucesso': true,
      'mensagem': 'Código enviado para o seu e-mail',
    });
    expect(pedidos, hasLength(1));
  });

  testWidgets('recuperacao mostra limite em portugues e preserva codigo', (
    tester,
  ) async {
    primeiroEnvioPermitido = true;
    await tester.pumpWidget(
      MaterialApp(theme: AppTheme.lightTheme, home: const EsqueciSenhaTela()),
    );
    await tester.enterText(
      find.byKey(const ValueKey('email-recuperacao')),
      email,
    );
    await tester.tap(find.byKey(const ValueKey('solicitar-codigo-senha')));
    await tester.pumpAndSettle();
    expect(pedidos, hasLength(1));
    ScaffoldMessenger.of(
      tester.element(find.byType(EsqueciSenhaTela)),
    ).removeCurrentSnackBar();
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('codigo-recuperacao')),
      '001234',
    );
    await tester.ensureVisible(find.text('Reenviar código'));
    await tester.tap(find.text('Reenviar código'));
    await tester.pumpAndSettle();
    expect(pedidos, hasLength(2));
    expect(find.text(avisoLimite), findsOneWidget);
    expect(find.text(mensagem), findsNothing);
    expect(tester.widget<AvisoApp>(find.byType(AvisoApp)).tipo, TipoAviso.erro);
    expect(
      tester.widget<SnackBar>(find.byType(SnackBar)).duration,
      const Duration(seconds: 5),
    );
    final cartao = tester.widget<Material>(
      find
          .descendant(
            of: find.byType(AvisoApp),
            matching: find.byType(Material),
          )
          .first,
    );
    expect(cartao.color, const Color(0xFFC62828));
    expect(
      tester.widget<Text>(find.text(avisoLimite)).style!.color,
      Colors.white,
    );
    expect(
      tester
          .widget<TextField>(find.byKey(const ValueKey('codigo-recuperacao')))
          .controller!
          .text,
      '001234',
    );
    expect(
      find.byKey(const ValueKey('formulario-redefinicao')),
      findsOneWidget,
    );
    await tester.pump(const Duration(seconds: 61));
    await tester.pumpAndSettle();
    status = 200;
    await tester.tap(find.text('Reenviar código'));
    await tester.pumpAndSettle();
    expect(pedidos, hasLength(3));
    expect(find.text('Código enviado para o seu e-mail'), findsOneWidget);
    expect(
      tester.widget<AvisoApp>(find.byType(AvisoApp)).tipo,
      TipoAviso.informacao,
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
