import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:uni_carona/home/ofertar_carona.dart';
import 'package:uni_carona/models/capacidade_carona.dart';
import 'package:uni_carona/models/carona.dart';
import 'package:uni_carona/services/auth_service.dart';
import 'package:uni_carona/services/mensagem_service.dart';
import 'package:uni_carona/services/solicitacao_service.dart';
import 'package:uni_carona/widgets/formulario_ofertar_carona.dart';
import 'package:uni_carona/widgets/seletor_quantidade_passageiros.dart';

Carona carona({int vagas = 0}) => Carona(
  id: 10,
  origem: 'Rua A, 10',
  origemLatitude: -21,
  origemLongitude: -50,
  destino: 'Campus',
  destinoLatitude: -21.1,
  destinoLongitude: -50.1,
  dataInicio: DateTime(2099, 12, 1),
  horario: '18:00:00',
  vagas: vagas,
  valor: 5,
  recorrente: false,
  diasSemana: [],
  motorista: 'Motorista',
  idMotorista: 7,
  status: 'LOTADA',
);

void main() {
  for (final status in [200, 409]) {
    testWidgets('salvamento pela tela com resposta HTTP $status', (
      tester,
    ) async {
      FlutterSecureStorage.setMockInitialValues({});
      AuthService.tokenUsuarioLogado = 'token-sintetico';
      var consultas = 0;
      var gravacoes = 0;
      await http.runWithClient(
        () async {
          try {
            await tester.pumpWidget(
              MaterialApp(home: OfertarCaronaTela(caronaParaEditar: carona())),
            );
            await tester.pumpAndSettle();
            final form = tester.widget<FormularioOfertarCarona>(
              find.byType(FormularioOfertarCarona),
            );
            expect(form.vagasController.text, '4');
            form.observacoesController.text = 'Observacao de teste';
            await tester.ensureVisible(find.text('SALVAR ALTERAÇÕES'));
            await tester.pumpAndSettle();
            await tester.tap(find.text('SALVAR ALTERAÇÕES'));
            await tester.pumpAndSettle();
            expect(consultas, 1);
            expect(gravacoes, 1);
            expect(
              find.text(
                status == 200
                    ? 'Carona atualizada com sucesso'
                    : 'Reabra a carona para conferir as reservas',
              ),
              findsOneWidget,
            );
            if (status == 409) {
              expect(find.byType(FormularioOfertarCarona), findsOneWidget);
              expect(form.observacoesController.text, 'Observacao de teste');
            }
            expect(tester.takeException(), isNull);
            await tester.pumpWidget(const SizedBox());
          } finally {
            SolicitacaoService.pararContadorSolicitacoesPendentes();
            await MensagemService.pararContadorMensagensNaoLidas();
            AuthService.tokenUsuarioLogado = null;
          }
        },
        () => MockClient((req) async {
          if (req.url.path == '/caronas/10/capacidade') {
            consultas++;
            return http.Response(
              '{"sucesso":true,"dados":{"capacidadePassageiros":4,"passageirosAceitos":4,"vagasDisponiveis":0}}',
              200,
            );
          }
          if (req.method == 'PATCH' && req.url.path == '/caronas/10') {
            gravacoes++;
            final body = jsonDecode(req.body) as Map<String, dynamic>;
            expect(body['capacidadePassageiros'], 4);
            expect(body['capacidadeAnterior'], 4);
            expect(body.containsKey('vagas'), isFalse);
            expect(body['observacoes'], 'Observacao de teste');
            return http.Response.bytes(
              utf8.encode(
                jsonEncode(
                  status == 200
                      ? {
                          'sucesso': true,
                          'mensagem': 'Carona atualizada com sucesso',
                        }
                      : {
                          'message':
                              'Reabra a carona para conferir as reservas',
                        },
                ),
              ),
              status,
            );
          }
          return http.Response('{"sucesso":true,"dados":[]}', 200);
        }),
      );
    });
  }

  testWidgets('edicao da programacao nao consulta ocupacao das ocorrencias', (
    tester,
  ) async {
    var consultas = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: OfertarCaronaTela(
          caronaParaEditar: carona(vagas: 2),
          idRecorrencia: 20,
          carregarCapacidade: () async {
            consultas++;
            return {'sucesso': false};
          },
          carregarPerfil: () async => {
            'sucesso': true,
            'dados': {
              'statusVerificacaoCnh': 'APROVADA',
              'cnhCategoria': 'B',
              'cnhValidade': '2099-12-01',
              'veiculo': {'modelo': 'Carro'},
            },
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(consultas, 0);
    final form = tester.widget<FormularioOfertarCarona>(
      find.byType(FormularioOfertarCarona),
    );
    expect(form.vagasController.text, '2');
    expect(form.passageirosAceitos, isNull);
  });

  testWidgets(
    'carona lotada preenche capacidade total, nao zero vagas livres',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: OfertarCaronaTela(
            caronaParaEditar: carona(),
            carregarCapacidade: () async => {
              'sucesso': true,
              'dados': const CapacidadeCarona(total: 4, aceitos: 4, livres: 0),
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      final form = tester.widget<FormularioOfertarCarona>(
        find.byType(FormularioOfertarCarona),
      );
      expect(form.vagasController.text, '4');
      expect(form.passageirosAceitos, 4);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'consulta pendente impede salvar e sair nao causa setState apos dispose',
    (tester) async {
      final pendente = Completer<Map<String, dynamic>>();
      await tester.pumpWidget(
        MaterialApp(
          home: OfertarCaronaTela(
            caronaParaEditar: carona(),
            carregarCapacidade: () => pendente.future,
          ),
        ),
      );
      await tester.pump();
      expect(find.byType(FormularioOfertarCarona), findsNothing);
      await tester.pumpWidget(const SizedBox());
      pendente.complete({
        'sucesso': true,
        'dados': const CapacidadeCarona(total: 4, aceitos: 4, livres: 0),
      });
      await tester.pump();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('falha mostra aviso e nova tentativa recupera formulario', (
    tester,
  ) async {
    var consultas = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: OfertarCaronaTela(
          caronaParaEditar: carona(),
          carregarCapacidade: () async {
            consultas++;
            return consultas == 1
                ? {'sucesso': false, 'mensagem': 'Sem conexao'}
                : {
                    'sucesso': true,
                    'dados': const CapacidadeCarona(
                      total: 3,
                      aceitos: 2,
                      livres: 1,
                    ),
                  };
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Sem conexao'), findsOneWidget);
    expect(find.byType(FormularioOfertarCarona), findsNothing);
    await tester.tap(find.text('Tentar novamente'));
    await tester.pumpAndSettle();
    expect(consultas, 2);
    expect(
      tester
          .widget<FormularioOfertarCarona>(find.byType(FormularioOfertarCarona))
          .vagasController
          .text,
      '3',
    );
  });

  testWidgets('resposta sem capacidade nao libera formulario', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: OfertarCaronaTela(
          caronaParaEditar: carona(),
          carregarCapacidade: () async => {'sucesso': true, 'dados': {}},
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(FormularioOfertarCarona), findsNothing);
    expect(find.text('Tentar novamente'), findsOneWidget);
  });

  testWidgets(
    'seletor bloqueia capacidade abaixo dos aceitos e atualiza livres',
    (tester) async {
      final controller = TextEditingController(text: '4');
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SeletorQuantidadePassageiros(
              controller: controller,
              passageirosAceitos: 3,
            ),
          ),
        ),
      );
      final seletor = tester.widget<SegmentedButton<int>>(
        find.byType(SegmentedButton<int>),
      );
      expect(seletor.segments.map((s) => s.enabled), [
        false,
        false,
        true,
        true,
      ]);
      await tester.tap(find.text('1'));
      await tester.pump();
      expect(controller.text, '4');
      await tester.tap(find.text('3'));
      await tester.pump();
      expect(controller.text, '3');
      expect(find.textContaining('0 vagas livres'), findsOneWidget);
    },
  );

  testWidgets(
    'capacidade e ocupacao cabem em tela estreita com fonte ampliada',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final controller = TextEditingController(text: '4');
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(1.5)),
            child: Scaffold(
              body: Padding(
                padding: const EdgeInsets.all(24),
                child: SeletorQuantidadePassageiros(
                  controller: controller,
                  passageirosAceitos: 4,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );
}
