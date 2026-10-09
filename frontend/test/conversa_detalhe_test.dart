import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uni_carona/home/conversa_detalhe.dart';
import 'package:uni_carona/home/detalhes_carona.dart';
import 'package:uni_carona/models/carona.dart';
import 'package:uni_carona/models/conversa.dart';
import 'package:uni_carona/models/mensagem.dart';
import 'conversa_estado_test.dart' show conversaJson;

void main() {
  final conversa = Conversa(
    id: 1,
    status: 'ACEITA',
    idSolicitacao: 10,
    idPassageiro: 1,
    passageiro: 'João',
    idMotorista: 2,
    motorista: 'Maria',
    idCarona: 20,
    destino: 'UniSalesiano',
    dataInicio: DateTime(2026, 9, 2),
    horario: '19:00:00',
    criadoEm: DateTime(2026, 9, 1),
  );

  List<Mensagem> criarHistorico(int quantidade) {
    return List.generate(
      quantidade,
      (indice) => Mensagem(
        id: indice + 1,
        conteudo: 'Mensagem ${indice + 1}',
        criadoEm: DateTime(2026, 9, 1, 18, indice),
        idRemetente: indice.isEven ? 1 : 2,
      ),
    );
  }

  Carona caronaDoChat(String status) => Carona(
    id: 20,
    origem: 'Centro',
    destino: 'UniSalesiano',
    dataInicio: DateTime(2026, 10, 8),
    horario: '19:00:00',
    vagas: 3,
    valor: 8,
    recorrente: false,
    diasSemana: const [],
    status: status,
    motorista: 'Maria',
    idMotorista: 2,
    veiculoModelo: 'Onix',
    veiculoCor: 'Branco',
    veiculoPlaca: '***1D23',
  );

  for (final status in ['ATIVA', 'FINALIZADA', 'CANCELADA']) {
    testWidgets(
      'abre mesma tela de detalhes pelo cabecalho com carona $status',
      (tester) async {
        final carona = caronaDoChat(status);
        await tester.pumpWidget(
          MaterialApp(
            home: ConversaDetalheTela(
              conversa: Conversa.fromJson(conversaJson(status)),
              idUsuario: 1,
              usarRealtime: false,
              carregarMensagens: () async => {
                'sucesso': true,
                'dados': criarHistorico(1),
              },
              carregarCarona: (id) async {
                expect(id, 20);
                return {'sucesso': true, 'dados': carona};
              },
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(
          find.byKey(const ValueKey('avatar-cabecalho-conversa')),
        );
        await tester.pumpAndSettle();
        final detalhes = tester.widget<DetalhesCaronaTela>(
          find.byType(DetalhesCaronaTela),
        );
        expect(detalhes.carona, same(carona));
        expect(detalhes.indiceNavegacaoOrigem, 1);
        expect(detalhes.somenteConsulta, isTrue);
        expect(find.text('Vagas disponíveis'), findsNothing);
        expect(find.text('Detalhes da carona'), findsOneWidget);
        expect(find.text('SOLICITAR VAGA'), findsNothing);
        await tester.tap(find.byTooltip('Voltar'));
        await tester.pumpAndSettle();
        expect(find.text('Mensagem 1'), findsOneWidget);
      },
    );
  }

  testWidgets('erro nos detalhes mantem chat e permite tentar novamente', (
    tester,
  ) async {
    var tentativas = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: ConversaDetalheTela(
          conversa: conversa,
          idUsuario: 1,
          usarRealtime: false,
          carregarMensagens: () async => {
            'sucesso': true,
            'dados': criarHistorico(1),
          },
          carregarCarona: (_) async {
            tentativas++;
            return tentativas == 1
                ? {'sucesso': false, 'mensagem': 'Carona não encontrada'}
                : {'sucesso': true, 'dados': caronaDoChat('ATIVA')};
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Maria'));
    await tester.pumpAndSettle();
    expect(find.text('Carona não encontrada'), findsOneWidget);
    expect(find.text('Mensagem 1'), findsOneWidget);
    expect(find.byType(DetalhesCaronaTela), findsNothing);
    await tester.tap(find.text('Maria'));
    await tester.pumpAndSettle();
    expect(tentativas, 2);
    expect(find.byType(DetalhesCaronaTela), findsOneWidget);
  });

  testWidgets(
    'impede consultas duplicadas e suporta texto ampliado no cabecalho',
    (tester) async {
      tester.view.physicalSize = const Size(320, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final resposta = Completer<Map<String, dynamic>>();
      var consultas = 0;
      await tester.pumpWidget(
        MaterialApp(
          builder: (_, child) => MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(1.5)),
            child: child!,
          ),
          home: ConversaDetalheTela(
            conversa: conversa,
            idUsuario: 1,
            usarRealtime: false,
            carregarMensagens: () async => {
              'sucesso': true,
              'dados': <Mensagem>[],
            },
            carregarCarona: (_) {
              consultas++;
              return resposta.future;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final cabecalho = find.byKey(const ValueKey('cabecalho-detalhes-carona'));
      await tester.tap(cabecalho);
      await tester.pump();
      await tester.tap(cabecalho);
      expect(consultas, 1);
      resposta.complete({'sucesso': false, 'mensagem': 'Sem conexão'});
      await tester.pumpAndSettle();
      expect(find.text('Sem conexão'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  ScrollPosition posicaoLista(WidgetTester tester) {
    final lista = tester.widget<ListView>(
      find.byKey(const ValueKey('lista-mensagens')),
    );
    return lista.controller!.position;
  }

  testWidgets('atualiza chat aberto ao retornar depois da finalizacao', (
    tester,
  ) async {
    var finalizada = false;
    await tester.pumpWidget(
      MaterialApp(
        home: ConversaDetalheTela(
          conversa: conversa,
          idUsuario: 1,
          usarRealtime: false,
          carregarMensagens: () async => {
            'sucesso': true,
            'dados': criarHistorico(1),
            'conversa': Conversa.fromJson(
              conversaJson(finalizada ? 'FINALIZADA' : 'ATIVA'),
            ),
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsOneWidget);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    finalizada = true;
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsNothing);
    expect(find.text('Mensagem 1'), findsOneWidget);
    expect(find.text('Conversa encerrada'), findsOneWidget);
  });

  testWidgets(
    'historico de carona finalizada fecha mesmo com card desatualizado',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ConversaDetalheTela(
            conversa: conversa,
            idUsuario: 1,
            usarRealtime: false,
            carregarMensagens: () async => {
              'sucesso': true,
              'dados': criarHistorico(1),
              'conversa': Conversa.fromJson(conversaJson('FINALIZADA')),
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(TextField), findsNothing);
      expect(find.text('Mensagem 1'), findsOneWidget);
    },
  );

  testWidgets('recusa do backend encerra chat e impede reenvio', (
    tester,
  ) async {
    var tentativas = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: ConversaDetalheTela(
          conversa: conversa,
          idUsuario: 1,
          usarRealtime: false,
          carregarMensagens: () async => {
            'sucesso': true,
            'dados': <Mensagem>[],
          },
          enviarMensagem: (_) async {
            tentativas++;
            return {'sucesso': false, 'codigo': 'CONVERSA_ENCERRADA'};
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Nao deve enviar');
    await tester.tap(find.byTooltip('Enviar mensagem'));
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsNothing);
    await tester.tap(find.text('Tentar novamente'), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(tentativas, 1);
    expect(find.text('Não enviada'), findsOneWidget);
  });

  testWidgets('mostra histórico e envia nova mensagem', (tester) async {
    var textoEnviado = '';

    await tester.pumpWidget(
      MaterialApp(
        home: ConversaDetalheTela(
          conversa: conversa,
          idUsuario: 1,
          usarRealtime: false,
          carregarMensagens: () async => {
            'sucesso': true,
            'dados': [
              Mensagem(
                id: 1,
                conteudo: 'Boa tarde!',
                criadoEm: DateTime(2026, 9, 1, 18),
                idRemetente: 2,
              ),
            ],
          },
          enviarMensagem: (texto) async {
            textoEnviado = texto;
            return {
              'sucesso': true,
              'dados': Mensagem(
                id: 2,
                conteudo: texto,
                criadoEm: DateTime(2026, 9, 1, 18, 5),
                idRemetente: 1,
              ),
            };
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Maria'), findsOneWidget);
    expect(find.text('Boa tarde!'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'Estou chegando');
    await tester.tap(find.byTooltip('Enviar mensagem'));
    await tester.pumpAndSettle();

    expect(textoEnviado, 'Estou chegando');
    expect(find.text('Estou chegando'), findsOneWidget);
    expect(find.text('Enviada'), findsOneWidget);
  });

  testWidgets('mostra envio em andamento na própria mensagem', (tester) async {
    final resposta = Completer<Map<String, dynamic>>();

    await tester.pumpWidget(
      MaterialApp(
        home: ConversaDetalheTela(
          conversa: conversa,
          idUsuario: 1,
          usarRealtime: false,
          carregarMensagens: () async => {
            'sucesso': true,
            'dados': <Mensagem>[],
          },
          enviarMensagem: (_) => resposta.future,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'Mensagem pendente');
    await tester.tap(find.byTooltip('Enviar mensagem'));
    await tester.pump();

    expect(find.text('Mensagem pendente'), findsOneWidget);
    expect(find.text('Enviando'), findsOneWidget);
    expect(find.widgetWithText(TextField, 'Mensagem pendente'), findsNothing);

    resposta.complete({
      'sucesso': true,
      'dados': Mensagem(
        id: 3,
        conteudo: 'Mensagem pendente',
        criadoEm: DateTime(2026, 9, 1, 18, 10),
        idRemetente: 1,
      ),
    });
    await tester.pumpAndSettle();

    expect(find.text('Enviando'), findsNothing);
    expect(find.text('Enviada'), findsOneWidget);
  });

  testWidgets('mantém mensagem com erro e permite tentar novamente', (
    tester,
  ) async {
    var tentativas = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: ConversaDetalheTela(
          conversa: conversa,
          idUsuario: 1,
          usarRealtime: false,
          carregarMensagens: () async => {
            'sucesso': true,
            'dados': <Mensagem>[],
          },
          enviarMensagem: (texto) async {
            tentativas++;
            if (tentativas == 1) {
              return {'sucesso': false, 'mensagem': 'Sem conexão'};
            }

            return {
              'sucesso': true,
              'dados': Mensagem(
                id: 4,
                conteudo: texto,
                criadoEm: DateTime(2026, 9, 1, 18, 15),
                idRemetente: 1,
              ),
            };
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'Tente de novo');
    await tester.tap(find.byTooltip('Enviar mensagem'));
    await tester.pumpAndSettle();

    expect(tentativas, 1);
    expect(find.text('Tente de novo'), findsOneWidget);
    expect(find.text('Não enviada'), findsOneWidget);
    expect(find.text('Tentar novamente'), findsOneWidget);

    await tester.tap(find.text('Tentar novamente'));
    await tester.pumpAndSettle();

    expect(tentativas, 2);
    expect(find.text('Não enviada'), findsNothing);
    expect(find.text('Tentar novamente'), findsNothing);
    expect(find.text('Enviada'), findsOneWidget);
  });

  testWidgets('abre uma conversa longa na mensagem mais recente', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ConversaDetalheTela(
          conversa: conversa,
          idUsuario: 1,
          usarRealtime: false,
          carregarMensagens: () async => {
            'sucesso': true,
            'dados': criarHistorico(30),
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    final posicao = posicaoLista(tester);
    expect(posicao.pixels, closeTo(posicao.maxScrollExtent, 0.1));
    expect(find.text('Mensagem 30'), findsOneWidget);
  });

  testWidgets('volta ao final ao enviar uma nova mensagem', (tester) async {
    final resposta = Completer<Map<String, dynamic>>();

    await tester.pumpWidget(
      MaterialApp(
        home: ConversaDetalheTela(
          conversa: conversa,
          idUsuario: 1,
          usarRealtime: false,
          carregarMensagens: () async => {
            'sucesso': true,
            'dados': criarHistorico(30),
          },
          enviarMensagem: (_) => resposta.future,
        ),
      ),
    );
    await tester.pumpAndSettle();

    posicaoLista(tester).jumpTo(0);
    await tester.enterText(find.byType(TextField), 'Nova mensagem');
    await tester.tap(find.byTooltip('Enviar mensagem'));
    await tester.pump();

    resposta.complete({
      'sucesso': true,
      'dados': Mensagem(
        id: 31,
        conteudo: 'Nova mensagem',
        criadoEm: DateTime(2026, 9, 1, 18, 30),
        idRemetente: 1,
      ),
    });
    await tester.pumpAndSettle();

    final posicao = posicaoLista(tester);
    expect(posicao.pixels, closeTo(posicao.maxScrollExtent, 0.1));
    expect(find.text('Nova mensagem'), findsOneWidget);
  });

  testWidgets('separa mensagens por data e formata os horários', (
    tester,
  ) async {
    final agora = DateTime.now();
    final ontem = DateTime(agora.year, agora.month, agora.day - 1, 23, 8);
    final hojeDeManha = DateTime(agora.year, agora.month, agora.day, 8, 5);
    final hojeMaisTarde = DateTime(agora.year, agora.month, agora.day, 9, 7);

    await tester.pumpWidget(
      MaterialApp(
        home: ConversaDetalheTela(
          conversa: conversa,
          idUsuario: 1,
          usarRealtime: false,
          carregarMensagens: () async => {
            'sucesso': true,
            'dados': [
              Mensagem(
                id: 1,
                conteudo: 'Mensagem antiga',
                criadoEm: DateTime(2024, 5, 2, 7, 4),
                idRemetente: 2,
              ),
              Mensagem(
                id: 2,
                conteudo: 'Mensagem de ontem',
                criadoEm: ontem,
                idRemetente: 2,
              ),
              Mensagem(
                id: 3,
                conteudo: 'Bom dia',
                criadoEm: hojeDeManha,
                idRemetente: 2,
              ),
              Mensagem(
                id: 4,
                conteudo: 'Tudo certo',
                criadoEm: hojeMaisTarde,
                idRemetente: 1,
              ),
            ],
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('2 de maio de 2024'), findsOneWidget);
    expect(find.text('Ontem'), findsOneWidget);
    expect(find.text('Hoje'), findsOneWidget);
    expect(find.text('07:04'), findsOneWidget);
    expect(find.text('23:08'), findsOneWidget);
    expect(find.text('08:05'), findsOneWidget);
    expect(find.text('09:07'), findsOneWidget);
  });

  testWidgets('orienta como iniciar uma conversa vazia', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ConversaDetalheTela(
          conversa: conversa,
          idUsuario: 1,
          usarRealtime: false,
          carregarMensagens: () async => {
            'sucesso': true,
            'dados': <Mensagem>[],
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Comece a conversa'), findsOneWidget);
    expect(
      find.text('Envie uma mensagem para combinar os detalhes da carona.'),
      findsOneWidget,
    );
    expect(find.byType(TextField), findsOneWidget);
  });

  testWidgets('explica falha ao carregar mensagens', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ConversaDetalheTela(
          conversa: conversa,
          idUsuario: 1,
          usarRealtime: false,
          carregarMensagens: () async => {
            'sucesso': false,
            'mensagem': 'Sem conexão',
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Não foi possível carregar as mensagens'), findsOneWidget);
    expect(find.text('Sem conexão'), findsOneWidget);
    expect(find.byIcon(Icons.refresh_rounded), findsOneWidget);
  });

  testWidgets('conversa encerrada fica somente para leitura', (tester) async {
    final conversaEncerrada = Conversa(
      id: conversa.id,
      status: 'CANCELADA_PASSAGEIRO',
      idSolicitacao: conversa.idSolicitacao,
      idPassageiro: conversa.idPassageiro,
      passageiro: conversa.passageiro,
      idMotorista: conversa.idMotorista,
      motorista: conversa.motorista,
      idCarona: conversa.idCarona,
      destino: conversa.destino,
      dataInicio: conversa.dataInicio,
      horario: conversa.horario,
      criadoEm: conversa.criadoEm,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: ConversaDetalheTela(
          conversa: conversaEncerrada,
          idUsuario: 1,
          usarRealtime: false,
          carregarMensagens: () async => {
            'sucesso': true,
            'dados': <Mensagem>[],
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Conversa encerrada'), findsNWidgets(2));
    expect(
      find.text('Esta conversa foi encerrada antes do envio de mensagens.'),
      findsOneWidget,
    );
    expect(
      find.text(
        'O histórico continua disponível, mas novas mensagens não podem ser enviadas.',
      ),
      findsOneWidget,
    );
    expect(find.byType(TextField), findsNothing);
    expect(find.byTooltip('Enviar mensagem'), findsNothing);
  });
}
