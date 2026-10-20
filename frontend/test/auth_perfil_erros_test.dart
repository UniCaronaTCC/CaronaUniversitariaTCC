import 'dart:async';
import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:uni_carona/services/auth_service.dart';
import 'package:uni_carona/services/sessao_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const perfil = {'id': 1, 'nome': 'Usuario', 'email': 'usuario@example.test'};

  setUp(() async {
    FlutterSecureStorage.setMockInitialValues({});
    AuthService.tokenUsuarioLogado = null;
    AuthService.tokenUsuarioLogado = 'token-teste';
    AuthService.usuarioLogado = Map<String, dynamic>.from(perfil);
    await SessaoService.salvar('token-teste', perfil);
  });

  tearDown(() {
    AuthService.tokenUsuarioLogado = null;
    AuthService.usuarioLogado = null;
  });

  for (final status in [403, 409, 429, 500, 503]) {
    test('HTTP $status preserva sessao e perfil', () async {
      final resultado = await http.runWithClient(
        AuthService.buscarPerfil,
        () => MockClient(
          (_) async =>
              http.Response('{"message":"Aviso de validacao"}', status),
        ),
      );
      expect(resultado['sucesso'], isFalse);
      expect(AuthService.tokenUsuarioLogado, 'token-teste');
      expect(AuthService.usuarioLogado, perfil);
      expect((await SessaoService.carregar())!['usuario'], perfil);
      if (status >= 500) {
        expect(resultado['mensagem'], contains('indisponível'));
      }
      if (status == 403 || status == 409) {
        expect(resultado['mensagem'], 'Aviso de validacao');
      }
    });
  }

  for (final corpo in ['<html>proxy</html>', '', '[]', '{"dados":null}']) {
    test('nao salva resposta 200 invalida: $corpo', () async {
      final resultado = await http.runWithClient(
        AuthService.buscarPerfil,
        () => MockClient((_) async => http.Response(corpo, 200)),
      );
      expect(resultado['mensagem'], contains('resposta inválida'));
      expect(AuthService.usuarioLogado, perfil);
    });
  }

  test('HTML 503 e indisponibilidade, nao falta de internet', () async {
    final resultado = await http.runWithClient(
      AuthService.buscarPerfil,
      () => MockClient((_) async => http.Response('<html>proxy</html>', 503)),
    );
    expect(resultado['mensagem'], contains('indisponível'));
  });

  test('timeout nao salva resposta tardia nem remove sessao', () async {
    final pendente = Completer<http.Response>();
    final resultado = await http.runWithClient(
      () => AuthService.buscarPerfil(prazo: const Duration(milliseconds: 10)),
      () => MockClient((_) => pendente.future),
    );
    expect(resultado['mensagem'], contains('demorou'));
    pendente.complete(
      http.Response('{"dados":{"id":99,"nome":"Tardio"}}', 200),
    );
    await Future<void>.delayed(Duration.zero);
    expect(AuthService.usuarioLogado, perfil);
    expect(AuthService.tokenUsuarioLogado, 'token-teste');
    expect((await SessaoService.carregar())!['usuario'], perfil);
  });

  test('resposta de consulta anterior ao logout nao restaura perfil', () async {
    final pendente = Completer<http.Response>();
    final consulta = http.runWithClient(
      AuthService.buscarPerfil,
      () => MockClient((_) => pendente.future),
    );
    await Future<void>.delayed(Duration.zero);
    await AuthService.sair();
    pendente.complete(http.Response(jsonEncode({'dados': perfil}), 200));
    expect((await consulta)['sucesso'], isFalse);
    expect(AuthService.usuarioLogado, isNull);
    expect(await SessaoService.carregar(), isNull);
  });

  test('falha de conexao preserva sessao', () async {
    final resultado = await http.runWithClient(
      AuthService.buscarPerfil,
      () => MockClient((_) async {
        throw http.ClientException('rede indisponivel');
      }),
    );
    expect(resultado['mensagem'], contains('conexão'));
    expect(AuthService.estaLogado, isTrue);
  });

  test('consulta valida atualiza cache e persistencia', () async {
    final novoPerfil = {...perfil, 'campus': 'Campus teste'};
    final resultado = await http.runWithClient(
      AuthService.buscarPerfil,
      () => MockClient(
        (_) async => http.Response(jsonEncode({'dados': novoPerfil}), 200),
      ),
    );
    expect(resultado['sucesso'], isTrue);
    expect(AuthService.usuarioLogado, novoPerfil);
    expect((await SessaoService.carregar())!['usuario'], novoPerfil);
  });

  test('401 definitivo encerra sessao mesmo com corpo invalido', () async {
    final resultado = await http.runWithClient(
      AuthService.buscarPerfil,
      () => MockClient((_) async => http.Response('<html>401</html>', 401)),
    );
    expect(resultado['mensagem'], contains('sessão expirou'));
    expect(AuthService.estaLogado, isFalse);
    expect(await SessaoService.carregar(), isNull);
  });

  test('veiculo preserva restante do perfil', () async {
    final resultado = await http.runWithClient(
      () => AuthService.salvarVeiculo('Onix', 'Branco', 'AAA1B23'),
      () => MockClient((request) async {
        expect(request.method, 'PUT');
        expect(request.headers['Authorization'], 'Bearer token-teste');
        return http.Response(
          '{"dados":{"id":2,"modelo":"Onix"},"mensagem":"Veiculo salvo"}',
          200,
        );
      }),
    );
    expect(resultado['sucesso'], isTrue);
    expect(AuthService.usuarioLogado!['nome'], perfil['nome']);
    expect(AuthService.usuarioLogado!['veiculo'], {'id': 2, 'modelo': 'Onix'});
  });

  test(
    'timeout de alteracao nao repete envio e orienta consultar perfil',
    () async {
      var chamadas = 0;
      final resultado = await http.runWithClient(
        () => AuthService.atualizarPerfil(1, 'Campus'),
        () => MockClient((_) async {
          chamadas++;
          throw TimeoutException('teste');
        }),
      );
      expect(chamadas, 1);
      expect(resultado['mensagem'], contains('Atualize o perfil antes'));
      expect(AuthService.estaLogado, isTrue);
    },
  );
}
