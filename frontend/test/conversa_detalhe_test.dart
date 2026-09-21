import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uni_carona/home/conversa_detalhe.dart';
import 'package:uni_carona/models/conversa.dart';
import 'package:uni_carona/models/mensagem.dart';

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

  ScrollPosition posicaoLista(WidgetTester tester) {
    final lista = tester.widget<ListView>(
      find.byKey(const ValueKey('lista-mensagens')),
    );
    return lista.controller!.position;
  }

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

    expect(find.text('Esta conversa foi encerrada'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
    expect(find.byTooltip('Enviar mensagem'), findsNothing);
  });
}
