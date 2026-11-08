import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:uni_carona/models/carona.dart';
import 'package:uni_carona/models/reputacao.dart';
import 'package:uni_carona/models/solicitacao_enviada.dart';
import 'package:uni_carona/models/solicitacao_recebida.dart';
import 'package:uni_carona/services/auth_service.dart';
import 'package:uni_carona/services/carona_service.dart';
import 'package:uni_carona/services/solicitacao_service.dart';

import 'reputacao_test.dart' show caronaComReputacao, pedidoComReputacao;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    AuthService.usuarioLogado = {'id': 7};
    AuthService.tokenUsuarioLogado = 'token-teste';
  });
  tearDown(() {
    AuthService.tokenUsuarioLogado = null;
    AuthService.usuarioLogado = null;
    SolicitacaoService.pararContadorSolicitacoesPendentes();
  });

  final consultas = <String, Future<Map<String, dynamic>> Function()>{
    '/caronas': () => CaronaService.listarCaronas(),
    '/caronas/minhas': CaronaService.listarMinhasCaronas,
    '/caronas/10': () => CaronaService.buscarDetalhesCarona(10),
    '/solicitacoes/recebidas': () => SolicitacaoService.listarRecebidas(),
    '/caronas/10/solicitacoes': () =>
        SolicitacaoService.listarRecebidas(idCarona: 10),
    '/solicitacoes/enviadas': SolicitacaoService.listarEnviadas,
  };
  for (final consulta in consultas.entries) {
    for (final resumo in <Object?>[
      {'media': 4.5, 'total': 2},
      {'media': 0, 'total': 0},
      null,
    ]) {
      test(
        '${consulta.key}: reputacao $resumo vem na mesma requisicao',
        () async {
          var chamadas = 0;
          final carona = caronaComReputacao(resumo);
          final pedido = pedidoComReputacao(resumo);
          final ehPedido = consulta.key.contains('solicitacoes');
          final detalhe = consulta.key == '/caronas/10';
          final resultado = await http.runWithClient(
            consulta.value,
            () => MockClient((requisicao) async {
              chamadas++;
              expect(requisicao.method, 'GET');
              expect(requisicao.url.path, consulta.key);
              expect(requisicao.headers['Authorization'], 'Bearer token-teste');
              return http.Response(
                jsonEncode({
                  'sucesso': true,
                  'dados': detalhe ? carona : [ehPedido ? pedido : carona],
                }),
                200,
              );
            }),
          );
          expect(resultado['sucesso'], isTrue);
          expect(chamadas, 1);
          final dados = detalhe
              ? resultado['dados']
              : (resultado['dados'] as List).single;
          final Reputacao? reputacao = switch (dados) {
            Carona() => dados.reputacaoMotorista,
            SolicitacaoRecebida() => dados.reputacaoPassageiro,
            SolicitacaoEnviada() => dados.reputacaoMotorista,
            _ => throw StateError('Modelo de resposta incorreto'),
          };
          expect(
            reputacao?.media,
            resumo == null ? null : (resumo as Map)['media'],
          );
          expect(
            reputacao?.total,
            resumo == null ? null : (resumo as Map)['total'],
          );
        },
      );
    }
  }
}
