import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uni_carona/services/auth_service.dart';
import 'package:uni_carona/services/carona_service.dart';
import 'package:uni_carona/services/sessao_service.dart';
import 'package:uni_carona/services/supabase_auth_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  var modo = 'normal';
  var renovacoes = 0;
  var geracao = 0;
  Completer<void>? liberarRenovacao;
  const perfil = {'id': 1, 'nome': 'Usuario', 'email': 'usuario@example.test'};

  String token() {
    String parte(Object json) =>
        base64Url.encode(utf8.encode(jsonEncode(json))).replaceAll('=', '');
    return '${parte({'alg': 'HS256', 'typ': 'JWT'})}.${parte({'sub': '00000000-0000-4000-8000-000000000001', 'exp': DateTime.now().millisecondsSinceEpoch ~/ 1000 + 3600, 'geracao': geracao})}.assinatura';
  }

  http.Response respostaAuth(Object corpo, [int status = 200]) => http.Response(
    jsonEncode(corpo),
    status,
    headers: {
      'content-type': 'application/json',
      'x-supabase-api-version': '2024-01-01',
    },
  );

  setUpAll(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/shared_preferences'),
          (chamada) async =>
              chamada.method == 'getAll' ? <String, Object>{} : true,
        );
    await SupabaseAuthService.inicializar(
      authOptions: const FlutterAuthClientOptions(
        persistSession: false,
        autoRefreshToken: false,
        detectSessionInUri: false,
        authFlowType: AuthFlowType.implicit,
      ),
      cliente: MockClient((request) async {
        if (request.url.path.endsWith('/logout')) return respostaAuth({});
        if (request.url.queryParameters['grant_type'] == 'refresh_token') {
          renovacoes++;
          await liberarRenovacao?.future;
          if (modo == 'invalida') {
            return respostaAuth({
              'msg': 'Invalid refresh token',
              'code': 'refresh_token_not_found',
            }, 400);
          }
          if (modo == 'indisponivel') {
            return respostaAuth({'msg': 'Temporarily unavailable'}, 503);
          }
        }
        geracao++;
        return respostaAuth({
          'access_token': token(),
          'refresh_token': 'refresh-$geracao',
          'token_type': 'bearer',
          'expires_in': 3600,
          'user': {
            'id': '00000000-0000-4000-8000-000000000001',
            'aud': 'authenticated',
            'email': perfil['email'],
            'created_at': '2026-01-01T00:00:00Z',
            'app_metadata': {},
            'user_metadata': {},
          },
        });
      }),
    );
  });

  setUp(() async {
    modo = 'normal';
    liberarRenovacao = null;
    renovacoes = 0;
    FlutterSecureStorage.setMockInitialValues({});
    await SupabaseAuthService.entrar('usuario@example.test', 'senha');
    AuthService.usuarioLogado = Map<String, dynamic>.from(perfil);
  });
  tearDownAll(() => Supabase.instance.dispose());

  test('401 renova token e repete consulta uma unica vez', () async {
    final original = AuthService.tokenUsuarioLogado;
    var consultas = 0;
    final resultado = await http.runWithClient(
      AuthService.buscarPerfil,
      () => MockClient((request) async {
        consultas++;
        if (consultas == 1) return http.Response('{}', 401);
        expect(request.headers['Authorization'], isNot('Bearer $original'));
        return http.Response(jsonEncode({'dados': perfil}), 200);
      }),
    );
    expect(resultado['sucesso'], isTrue);
    expect(consultas, 2);
    expect(renovacoes, 1);
  });

  test('consultas simultaneas compartilham uma renovacao', () async {
    final original = AuthService.tokenUsuarioLogado;
    liberarRenovacao = Completer<void>();
    final consultas = http.runWithClient(
      () =>
          Future.wait([AuthService.buscarPerfil(), AuthService.buscarPerfil()]),
      () => MockClient((request) async {
        if (request.headers['Authorization'] == 'Bearer $original') {
          return http.Response('{}', 401);
        }
        return http.Response(jsonEncode({'dados': perfil}), 200);
      }),
    );
    await Future<void>.delayed(Duration.zero);
    liberarRenovacao!.complete();
    expect((await consultas).every((r) => r['sucesso'] == true), isTrue);
    expect(renovacoes, 1);
  });

  test('403 nao renova nem encerra sessao', () async {
    final resultado = await http.runWithClient(
      AuthService.buscarPerfil,
      () => MockClient(
        (_) async => http.Response('{"message":"Acesso negado"}', 403),
      ),
    );
    expect(resultado['mensagem'], 'Acesso negado');
    expect(renovacoes, 0);
    expect(AuthService.estaLogado, isTrue);
  });

  test('refresh comprovadamente invalido encerra sessao', () async {
    modo = 'invalida';
    final resultado = await http.runWithClient(
      AuthService.buscarPerfil,
      () => MockClient((_) async => http.Response('{}', 401)),
    );
    expect(resultado['mensagem'], contains('sessão expirou'));
    expect(AuthService.estaLogado, isFalse);
    expect(AuthService.usuarioLogado, isNull);
  });

  testWidgets(
    'indisponibilidade durante refresh nao desloga nem reenvia operacao vencida',
    (tester) async {
      modo = 'indisponivel';
      final original = AuthService.tokenUsuarioLogado;
      var consultas = 0;
      final pendente = http.runWithClient(
        AuthService.buscarPerfil,
        () => MockClient((_) async {
          consultas++;
          return http.Response('{}', 401);
        }),
      );
      for (var i = 0; i < 21; i++) {
        await tester.pump(const Duration(seconds: 1));
      }
      final resultado = await pendente;
      expect(resultado['sucesso'], isFalse);
      expect(AuthService.tokenUsuarioLogado, original);
      expect(AuthService.usuarioLogado, perfil);
      modo = 'normal';
      await tester.pump(const Duration(seconds: 10));
      await tester.pump();
      expect(consultas, 1);
      expect(AuthService.usuarioLogado, perfil);
    },
  );

  for (final acao in ['iniciar', 'finalizar']) {
    test('$acao corrida usa token renovado sem mudar regras', () async {
      var chamadas = 0;
      final resultado = await http.runWithClient(
        () => acao == 'iniciar'
            ? CaronaService.iniciarCorrida(20)
            : CaronaService.finalizarCorrida(20),
        () => MockClient((request) async {
          expect(request.url.path, '/caronas/20/$acao');
          expect(request.method, 'PATCH');
          chamadas++;
          if (chamadas == 1) return http.Response('{}', 401);
          return http.Response(
            jsonEncode({
              'dados': {
                'idCarona': 20,
                'origem': 'Centro',
                'destino': 'Campus',
                'dataInicio': '2026-10-20',
                'horario': '19:00:00',
                'vagas': 2,
                'valor': 8,
                'status': acao == 'iniciar' ? 'EM_ANDAMENTO' : 'FINALIZADA',
                'usuario': {'idUsuario': 1, 'nome': 'Usuario'},
              },
            }),
            200,
          );
        }),
      );
      expect(resultado['sucesso'], isTrue);
      expect(chamadas, 2);
      expect(renovacoes, 1);
    });
  }

  test('alteracao de perfil renova token e mantem corpo enviado', () async {
    var chamadas = 0;
    final resultado = await http.runWithClient(
      () => AuthService.atualizarPerfil(2, 'Campus'),
      () => MockClient((request) async {
        expect(request.method, 'PATCH');
        expect(jsonDecode(request.body), {
          'idInstituicao': 2,
          'campus': 'Campus',
        });
        chamadas++;
        return chamadas == 1
            ? http.Response('{}', 401)
            : http.Response(jsonEncode({'dados': perfil}), 200);
      }),
    );
    expect(resultado['sucesso'], isTrue);
    expect(chamadas, 2);
  });

  test('veiculo renova token e preserva os campos do perfil', () async {
    var chamadas = 0;
    final resultado = await http.runWithClient(
      () => AuthService.salvarVeiculo('Onix', 'Branco', 'AAA1B23'),
      () => MockClient((request) async {
        expect(request.method, 'PUT');
        expect(jsonDecode(request.body), {
          'modelo': 'Onix',
          'cor': 'Branco',
          'placa': 'AAA1B23',
        });
        chamadas++;
        return chamadas == 1
            ? http.Response('{}', 401)
            : http.Response('{"dados":{"id":2,"modelo":"Onix"}}', 200);
      }),
    );
    expect(resultado['sucesso'], isTrue);
    expect(chamadas, 2);
    expect(renovacoes, 1);
    expect(AuthService.usuarioLogado!['nome'], perfil['nome']);
    expect(
      (await SessaoService.carregar())!['token'],
      AuthService.tokenUsuarioLogado,
    );
  });

  test('foto recria multipart apos 401 e persiste token renovado', () async {
    final pasta = await Directory.systemTemp.createTemp('buscaeu-foto-teste-');
    try {
      final foto = File('${pasta.path}/foto.jpg');
      await foto.writeAsBytes([255, 216, 255, 1, 2, 3]);
      var chamadas = 0;
      final resultado = await http.runWithClient(
        () => AuthService.atualizarFotoPerfil(foto.path),
        () => MockClient.streaming((request, corpo) async {
          chamadas++;
          expect(request.method, 'PATCH');
          expect(request.url.path, '/usuarios/perfil/foto');
          expect(
            request.headers['content-type'],
            startsWith('multipart/form-data'),
          );
          expect(
            utf8.decode(await corpo.toBytes(), allowMalformed: true),
            contains('name="foto"'),
          );
          return http.StreamedResponse(
            Stream.value(
              utf8.encode(
                chamadas == 1
                    ? '{}'
                    : jsonEncode({
                        'dados': {
                          ...perfil,
                          'fotoPerfil': 'https://example.test/foto.jpg',
                        },
                      }),
              ),
            ),
            chamadas == 1 ? 401 : 200,
          );
        }),
      );
      expect(resultado['sucesso'], isTrue);
      expect(chamadas, 2);
      expect(renovacoes, 1);
      expect(
        AuthService.usuarioLogado!['fotoPerfil'],
        'https://example.test/foto.jpg',
      );
      expect(
        (await SessaoService.carregar())!['token'],
        AuthService.tokenUsuarioLogado,
      );
    } finally {
      await pasta.delete(recursive: true);
    }
  });

  test(
    'reabertura preserva perfil salvo se backend estiver indisponivel',
    () async {
      final original = AuthService.tokenUsuarioLogado!;
      await SessaoService.salvar(original, perfil);
      AuthService.usuarioLogado = null;
      await http.runWithClient(
        AuthService.carregarSessao,
        () => MockClient((_) async => http.Response('indisponivel', 503)),
      );
      expect(AuthService.estaLogado, isTrue);
      expect(AuthService.usuarioLogado, perfil);
      expect((await SessaoService.carregar())!['usuario'], perfil);
    },
  );

  test('login carrega perfil e mantem formato esperado pela tela', () async {
    final resultado = await http.runWithClient(
      () => AuthService.fazerLogin('usuario@example.test', 'senha'),
      () => MockClient(
        (_) async => http.Response(jsonEncode({'dados': perfil}), 200),
      ),
    );
    expect(resultado['sucesso'], isTrue);
    expect(resultado['dados']['usuario'], perfil);
    expect(resultado['dados']['mensagem'], 'Login realizado com sucesso');
  });

  for (final leitura in [true, false]) {
    test(
      'localizacao ${leitura ? 'consulta' : 'envio'} renova antes de encerrar sessao',
      () async {
        var chamadas = 0;
        final resultado = await http.runWithClient(
          () => leitura
              ? CaronaService.buscarPosicaoAtual(20)
              : CaronaService.atualizarPosicaoAtual(
                  idCarona: 20,
                  latitude: -21.2,
                  longitude: -50.4,
                  precisao: 5,
                ),
          () => MockClient((request) async {
            chamadas++;
            expect(request.method, leitura ? 'GET' : 'PUT');
            return chamadas == 1
                ? http.Response('{}', 401)
                : http.Response('{"dados":null}', 200);
          }),
        );
        expect(leitura ? (resultado as Map)['sucesso'] : resultado, isTrue);
        expect(chamadas, 2);
        expect(renovacoes, 1);
        expect(AuthService.estaLogado, isTrue);
      },
    );
  }

  test('conflito ao iniciar nao renova nem repete operacao', () async {
    var chamadas = 0;
    final resultado = await http.runWithClient(
      () => CaronaService.iniciarCorrida(20),
      () => MockClient((_) async {
        chamadas++;
        return http.Response(
          '{"message":"Esta carona não pode ser iniciada"}',
          409,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }),
    );
    expect(resultado['sucesso'], isFalse);
    expect(resultado['mensagem'], 'Esta carona não pode ser iniciada');
    expect(chamadas, 1);
    expect(renovacoes, 0);
  });

  test('segunda resposta 401 nao provoca ciclo de renovacao', () async {
    var chamadas = 0;
    final resultado = await http.runWithClient(
      AuthService.buscarPerfil,
      () => MockClient((_) async {
        chamadas++;
        return http.Response('{}', 401);
      }),
    );
    expect(resultado['sucesso'], isFalse);
    expect(chamadas, 2);
    expect(renovacoes, 1);
    expect(AuthService.estaLogado, isFalse);
  });
}
