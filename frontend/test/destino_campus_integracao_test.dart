import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:latlong2/latlong.dart';
import 'package:uni_carona/home/buscar_carona.dart';
import 'package:uni_carona/home/tela_inicial.dart';
import 'package:uni_carona/mapa/models/localizacao_selecionada.dart';
import 'package:uni_carona/services/auth_service.dart';
import 'package:uni_carona/services/destino_preferido_service.dart';
import 'package:uni_carona/services/mensagem_service.dart';
import 'package:uni_carona/services/solicitacao_service.dart';
import 'package:uni_carona/widgets/card_destino_home.dart';

import 'campus_destino_test.dart' show campusJson;

void main() {
  testWidgets(
    'seleção real do campus na Home persiste e preenche a busca ao reabrir',
    (tester) async {
      FlutterSecureStorage.setMockInitialValues({});
      AuthService.usuarioLogado = {'id': 7, 'nome': 'Pessoa'};
      AuthService.tokenUsuarioLogado = 'token-sintetico';
      const preferencia = DestinoPreferidoService();
      await preferencia.salvar(
        7,
        const LocalizacaoSelecionada(
          ponto: LatLng(-21.23, -50.4),
          endereco: 'Outro destino',
          cidade: 'Araçatuba',
          estado: 'SP',
        ),
      );
      await http.runWithClient(
        () async {
          try {
            await tester.pumpWidget(
              const MaterialApp(home: TelaInicial(nomeUsuario: 'Pessoa')),
            );
            await tester.pumpAndSettle();
            await tester.tap(find.byType(CardDestinoHome));
            await tester.pumpAndSettle();
            await tester.tap(find.text('UNESP · Araçatuba - Odontologia'));
            await tester.pumpAndSettle();
            final salvo = await preferencia.carregar(7);
            expect(salvo!.ponto, const LatLng(-21.2, -50.4));
            expect(salvo.nome, 'UNESP · Araçatuba - Odontologia');
            await tester.pumpWidget(const SizedBox());
            await tester.pumpWidget(
              const MaterialApp(home: TelaInicial(nomeUsuario: 'Pessoa')),
            );
            await tester.pumpAndSettle();
            expect(
              tester
                  .widget<CardDestinoHome>(find.byType(CardDestinoHome))
                  .destino,
              salvo.descricaoCompleta,
            );
            await tester.tap(find.text('BUSCAR'));
            await tester.pumpAndSettle();
            expect(
              tester
                  .widget<BuscarCaronaTela>(find.byType(BuscarCaronaTela))
                  .destinoInicial!
                  .toJson(),
              salvo.toJson(),
            );
            await tester.pumpWidget(const SizedBox());
          } finally {
            SolicitacaoService.pararContadorSolicitacoesPendentes();
            await MensagemService.pararContadorMensagensNaoLidas();
            AuthService.usuarioLogado = null;
            AuthService.tokenUsuarioLogado = null;
          }
        },
        () => MockClient(
          (request) async => http.Response.bytes(
            utf8.encode(
              jsonEncode({
                'sucesso': true,
                'dados': request.url.path == '/instituicoes/destinos'
                    ? [campusJson()]
                    : [],
              }),
            ),
            200,
          ),
        ),
      );
    },
  );
}
