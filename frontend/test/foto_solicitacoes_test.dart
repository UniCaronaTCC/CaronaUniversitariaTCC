import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:uni_carona/models/solicitacao_enviada.dart';
import 'package:uni_carona/models/solicitacao_recebida.dart';
import 'package:uni_carona/services/auth_service.dart';
import 'package:uni_carona/services/solicitacao_service.dart';
import 'package:uni_carona/widgets/avatar_usuario.dart';
import 'package:uni_carona/widgets/card_solicitacao_enviada.dart';
import 'package:uni_carona/widgets/card_solicitacao_recebida.dart';

Map<String, dynamic> dados({
  required bool recebida,
  Object? foto,
  bool incluirFoto = true,
}) => {
  'id': 1,
  'status': 'ACEITA',
  'localEmbarque': 'Praca central',
  'embarqueLatitude': -21.2,
  'embarqueLongitude': -50.4,
  'pagamentoLimiteEm': '2026-11-03T16:07:00.000Z',
  recebida ? 'passageiro' : 'motorista': {
    'id': 8,
    'nome': 'Henrique',
    if (incluirFoto) 'fotoPerfil': foto,
  },
  'carona': {
    'id': 2,
    'destino': 'Campus',
    'dataInicio': '2026-11-05',
    'horario': '14:00:00',
    'valor': 5,
    'status': 'ATIVA',
  },
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const url = 'https://example.test/perfil-123?v=2';

  for (final recebida in [true, false]) {
    for (final foto in [
      null,
      '',
      '   ',
      12,
      false,
      <String, dynamic>{},
      ' $url ',
    ]) {
      test(
        'modelo de solicitacao recebida=$recebida normaliza foto=$foto sem alterar prazo',
        () {
          final json = dados(recebida: recebida, foto: foto);
          final esperada = foto == ' $url ' ? url : null;
          if (recebida) {
            final item = SolicitacaoRecebida.fromJson(json);
            expect(item.fotoPassageiro, esperada);
            expect(item.passageiro, 'Henrique');
            expect(item.pagamentoLimiteEm, DateTime(2026, 11, 3, 13, 7));
          } else {
            final item = SolicitacaoEnviada.fromJson(json);
            expect(item.fotoMotorista, esperada);
            expect(item.motorista, 'Henrique');
            expect(item.prazoPagamentoFormatado, '03/11 às 13:07');
          }
        },
      );
    }

    test(
      'resposta antiga sem foto continua compativel; recebida=$recebida',
      () {
        final json = dados(recebida: recebida, incluirFoto: false);
        expect(
          recebida
              ? SolicitacaoRecebida.fromJson(json).fotoPassageiro
              : SolicitacaoEnviada.fromJson(json).fotoMotorista,
          isNull,
        );
      },
    );

    for (final foto in [null, url]) {
      testWidgets(
        'card usa foto da outra pessoa ou inicial; recebida=$recebida foto=$foto',
        (tester) async {
          final json = dados(recebida: recebida, foto: foto);
          final card = recebida
              ? CardSolicitacaoRecebida(
                  solicitacao: SolicitacaoRecebida.fromJson(json),
                  processando: false,
                  onAceitar: () {},
                  onRecusar: () {},
                )
              : CardSolicitacaoEnviada(
                  solicitacao: SolicitacaoEnviada.fromJson(json),
                );
          await tester.pumpWidget(MaterialApp(home: Scaffold(body: card)));
          await tester.pumpAndSettle();
          final avatar = tester.widget<AvatarUsuario>(
            find.byType(AvatarUsuario),
          );
          expect(avatar.urlFoto, foto);
          expect(avatar.nome, 'Henrique');
          final circulo = tester.widget<CircleAvatar>(
            find.byType(CircleAvatar),
          );
          if (foto == null) {
            expect(circulo.foregroundImage, isNull);
          } else {
            expect((circulo.foregroundImage as NetworkImage).url, url);
            expect(circulo.onForegroundImageError, isNotNull);
          }
          expect(find.text('H'), findsOneWidget);
          expect(find.text('Henrique'), findsOneWidget);
          expect(tester.getSize(find.byType(CircleAvatar)), const Size(40, 40));
          expect(tester.takeException(), isNull);
        },
      );
    }

    test(
      'GET de solicitacoes transporta foto atual e removida; recebida=$recebida',
      () async {
        FlutterSecureStorage.setMockInitialValues({});
        AuthService.tokenUsuarioLogado = 'token-teste';
        addTearDown(() => AuthService.tokenUsuarioLogado = null);
        for (final foto in [url, null]) {
          final resultado = await http.runWithClient(
            recebida
                ? SolicitacaoService.listarRecebidas
                : SolicitacaoService.listarEnviadas,
            () => MockClient((request) async {
              expect(request.method, 'GET');
              expect(
                request.url.path,
                recebida ? '/solicitacoes/recebidas' : '/solicitacoes/enviadas',
              );
              expect(request.headers['Authorization'], 'Bearer token-teste');
              return http.Response(
                jsonEncode({
                  'sucesso': true,
                  'dados': [dados(recebida: recebida, foto: foto)],
                }),
                200,
              );
            }),
          );
          expect(resultado['sucesso'], isTrue);
          if (recebida) {
            expect(
              (resultado['dados'] as List<SolicitacaoRecebida>)
                  .single
                  .fotoPassageiro,
              foto,
            );
          } else {
            expect(
              (resultado['dados'] as List<SolicitacaoEnviada>)
                  .single
                  .fotoMotorista,
              foto,
            );
          }
        }
      },
    );
  }
}
