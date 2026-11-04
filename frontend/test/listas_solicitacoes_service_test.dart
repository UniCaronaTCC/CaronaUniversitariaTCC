import 'dart:async';
import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:uni_carona/services/auth_service.dart';
import 'package:uni_carona/services/memoria_solicitacoes.dart';
import 'package:uni_carona/services/solicitacao_service.dart';

import 'memoria_solicitacoes_test.dart' show dadosSolicitacao;

http.Response lista({bool vazia = false, String status = 'PENDENTE'}) =>
    http.Response(
      jsonEncode({
        'dados': [if (!vazia) dadosSolicitacao(status: status)],
      }),
      200,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    AuthService.tokenUsuarioLogado = null;
    AuthService.usuarioLogado = {'id': 1};
    AuthService.tokenUsuarioLogado = 'token-teste';
  });
  tearDown(() {
    AuthService.tokenUsuarioLogado = null;
    AuthService.usuarioLogado = null;
    SolicitacaoService.pararContadorSolicitacoesPendentes();
  });

  Future<void> preparar() async {
    final resposta = await http.runWithClient(
      SolicitacaoService.atualizarListas,
      () => MockClient((_) async => lista()),
    );
    expect(resposta['sucesso'], isTrue);
  }

  test('consulta conjunta nao altera o contador automaticamente', () async {
    SolicitacaoService.totalSolicitacoesPendentes.value = 7;
    await preparar();
    expect(SolicitacaoService.lerListas()!.recebidas, hasLength(1));
    expect(SolicitacaoService.lerListas()!.enviadas, hasLength(1));
    expect(SolicitacaoService.listasConfirmadas, isTrue);
    expect(SolicitacaoService.totalSolicitacoesPendentes.value, 7);
  });

  test('consultas simultaneas fazem somente um GET por lista', () async {
    final recebidas = Completer<http.Response>();
    final enviadas = Completer<http.Response>();
    var total = 0;
    await http.runWithClient(
      () async {
        final primeira = SolicitacaoService.atualizarListas();
        final segunda = SolicitacaoService.atualizarListas();
        expect(identical(primeira, segunda), isTrue);
        await Future<void>.delayed(Duration.zero);
        expect(total, 2);
        recebidas.complete(lista());
        enviadas.complete(lista());
        await Future.wait([primeira, segunda]);
      },
      () => MockClient((request) {
        total++;
        return request.url.path.endsWith('/recebidas')
            ? recebidas.future
            : enviadas.future;
      }),
    );
  });

  test(
    'nova consulta revalida e metodos diretos nunca retornam a memoria',
    () async {
      await preparar();
      var total = 0;
      await http.runWithClient(
        () async {
          await SolicitacaoService.atualizarListas();
          await SolicitacaoService.listarRecebidas(idCarona: 10);
          await SolicitacaoService.listarEnviadas();
          await SolicitacaoService.listarRecebidas();
        },
        () => MockClient((_) async {
          total++;
          return lista(vazia: true);
        }),
      );
      expect(total, 5);
      expect(SolicitacaoService.lerListas()!.recebidas, isEmpty);
    },
  );

  for (final falhaRecebidas in [false, true]) {
    test(
      'falha parcial nao substitui snapshot nem contador: $falhaRecebidas',
      () async {
        await preparar();
        final anterior = SolicitacaoService.lerListas();
        SolicitacaoService.totalSolicitacoesPendentes.value = 8;
        final resultado = await http.runWithClient(
          SolicitacaoService.atualizarListas,
          () => MockClient(
            (request) async =>
                request.url.path.endsWith('/recebidas') == falhaRecebidas
                ? http.Response('{}', 200)
                : lista(vazia: true),
          ),
        );
        expect(resultado['sucesso'], isFalse);
        expect(identical(SolicitacaoService.lerListas(), anterior), isTrue);
        expect(SolicitacaoService.listasConfirmadas, isFalse);
        expect(SolicitacaoService.totalSolicitacoesPendentes.value, 8);
      },
    );
  }

  for (final id in <int?>[null, 0, -1]) {
    test('sem usuario valido nao consulta nem restaura memoria: $id', () async {
      AuthService.usuarioLogado = id == null ? null : {'id': id};
      var consultas = 0;
      final resultado = await http.runWithClient(
        SolicitacaoService.atualizarListas,
        () => MockClient((_) async {
          consultas++;
          return lista();
        }),
      );
      expect(resultado['sucesso'], isFalse);
      expect(consultas, 0);
      expect(SolicitacaoService.lerListas(), isNull);
      expect(SolicitacaoService.listasConfirmadas, isFalse);
    });
  }

  test('renovar token preserva memoria; logout e novo login limpam', () async {
    await preparar();
    AuthService.tokenUsuarioLogado = 'token-renovado';
    expect(SolicitacaoService.lerListas(), isNotNull);
    expect(SolicitacaoService.listasConfirmadas, isTrue);
    await AuthService.sair();
    expect(SolicitacaoService.lerListas(), isNull);
    AuthService.usuarioLogado = {'id': 1};
    AuthService.tokenUsuarioLogado = 'novo-login';
    expect(SolicitacaoService.lerListas(), isNull);
    expect(SolicitacaoService.listasConfirmadas, isFalse);
  });

  test(
    'troca de usuario sem reutilizar a geracao nao recupera listas',
    () async {
      await preparar();
      AuthService.usuarioLogado = {'id': 2};
      expect(SolicitacaoService.lerListas(), isNull);
      expect(SolicitacaoService.listasConfirmadas, isFalse);
    },
  );

  test(
    'GET antigo depois do logout nao altera listas da nova sessao',
    () async {
      final antiga = Completer<http.Response>();
      await http.runWithClient(() async {
        final consultaAntiga = SolicitacaoService.atualizarListas();
        await Future<void>.delayed(Duration.zero);
        await AuthService.sair();
        AuthService.usuarioLogado = {'id': 2};
        AuthService.tokenUsuarioLogado = 'nova-sessao';
        await preparar();
        final atual = SolicitacaoService.lerListas();
        antiga.complete(lista(vazia: true));
        expect((await consultaAntiga)['codigo'], 'CONSULTA_DESCARTADA');
        expect(identical(SolicitacaoService.lerListas(), atual), isTrue);
        expect(SolicitacaoService.listasConfirmadas, isTrue);
      }, () => MockClient((_) => antiga.future));
    },
  );

  for (final acao in ['aceitar', 'cancelar', 'solicitar']) {
    for (final sucesso in [false, true]) {
      test(
        '$acao sucesso=$sucesso exige nova leitura sem apagar os cards',
        () async {
          await preparar();
          final anterior = SolicitacaoService.lerListas();
          final resultado = await http.runWithClient(
            () {
              return switch (acao) {
                'aceitar' => SolicitacaoService.responderSolicitacao(
                  idSolicitacao: 23,
                  status: 'ACEITA',
                ),
                'cancelar' => SolicitacaoService.cancelarSolicitacao(23),
                _ => SolicitacaoService.solicitarVagaComPontoExistente(
                  idCarona: 10,
                  idPontoEmbarque: 1,
                ),
              };
            },
            () => MockClient(
              (_) async => http.Response(
                '{"mensagem":"Resultado"}',
                sucesso ? 200 : 409,
              ),
            ),
          );
          expect(resultado['sucesso'], sucesso);
          expect(identical(SolicitacaoService.lerListas(), anterior), isTrue);
          expect(SolicitacaoService.listasConfirmadas, isFalse);
        },
      );
    }
  }

  test('acao concluida durante GET exige nova consulta do par', () async {
    await preparar();
    final antigas = Completer<http.Response>();
    var gets = 0;
    await http.runWithClient(
      () async {
        final consulta = SolicitacaoService.atualizarListas();
        await Future<void>.delayed(Duration.zero);
        await SolicitacaoService.cancelarSolicitacao(23);
        antigas.complete(lista());
        expect((await consulta)['sucesso'], isTrue);
        expect(gets, 4);
        expect(SolicitacaoService.lerListas()!.recebidas, isEmpty);
        expect(SolicitacaoService.lerListas()!.enviadas, isEmpty);
      },
      () => MockClient((request) {
        if (request.method == 'PATCH') {
          return Future.value(http.Response('{}', 200));
        }
        gets++;
        return gets <= 2 ? antigas.future : Future.value(lista(vazia: true));
      }),
    );
  });

  test(
    'PATCH de sessao antiga nao invalida nova consulta confirmada',
    () async {
      final antiga = Completer<http.Response>();
      await http.runWithClient(() async {
        final comando = SolicitacaoService.cancelarSolicitacao(23);
        await Future<void>.delayed(Duration.zero);
        await AuthService.sair();
        AuthService.usuarioLogado = {'id': 2};
        AuthService.tokenUsuarioLogado = 'nova-sessao';
        await preparar();
        antiga.complete(http.Response('{}', 200));
        expect((await comando)['sucesso'], isFalse);
        expect(SolicitacaoService.listasConfirmadas, isTrue);
      }, () => MockClient((_) => antiga.future));
    },
  );

  test('sem token nao usa memoria nem consulta servidor', () async {
    await preparar();
    AuthService.tokenUsuarioLogado = null;
    final resultado = await SolicitacaoService.atualizarListas();
    expect(resultado['sucesso'], isFalse);
    expect(SolicitacaoService.lerListas(), isNull);
    expect(
      MemoriaSolicitacoes.compartilhada.ler((1, AuthService.versaoSessao)),
      isNull,
    );
  });

  test('atualizacao forcada durante GET nao perde a nova consulta', () async {
    final antigas = Completer<http.Response>();
    var gets = 0;
    await http.runWithClient(
      () async {
        final primeira = SolicitacaoService.atualizarListas();
        await Future<void>.delayed(Duration.zero);
        final forcada = SolicitacaoService.atualizarListas(invalidar: true);
        expect(identical(primeira, forcada), isTrue);
        antigas.complete(lista());
        final resultado = await forcada;
        expect(resultado['sucesso'], isTrue);
        expect(gets, 4);
        expect(SolicitacaoService.lerListas()!.recebidas, isEmpty);
        expect(SolicitacaoService.listasConfirmadas, isTrue);
      },
      () => MockClient((_) {
        gets++;
        return gets <= 2 ? antigas.future : Future.value(lista(vazia: true));
      }),
    );
  });

  test(
    'falha de rede na alteracao exige nova leitura sem apagar dados',
    () async {
      await preparar();
      final anterior = SolicitacaoService.lerListas();
      final resultado = await http.runWithClient(
        () => SolicitacaoService.cancelarSolicitacao(23),
        () => MockClient((_) async => throw http.ClientException('offline')),
      );
      expect(resultado['sucesso'], isFalse);
      expect(identical(SolicitacaoService.lerListas(), anterior), isTrue);
      expect(SolicitacaoService.listasConfirmadas, isFalse);
    },
  );

  test(
    'leitura durante PATCH nao confirma dados depois de sua conclusao',
    () async {
      await preparar();
      final alteracao = Completer<http.Response>();
      await http.runWithClient(() async {
        final comando = SolicitacaoService.cancelarSolicitacao(23);
        expect(SolicitacaoService.listasConfirmadas, isFalse);
        await preparar();
        expect(SolicitacaoService.listasConfirmadas, isTrue);
        alteracao.complete(http.Response('{}', 200));
        await comando;
        expect(SolicitacaoService.listasConfirmadas, isFalse);
      }, () => MockClient((_) => alteracao.future));
      await preparar();
      expect(SolicitacaoService.listasConfirmadas, isTrue);
    },
  );
}
