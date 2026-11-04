import 'dart:async';
import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:uni_carona/models/solicitacao_recebida.dart';
import 'package:uni_carona/services/auth_service.dart';
import 'package:uni_carona/services/solicitacao_service.dart';

import 'memoria_solicitacoes_test.dart' show dadosSolicitacao;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    AuthService.usuarioLogado = {'id': 1};
    AuthService.tokenUsuarioLogado = 'token-teste';
  });
  tearDown(() {
    AuthService.tokenUsuarioLogado = null;
    AuthService.usuarioLogado = null;
    SolicitacaoService.pararContadorSolicitacoesPendentes();
  });

  Future<Map<String, dynamic>> consultar(
    String corpo, {
    int? idCarona,
    int status = 200,
  }) => http.runWithClient(
    () => SolicitacaoService.listarRecebidas(idCarona: idCarona),
    () => MockClient((request) async {
      expect(request.method, 'GET');
      expect(
        request.url.path,
        idCarona == null
            ? '/solicitacoes/recebidas'
            : '/caronas/$idCarona/solicitacoes',
      );
      expect(request.headers['Authorization'], 'Bearer token-teste');
      return http.Response(corpo, status);
    }),
  );

  for (final idCarona in <int?>[null, 10]) {
    for (final envelope in [false, true]) {
      test('consulta valida carona=$idCarona envelope=$envelope', () async {
        final dados = dadosSolicitacao()
          ..['pagamentoConfirmado'] = true
          ..['podeAvaliar'] = true
          ..['passageiro'] = {
            'nome': 'Passageiro',
            'fotoPerfil': 'https://example.test/foto.jpg',
          };
        final resultado = await consultar(
          jsonEncode({
            if (envelope) 'sucesso': true,
            'dados': [dados],
          }),
          idCarona: idCarona,
        );
        expect(resultado['sucesso'], isTrue);
        final solicitacao =
            (resultado['dados'] as List<SolicitacaoRecebida>).single;
        expect(solicitacao.id, 23);
        expect(solicitacao.pagamentoConfirmado, isTrue);
        expect(solicitacao.podeAvaliar, isTrue);
        expect(solicitacao.fotoPassageiro, 'https://example.test/foto.jpg');
        final vazio = await consultar(
          jsonEncode({if (envelope) 'sucesso': true, 'dados': []}),
          idCarona: idCarona,
        );
        expect(vazio['sucesso'], isTrue);
        expect(vazio['dados'], isEmpty);
      });
    }

    for (final corpo in [
      '',
      '<html>proxy</html>',
      '{',
      '[]',
      'null',
      '{}',
      '{"dados":null}',
      '{"dados":{}}',
      '{"dados":"lista"}',
      '{"sucesso":false,"dados":[]}',
      '{"dados":[null]}',
      '{"dados":[42]}',
      '{"dados":[false]}',
      '{"dados":[[]]}',
      '{"dados":["invalida"]}',
      '{"dados":[{}]}',
    ]) {
      test('nao aceita resposta invalida carona=$idCarona: $corpo', () async {
        final resultado = await consultar(corpo, idCarona: idCarona);
        expect(resultado['sucesso'], isFalse);
        expect(resultado['mensagem'], contains('resposta inválida'));
        expect(resultado.containsKey('dados'), isFalse);
        expect(AuthService.estaLogado, isTrue);
      });
    }

    test('nao publica lista parcial carona=$idCarona', () async {
      final resultado = await consultar(
        jsonEncode({
          'dados': [dadosSolicitacao(), null],
        }),
        idCarona: idCarona,
      );
      expect(resultado['sucesso'], isFalse);
      expect(resultado.containsKey('dados'), isFalse);
    });
  }

  for (final recebidas in [false, true]) {
    testWidgets('prazo de consulta preserva sessao recebidas=$recebidas', (
      tester,
    ) async {
      final atrasada = Completer<http.Response>();
      final consulta = http.runWithClient(
        () => recebidas
            ? SolicitacaoService.listarRecebidas()
            : SolicitacaoService.listarEnviadas(),
        () => MockClient((_) => atrasada.future),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 21));
      expect((await consulta)['sucesso'], isFalse);
      expect(AuthService.estaLogado, isTrue);
      atrasada.complete(http.Response('{"dados":[]}', 200));
      await tester.pump();
    });

    test('401 em HTML encerra sessao recebidas=$recebidas', () async {
      final resultado = await http.runWithClient(
        () => recebidas
            ? SolicitacaoService.listarRecebidas()
            : SolicitacaoService.listarEnviadas(),
        () => MockClient((_) async => http.Response('<html>401</html>', 401)),
      );
      expect(resultado['sucesso'], isFalse);
      expect(AuthService.estaLogado, isFalse);
    });
  }

  test('falha HTTP preserva a mensagem e a sessao', () async {
    final resultado = await consultar(
      '{"message":"Acesso negado"}',
      status: 403,
    );
    expect(resultado['mensagem'], 'Acesso negado');
    expect(AuthService.estaLogado, isTrue);
  });

  test('falha de rede nao encerra a sessao', () async {
    final resultado = await http.runWithClient(
      () => SolicitacaoService.listarRecebidas(),
      () => MockClient((_) async => throw http.ClientException('offline')),
    );
    expect(resultado['sucesso'], isFalse);
    expect(AuthService.estaLogado, isTrue);
  });

  test('resposta invalida de recebidas nao zera o contador', () async {
    SolicitacaoService.totalSolicitacoesPendentes.value = 4;
    await http.runWithClient(
      SolicitacaoService.atualizarTotalSolicitacoesPendentes,
      () => MockClient(
        (request) async => http.Response(
          request.url.path.endsWith('/recebidas') ? '{}' : '{"dados":[]}',
          200,
        ),
      ),
    );
    expect(SolicitacaoService.totalSolicitacoesPendentes.value, 4);
  });
}
