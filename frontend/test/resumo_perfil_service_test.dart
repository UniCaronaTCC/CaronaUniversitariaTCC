import 'dart:async';
import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:uni_carona/services/auth_service.dart';
import 'package:uni_carona/services/avaliacao_service.dart';
import 'package:uni_carona/services/memoria_resumo_perfil.dart';

http.Response respostaResumo({double media = 4.5, int total = 2}) =>
    http.Response(
      jsonEncode({
        'sucesso': true,
        'dados': {
          'media': media,
          'total': total,
          'pagina': 1,
          'totalPaginas': 1,
          'avaliacoes': [
            {'id': 1, 'comentario': 'Teste'},
          ],
        },
      }),
      200,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    AuthService.tokenUsuarioLogado = null;
    AuthService.usuarioLogado = {
      'id': 1,
      'nome': 'Pessoa de teste',
      'fotoPerfil': 'https://example.test/foto.jpg',
      'veiculo': {'modelo': 'Veiculo de teste'},
      'statusVerificacaoCnh': 'APROVADA',
    };
    AuthService.tokenUsuarioLogado = 'token-teste';
  });
  tearDown(() {
    AuthService.tokenUsuarioLogado = null;
    AuthService.usuarioLogado = null;
  });

  Future<void> preparar() async {
    final resultado = await http.runWithClient(
      AvaliacaoService.atualizarResumoPerfil,
      () => MockClient((request) async {
        expect(request.method, 'GET');
        expect(request.url.path, '/usuarios/1/avaliacoes');
        expect(request.url.queryParameters, {'pagina': '1'});
        expect(request.headers['Authorization'], 'Bearer token-teste');
        return respostaResumo();
      }),
    );
    expect(resultado['sucesso'], isTrue);
  }

  test(
    'consulta apenas a conta atual e nao substitui perfil, foto, veiculo ou CNH',
    () async {
      final perfil = AuthService.usuarioLogado;
      await preparar();
      final resumo = AvaliacaoService.lerResumoPerfil()!;
      expect(resumo, isA<ResumoAvaliacoesPerfil>());
      expect(resumo.media, 4.5);
      expect(resumo.total, 2);
      expect(identical(AuthService.usuarioLogado, perfil), isTrue);
    },
  );

  test('chamadas simultaneas geram um unico GET', () async {
    final pendente = Completer<http.Response>();
    var consultas = 0;
    await http.runWithClient(
      () async {
        final primeira = AvaliacaoService.atualizarResumoPerfil();
        final segunda = AvaliacaoService.atualizarResumoPerfil();
        expect(identical(primeira, segunda), isTrue);
        await Future<void>.delayed(Duration.zero);
        expect(consultas, 1);
        pendente.complete(respostaResumo());
        await Future.wait([primeira, segunda]);
      },
      () => MockClient((_) {
        consultas++;
        return pendente.future;
      }),
    );
  });

  test(
    'nova abertura revalida em vez de retornar so o resumo em memoria',
    () async {
      await preparar();
      var consultas = 0;
      await http.runWithClient(
        AvaliacaoService.atualizarResumoPerfil,
        () => MockClient((_) async {
          consultas++;
          return respostaResumo(media: 5, total: 3);
        }),
      );
      expect(consultas, 1);
      expect(AvaliacaoService.lerResumoPerfil()!.media, 5);
      expect(AvaliacaoService.lerResumoPerfil()!.total, 3);
    },
  );

  test(
    'consulta de outro usuario e pagina nao le nem substitui resumo proprio',
    () async {
      await preparar();
      final anterior = AvaliacaoService.lerResumoPerfil();
      await http.runWithClient(
        () async {
          final resposta = await AvaliacaoService.listarRecebidas(8, pagina: 2);
          expect(resposta['dados']['media'], 1);
          await AvaliacaoService.listarRecebidas(1, pagina: 3);
        },
        () => MockClient((request) async {
          expect(request.url.queryParameters['pagina'], anyOf('2', '3'));
          return respostaResumo(media: 1, total: 20);
        }),
      );
      expect(identical(AvaliacaoService.lerResumoPerfil(), anterior), isTrue);
    },
  );

  for (final dados in [
    <String, dynamic>{},
    {'media': 4.5},
    {'media': 'NaN', 'total': 3},
    {'media': 5, 'total': -1},
  ]) {
    test('payload incompleto nao sobrescreve media: $dados', () async {
      await preparar();
      final anterior = AvaliacaoService.lerResumoPerfil();
      final resultado = await http.runWithClient(
        AvaliacaoService.atualizarResumoPerfil,
        () => MockClient(
          (_) async => http.Response(jsonEncode({'dados': dados}), 200),
        ),
      );
      expect(resultado['sucesso'], isFalse);
      expect(identical(AvaliacaoService.lerResumoPerfil(), anterior), isTrue);
    });
  }

  test('indisponibilidade preserva resumo e permite nova tentativa', () async {
    await preparar();
    final resultado = await http.runWithClient(
      AvaliacaoService.atualizarResumoPerfil,
      () => MockClient(
        (_) async => http.Response('{"message":"Indisponivel"}', 503),
      ),
    );
    expect(resultado['mensagem'], 'Indisponivel');
    expect(AvaliacaoService.lerResumoPerfil()!.media, 4.5);
    expect(AuthService.estaLogado, isTrue);
    await preparar();
    expect(MemoriaResumoPerfil.compartilhada.erroAtualizacao, isNull);
  });

  for (final id in <int?>[null, 0, -1]) {
    test('sem identificador valido nao inicia consulta: $id', () async {
      AuthService.usuarioLogado = id == null ? null : {'id': id};
      var consultas = 0;
      final resultado = await http.runWithClient(
        AvaliacaoService.atualizarResumoPerfil,
        () => MockClient((_) async {
          consultas++;
          return respostaResumo();
        }),
      );
      expect(resultado['sucesso'], isFalse);
      expect(consultas, 0);
      expect(AvaliacaoService.lerResumoPerfil(), isNull);
    });
  }

  test(
    'renovacao do token preserva resumo e logout limpa imediatamente',
    () async {
      await preparar();
      final anterior = AvaliacaoService.lerResumoPerfil();
      AuthService.tokenUsuarioLogado = 'token-renovado';
      expect(identical(AvaliacaoService.lerResumoPerfil(), anterior), isTrue);
      await AuthService.sair();
      expect(AvaliacaoService.lerResumoPerfil(), isNull);
      AuthService.usuarioLogado = {'id': 1};
      AuthService.tokenUsuarioLogado = 'novo-login';
      expect(AvaliacaoService.lerResumoPerfil(), isNull);
    },
  );

  test(
    'troca de conta mesmo sem mudanca de geracao nao recupera resumo anterior',
    () async {
      await preparar();
      AuthService.usuarioLogado = {'id': 2};
      expect(AvaliacaoService.lerResumoPerfil(), isNull);
    },
  );

  test('GET antigo nao restaura resumo da sessao anterior', () async {
    final pendente = Completer<http.Response>();
    await http.runWithClient(() async {
      final antiga = AvaliacaoService.atualizarResumoPerfil();
      await Future<void>.delayed(Duration.zero);
      await AuthService.sair();
      AuthService.usuarioLogado = {'id': 1};
      AuthService.tokenUsuarioLogado = 'token-teste';
      await preparar();
      final atual = AvaliacaoService.lerResumoPerfil();
      pendente.complete(respostaResumo(media: 1));
      expect((await antiga)['codigo'], 'CONSULTA_DESCARTADA');
      expect(identical(AvaliacaoService.lerResumoPerfil(), atual), isTrue);
    }, () => MockClient((_) => pendente.future));
  });

  test('invalidacao durante GET exige resposta posterior', () async {
    var consultas = 0;
    final pendente = Completer<http.Response>();
    await http.runWithClient(
      () async {
        final primeira = AvaliacaoService.atualizarResumoPerfil();
        await Future<void>.delayed(Duration.zero);
        final forcada = AvaliacaoService.atualizarResumoPerfil(invalidar: true);
        expect(identical(primeira, forcada), isTrue);
        pendente.complete(respostaResumo());
        await forcada;
        expect(consultas, 2);
        expect(AvaliacaoService.lerResumoPerfil()!.media, 5);
      },
      () => MockClient(
        (_) => ++consultas == 1
            ? pendente.future
            : Future.value(respostaResumo(media: 5)),
      ),
    );
  });

  testWidgets(
    'timeout nao apaga resumo nem sessao e resposta tardia e ignorada',
    (tester) async {
      await preparar();
      final pendente = Completer<http.Response>();
      final consulta = http.runWithClient(
        AvaliacaoService.atualizarResumoPerfil,
        () => MockClient((_) => pendente.future),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 21));
      expect((await consulta)['sucesso'], isFalse);
      expect(AvaliacaoService.lerResumoPerfil()!.media, 4.5);
      expect(AuthService.estaLogado, isTrue);
      pendente.complete(respostaResumo(media: 1));
      await tester.pump();
      expect(AvaliacaoService.lerResumoPerfil()!.media, 4.5);
    },
  );

  test('401 definitivo limpa resumo alem da sessao', () async {
    await preparar();
    await http.runWithClient(
      AvaliacaoService.atualizarResumoPerfil,
      () => MockClient((_) async => http.Response('<html>401</html>', 401)),
    );
    expect(AvaliacaoService.lerResumoPerfil(), isNull);
    expect(AuthService.estaLogado, isFalse);
  });

  test(
    'envio de avaliacao preserva contrato e nao consulta nem altera resumo proprio',
    () async {
      await preparar();
      final anterior = AvaliacaoService.lerResumoPerfil();
      var pedidos = 0;
      final resultado = await http.runWithClient(
        () => AvaliacaoService.enviar(
          idSolicitacao: 12,
          nota: 5,
          comentario: 'Teste',
        ),
        () => MockClient((request) async {
          pedidos++;
          expect(request.method, 'POST');
          expect(request.url.path, '/avaliacoes');
          expect(jsonDecode(request.body), {
            'idSolicitacao': 12,
            'nota': 5,
            'comentario': 'Teste',
          });
          return http.Response('{"mensagem":"Enviada"}', 201);
        }),
      );
      expect(resultado['sucesso'], isTrue);
      expect(pedidos, 1);
      expect(identical(AvaliacaoService.lerResumoPerfil(), anterior), isTrue);
    },
  );
}
