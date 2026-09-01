import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uni_carona/home/conversas.dart';
import 'package:uni_carona/models/conversa.dart';
import 'package:uni_carona/models/mensagem.dart';

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
        idCarona: 20,
        destino: 'UniSalesiano',
        dataInicio: DateTime(2026, 9, 2),
        horario: '19:00:00',
        criadoEm: DateTime(2026, 9, 1),
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
    expect(find.text('Carlos'), findsOneWidget);
    expect(find.text('Encerrada'), findsOneWidget);
    expect(find.text('UNESP'), findsOneWidget);
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

    expect(
      find.text('Suas conversas aparecerão após uma carona ser aceita'),
      findsOneWidget,
    );
  });
}
