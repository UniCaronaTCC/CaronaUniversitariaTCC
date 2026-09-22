import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uni_carona/config/app_colors.dart';
import 'package:uni_carona/home/conversas.dart';
import 'package:uni_carona/models/conversa.dart';
import 'package:uni_carona/models/mensagem.dart';
import 'package:uni_carona/widgets/avatar_usuario.dart';

void main() {
  testWidgets('lista conversas e destaca conversa encerrada', (tester) async {
    final conversas = [
      Conversa(
        id: 1,
        status: 'ACEITA',
        idSolicitacao: 10,
        idPassageiro: 1,
        passageiro: 'João',
        idMotorista: 2,
        motorista: 'Maria',
        fotoMotorista: 'https://exemplo.com/maria.jpg',
        idCarona: 20,
        destino: 'UniSalesiano',
        dataInicio: DateTime(2026, 9, 2),
        horario: '19:00:00',
        criadoEm: DateTime(2026, 9, 1),
        mensagensNaoLidas: 3,
        ultimaMensagem: Mensagem(
          id: 2,
          conteudo: 'Te encontro na entrada',
          criadoEm: DateTime(2026, 9, 1, 18),
          idRemetente: 2,
        ),
      ),
      Conversa(
        id: 2,
        status: 'CANCELADA_PASSAGEIRO',
        idSolicitacao: 11,
        idPassageiro: 1,
        passageiro: 'João',
        idMotorista: 3,
        motorista: 'Carlos',
        idCarona: 21,
        destino: 'UNESP',
        dataInicio: DateTime(2026, 9, 3),
        horario: '18:00:00',
        criadoEm: DateTime(2026, 9, 1),
      ),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: ConversasTela(
          idUsuario: 1,
          carregarConversas: () async => {'sucesso': true, 'dados': conversas},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Maria'), findsOneWidget);
    expect(find.text('Te encontro na entrada'), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
    expect(find.byKey(const ValueKey('mensagens-nao-lidas-1')), findsOneWidget);
    expect(find.text('Carlos'), findsOneWidget);
    expect(find.text('Encerrada'), findsOneWidget);
    expect(find.text('UNESP'), findsOneWidget);

    final avatar = tester.widget<AvatarUsuario>(
      find.byKey(const ValueKey('avatar-conversa-1')),
    );
    expect(avatar.urlFoto, 'https://exemplo.com/maria.jpg');

    final cardComMensagemNova = tester.widget<Material>(
      find
          .ancestor(
            of: find.byKey(const ValueKey('mensagens-nao-lidas-1')),
            matching: find.byType(Material),
          )
          .first,
    );
    expect(cardComMensagemNova.color, const Color(0xFFFBF5FF));

    final nomeComMensagemNova = tester.widget<Text>(find.text('Maria'));
    expect(nomeComMensagemNova.style?.color, AppColors.primary);
    expect(nomeComMensagemNova.style?.fontWeight, FontWeight.w700);

    final nomeSemMensagemNova = tester.widget<Text>(find.text('Carlos'));
    expect(nomeSemMensagemNova.style?.color, AppColors.text);
    expect(nomeSemMensagemNova.style?.fontWeight, FontWeight.w600);
  });

  testWidgets('mostra estado vazio sem conversas', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ConversasTela(
          idUsuario: 1,
          carregarConversas: () async => {
            'sucesso': true,
            'dados': <Conversa>[],
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Nenhuma conversa ainda'), findsOneWidget);
    expect(
      find.text(
        'Quando uma solicitação de carona for aceita, a conversa aparecerá aqui.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('explica o carregamento das conversas', (tester) async {
    final resposta = Completer<Map<String, dynamic>>();

    await tester.pumpWidget(
      MaterialApp(
        home: ConversasTela(
          idUsuario: 1,
          carregarConversas: () => resposta.future,
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Carregando conversas'), findsOneWidget);
    expect(find.text('Buscando suas conversas mais recentes.'), findsOneWidget);

    resposta.complete({'sucesso': true, 'dados': <Conversa>[]});
    await tester.pumpAndSettle();
  });

  testWidgets('mostra erro e permite carregar novamente', (tester) async {
    var tentativas = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: ConversasTela(
          idUsuario: 1,
          carregarConversas: () async {
            tentativas++;
            if (tentativas == 1) {
              return {'sucesso': false, 'mensagem': 'Sem conexão'};
            }
            return {'sucesso': true, 'dados': <Conversa>[]};
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Não foi possível carregar'), findsOneWidget);
    expect(find.text('Sem conexão'), findsOneWidget);
    expect(find.byIcon(Icons.refresh_rounded), findsOneWidget);

    await tester.tap(find.text('Tentar novamente'));
    await tester.pumpAndSettle();

    expect(tentativas, 2);
    expect(find.text('Nenhuma conversa ainda'), findsOneWidget);
  });
}
