import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uni_carona/home/minhas_caronas.dart';
import 'package:uni_carona/models/solicitacao_enviada.dart';
import 'package:uni_carona/models/solicitacao_recebida.dart';
import 'package:uni_carona/services/mensagem_service.dart';
import 'package:uni_carona/services/solicitacao_service.dart';

void main() {
  testWidgets(
    'expiradas saem de Recebidas e Enviadas quando atualiza o estado',
    (tester) async {
      var expirada = false;
      await tester.pumpWidget(
        MaterialApp(
          home: MinhasCaronasTela(
            carregarRecebidas: () async => {
              'sucesso': true,
              'dados': [
                SolicitacaoRecebida(
                  id: 50,
                  status: expirada ? 'EXPIRADA' : 'ACEITA',
                  localEmbarque: 'Centro',
                  embarqueLatitude: -21.2,
                  embarqueLongitude: -50.4,
                  passageiro: 'Passageiro expirado',
                  idCarona: 60,
                  destino: 'Campus',
                  dataInicio: DateTime(2026, 10, 20),
                  horario: '19:00:00',
                ),
              ],
            },
            carregarEnviadas: () async => {
              'sucesso': true,
              'dados': [
                SolicitacaoEnviada(
                  id: 51,
                  status: expirada ? 'EXPIRADA' : 'ACEITA',
                  localEmbarque: 'Centro',
                  motorista: 'Motorista expirado',
                  idCarona: 61,
                  destino: 'Campus',
                  dataInicio: DateTime(2026, 10, 20),
                  horario: '19:00:00',
                  valor: 10,
                ),
              ],
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Passageiro expirado'), findsOneWidget);
      await tester.tap(find.text('Enviadas'));
      await tester.pumpAndSettle();
      expect(find.text('Motorista expirado'), findsOneWidget);
      expect(find.text('PAGAR COM PIX'), findsOneWidget);
      expirada = true;
      MensagemService.versaoConversas.value++;
      await tester.pumpAndSettle();
      expect(find.text('Motorista expirado'), findsNothing);
      expect(find.text('PAGAR COM PIX'), findsNothing);
      expect(SolicitacaoService.totalSolicitacoesPendentes.value, 0);
      await tester.tap(find.text('Recebidas'));
      await tester.pumpAndSettle();
      expect(find.text('Passageiro expirado'), findsNothing);
      expect(find.text('CANCELAR PARTICIPAÇÃO'), findsNothing);
      expect(find.text('Nenhuma solicitação recebida'), findsOneWidget);
    },
  );

  testWidgets(
    'remove aceite antigo quando a carona termina sem apagar o aceite',
    (tester) async {
      var finalizada = false;
      await tester.pumpWidget(
        MaterialApp(
          home: MinhasCaronasTela(
            carregarRecebidas: () async => {
              'sucesso': true,
              'dados': [
                SolicitacaoRecebida(
                  id: 12,
                  status: 'ACEITA',
                  localEmbarque: 'Local teste',
                  embarqueLatitude: -21.2,
                  embarqueLongitude: -50.4,
                  passageiro: 'henrique',
                  idCarona: 13,
                  destino: 'UniSALESIANO',
                  dataInicio: DateTime(2026, 9, 22),
                  horario: '19:01:00',
                  statusCarona: finalizada ? 'FINALIZADA' : 'ATIVA',
                ),
              ],
            },
            carregarEnviadas: () async => {
              'sucesso': true,
              'dados': <SolicitacaoEnviada>[],
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('henrique'), findsOneWidget);
      expect(find.text('CANCELAR PARTICIPAÇÃO'), findsOneWidget);
      finalizada = true;
      MensagemService.versaoConversas.value++;
      await tester.pumpAndSettle();
      expect(find.text('henrique'), findsNothing);
      expect(find.text('CANCELAR PARTICIPAÇÃO'), findsNothing);
      expect(find.text('Nenhuma solicitação recebida'), findsOneWidget);
    },
  );
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
