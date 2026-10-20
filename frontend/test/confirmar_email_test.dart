import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uni_carona/auth/confirmar_email.dart';
import 'package:uni_carona/auth/login.dart';
import 'package:uni_carona/services/email_verificacao_service.dart';
import 'package:uni_carona/services/supabase_auth_service.dart';

class ArmazenamentoAuthTeste extends GotrueAsyncStorage {
  const ArmazenamentoAuthTeste();
  @override
  Future<String?> getItem({required String key}) async => null;
  @override
  Future<void> setItem({required String key, required String value}) async {}
  @override
  Future<void> removeItem({required String key}) async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  var aceitarCodigo = true;
  var verificacoes = 0;
  var reenvios = 0;
  String? senhaRecebida;
  Map<String, dynamic>? pedido;
  const usuario = {
    'id': '00000000-0000-4000-8000-000000000001',
    'aud': 'authenticated',
    'email': 'usuario@example.test',
    'created_at': '2026-01-01T00:00:00Z',
    'app_metadata': <String, dynamic>{},
    'user_metadata': <String, dynamic>{},
  };

  setUpAll(() async {
    await SupabaseAuthService.inicializar(
      authOptions: const FlutterAuthClientOptions(
        persistSession: false,
        autoRefreshToken: false,
        detectSessionInUri: false,
        authFlowType: AuthFlowType.implicit,
        pkceAsyncStorage: ArmazenamentoAuthTeste(),
      ),
      cliente: MockClient((request) async {
        Map<String, dynamic> corpo = {};
        var status = 200;
        if (request.url.path.endsWith('/verify')) {
          verificacoes++;
          pedido = jsonDecode(request.body) as Map<String, dynamic>;
          if (aceitarCodigo) {
            String parte(Object json) => base64Url
                .encode(utf8.encode(jsonEncode(json)))
                .replaceAll('=', '');
            corpo = {
              'access_token':
                  '${parte({'alg': 'HS256'})}.${parte({'sub': usuario['id'], 'exp': DateTime.now().millisecondsSinceEpoch ~/ 1000 + 3600})}.assinatura',
              'refresh_token': 'refresh-sintetico',
              'token_type': 'bearer',
              'expires_in': 3600,
              'user': usuario,
            };
          } else {
            corpo = {
              'msg': 'Código inválido ou expirado',
              'code': 'otp_expired',
            };
            status = 403;
          }
        } else if (request.url.path.endsWith('/resend')) {
          reenvios++;
          expect(jsonDecode(request.body)['type'], 'signup');
        } else if (request.url.path.endsWith('/user')) {
          senhaRecebida = jsonDecode(request.body)['password'] as String;
          corpo = usuario;
        } else {
          expect(request.url.path.endsWith('/logout'), isTrue);
        }
        return http.Response(
          jsonEncode(corpo),
          status,
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
    aceitarCodigo = true;
    verificacoes = 0;
    reenvios = 0;
    senhaRecebida = null;
    pedido = null;
  });

  Future<void> abrir(WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      const MaterialApp(
        home: ConfirmarEmailTela(email: 'usuario@example.test'),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('campo e mensagem usam seis digitos', (tester) async {
    await abrir(tester);
    expect(tester.widget<TextField>(find.byType(TextField)).maxLength, 6);
    expect(find.textContaining('código de 6 dígitos'), findsOneWidget);
    expect(find.widgetWithText(TextField, '000000'), findsOneWidget);
    await tester.enterText(find.byType(TextField), '12345678');
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      '123456',
    );
    await tester.pumpWidget(const SizedBox());
  });

  for (final codigo in ['', '1', '12345']) {
    testWidgets('codigo incompleto "$codigo" nao e enviado', (tester) async {
      await abrir(tester);
      await tester.enterText(find.byType(TextField), codigo);
      await tester.tap(find.text('CONFIRMAR E-MAIL'));
      await tester.pumpAndSettle();
      expect(verificacoes, 0);
      expect(find.text('Informe o código de 6 dígitos'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });
  }

  testWidgets('campo remove caracteres nao numericos', (tester) async {
    await abrir(tester);
    await tester.enterText(find.byType(TextField), '12a34b56');
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      '123456',
    );
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('seis digitos confirmam cadastro e preservam zeros iniciais', (
    tester,
  ) async {
    await abrir(tester);
    await tester.enterText(find.byType(TextField), '001234');
    await tester.tap(find.text('CONFIRMAR E-MAIL'));
    await tester.pumpAndSettle();
    expect(verificacoes, 1);
    expect(pedido!['token'], '001234');
    expect(pedido!['type'], 'signup');
    expect(pedido!['email'], 'usuario@example.test');
    expect(find.byType(LoginTela), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('codigo incorreto ou expirado permite tentar novamente', (
    tester,
  ) async {
    aceitarCodigo = false;
    await abrir(tester);
    await tester.enterText(find.byType(TextField), '123456');
    await tester.tap(find.text('CONFIRMAR E-MAIL'));
    await tester.pumpAndSettle();
    expect(find.text('Código inválido ou expirado'), findsOneWidget);
    expect(find.text('CONFIRMANDO...'), findsNothing);
    expect(find.byType(ConfirmarEmailTela), findsOneWidget);
    aceitarCodigo = true;
    await tester.enterText(find.byType(TextField), '654321');
    await tester.tap(find.text('CONFIRMAR E-MAIL'));
    await tester.pumpAndSettle();
    expect(verificacoes, 2);
    expect(pedido!['token'], '654321');
    expect(find.byType(LoginTela), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('reenvio mantem intervalo de 60 segundos e limpa codigo antigo', (
    tester,
  ) async {
    await abrir(tester);
    await tester.enterText(find.byType(TextField), '123456');
    expect(find.text('REENVIAR CÓDIGO'), findsNothing);
    await tester.pump(const Duration(seconds: 61));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('REENVIAR CÓDIGO'));
    await tester.tap(find.text('REENVIAR CÓDIGO'));
    await tester.pumpAndSettle();
    expect(reenvios, 1);
    expect(find.text('Reenviar código em 60s'), findsOneWidget);
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      isEmpty,
    );
    await tester.pumpWidget(const SizedBox());
  });

  test(
    'recuperacao envia seis digitos como OTP recovery sem alterar senha',
    () async {
      final resultado = await EmailVerificacaoService.redefinirSenha(
        'usuario@example.test',
        '001234',
        'novaSenha123',
      );
      expect(resultado['sucesso'], isTrue);
      expect(pedido!['token'], '001234');
      expect(pedido!['type'], 'recovery');
      expect(senhaRecebida, 'novaSenha123');
    },
  );
}
