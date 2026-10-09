import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uni_carona/services/auth_service.dart';
import 'package:uni_carona/services/supabase_auth_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late String mensagem;
  String? codigo;
  Map<String, dynamic>? corpoCadastro;

  setUpAll(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/shared_preferences'),
          (_) async => <String, Object>{},
        );
    await Supabase.initialize(
      url: 'https://supabase.example',
      publishableKey: 'chave-publica-teste',
      httpClient: MockClient((requisicao) async {
        expect(requisicao.url.host, 'supabase.example');
        if (requisicao.url.path.endsWith('/signup')) {
          corpoCadastro = jsonDecode(requisicao.body) as Map<String, dynamic>;
        }
        return http.Response(
          jsonEncode({'msg': mensagem, 'code': codigo}),
          400,
          headers: {
            'content-type': 'application/json',
            'x-supabase-api-version': '2024-01-01',
          },
        );
      }),
      authOptions: const FlutterAuthClientOptions(
        persistSession: false,
        autoRefreshToken: false,
        detectSessionInUri: false,
        authFlowType: AuthFlowType.implicit,
      ),
    );
  });

  tearDownAll(() => Supabase.instance.dispose());

  setUp(() {
    codigo = null;
    corpoCadastro = null;
    AuthService.tokenUsuarioLogado = null;
    AuthService.usuarioLogado = null;
  });

  final casos = [
    (
      codigo: 'invalid_credentials',
      mensagem: 'Invalid email or password',
      esperado: 'E-mail ou senha inválidos',
    ),
    (
      codigo: 'email_provider_disabled',
      mensagem: 'Email and password sign-ins are disabled',
      esperado: 'A autenticação por e-mail e senha está desativada',
    ),
    (
      codigo: 'email_not_confirmed',
      mensagem: 'Email not confirmed',
      esperado: 'Confirme seu e-mail antes de entrar',
    ),
    (
      codigo: 'over_request_rate_limit',
      mensagem: 'Too many password sign-in attempts',
      esperado: 'Aguarde um pouco antes de tentar novamente',
    ),
  ];

  for (final caso in casos) {
    test('login diferencia o erro ${caso.codigo}', () async {
      codigo = caso.codigo;
      mensagem = caso.mensagem;

      final resultado = await AuthService.fazerLogin(
        'usuario@example.com',
        'senha-teste',
      );

      expect(resultado['sucesso'], isFalse);
      expect(resultado['mensagem'], caso.esperado);
      expect(AuthService.tokenUsuarioLogado, isNull);
    });
  }

  test('preserva erro desconhecido que menciona password', () async {
    codigo = 'unexpected_failure';
    mensagem = 'Unexpected password authentication error';

    final resultado = await AuthService.fazerLogin(
      'usuario@example.com',
      'senha-teste',
    );

    expect(resultado['mensagem'], mensagem);
  });

  test('reconhece credenciais inválidas sem código de erro', () async {
    mensagem = 'Invalid login credentials';

    final resultado = await AuthService.fazerLogin(
      'usuario@example.com',
      'senha-teste',
    );

    expect(resultado['mensagem'], 'E-mail ou senha inválidos');
  });

  test('cadastro mantém o aviso de senha fraca quando confirmado', () async {
    codigo = 'weak_password';
    mensagem = 'Password should contain at least 8 characters';

    final resultado = await AuthService.fazerCadastro(
      'Usuario',
      'usuario@example.com',
      'curta',
    );

    expect(resultado['sucesso'], isFalse);
    expect(
      resultado['mensagem'],
      'A senha não atende aos requisitos de segurança',
    );
  });

  test(
    'cadastro envia nome com inicial maiuscula sem alterar senha ou email',
    () async {
      codigo = 'weak_password';
      mensagem = 'Password should contain at least 8 characters';
      await expectLater(
        SupabaseAuthService.cadastrar(
          '  joão da Silva  ',
          'joao@example.com',
          'curta',
        ),
        throwsA(isA<AuthException>()),
      );
      expect(corpoCadastro!['data']['nome'], 'João da Silva');
      expect(corpoCadastro!['email'], 'joao@example.com');
      expect(corpoCadastro!['password'], 'curta');
    },
  );
}
