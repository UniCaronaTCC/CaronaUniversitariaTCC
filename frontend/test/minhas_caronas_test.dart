import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uni_carona/home/minhas_caronas.dart';
import 'package:uni_carona/models/solicitacao_enviada.dart';
import 'package:uni_carona/models/solicitacao_recebida.dart';

void main() {
  testWidgets('abre nas recebidas e separa as solicitações enviadas', (
    tester,
  ) async {
    final recebida = SolicitacaoRecebida(
      id: 1,
      status: 'PENDENTE',
      localEmbarque: 'Praça central',
      embarqueLatitude: -21.2,
      embarqueLongitude: -50.4,
      passageiro: 'Passageiro teste',
      idCarona: 10,
      destino: 'Campus motorista',
      dataInicio: DateTime(2026, 10, 10),
      horario: '19:00:00',
    );
    final enviada = SolicitacaoEnviada(
      id: 2,
      status: 'PENDENTE',
      localEmbarque: 'Terminal',
      motorista: 'Motorista teste',
      idCarona: 20,
      destino: 'Campus passageiro',
      dataInicio: DateTime(2026, 10, 11),
      horario: '18:00:00',
      valor: 6,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: MinhasCaronasTela(
          carregarRecebidas: () async => {
            'sucesso': true,
            'dados': [recebida],
          },
          carregarEnviadas: () async => {
            'sucesso': true,
            'dados': [enviada],
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Recebidas'), findsOneWidget);
    expect(find.text('Enviadas'), findsOneWidget);
    expect(find.text('Publicadas'), findsNothing);
    expect(find.text('Passageiro teste'), findsOneWidget);
    expect(
      find.text('Solicitações de passageiros para suas caronas.'),
      findsOneWidget,
    );

    await tester.tap(find.text('Enviadas'));
    await tester.pumpAndSettle();

    expect(find.text('Motorista teste'), findsOneWidget);
    expect(
      find.text('Solicitações que você enviou como passageiro.'),
      findsOneWidget,
    );
  });

  testWidgets('notifica o passageiro quando a solicitação foi aceita', (
    tester,
  ) async {
    final enviadaAceita = SolicitacaoEnviada(
      id: 3,
      status: 'ACEITA',
      localEmbarque: 'Terminal',
      motorista: 'Motorista teste',
      idCarona: 30,
      destino: 'Campus passageiro',
      dataInicio: DateTime(2026, 10, 11),
      horario: '18:00:00',
      valor: 10,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: MinhasCaronasTela(
          carregarRecebidas: () async => {
            'sucesso': true,
            'dados': <SolicitacaoRecebida>[],
          },
          carregarEnviadas: () async => {
            'sucesso': true,
            'dados': [enviadaAceita],
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('1'), findsNWidgets(2));
    expect(find.byType(Badge), findsNWidgets(2));
  });
}
