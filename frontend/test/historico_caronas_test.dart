import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uni_carona/home/historico_caronas.dart';
import 'package:uni_carona/models/carona.dart';
import 'package:uni_carona/models/solicitacao_enviada.dart';

void main() {
  for (final statusCarona in ['ATIVA', 'FINALIZADA']) {
    testWidgets(
      'mantem solicitacao expirada no historico com carona $statusCarona',
      (tester) async {
        final expirada = SolicitacaoEnviada(
          id: 50,
          status: 'EXPIRADA',
          localEmbarque: 'Centro',
          motorista: 'Motorista expirado',
          idCarona: 60,
          destino: 'Campus',
          dataInicio: DateTime(2026, 10, 20),
          horario: '19:00:00',
          valor: 10,
          statusCarona: statusCarona,
          podeAvaliar: true,
        );
        await tester.pumpWidget(
          MaterialApp(
            home: HistoricoCaronasTela(
              carregarOfertas: () async => {
                'sucesso': true,
                'dados': <Carona>[],
              },
              carregarPedidos: () async => {
                'sucesso': true,
                'dados': [expirada],
              },
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Como passageiro'));
        await tester.pumpAndSettle();
        expect(find.text('Caronas encerradas'), findsOneWidget);
        expect(find.text('Motorista expirado'), findsOneWidget);
        expect(find.text('EXPIRADA'), findsOneWidget);
        expect(find.text('FINALIZADA'), findsNothing);
        expect(find.text('PAGAR COM PIX'), findsNothing);
        expect(find.text('CANCELAR PARTICIPAÇÃO'), findsNothing);
        expect(find.text('AVALIAR'), findsNothing);
        final material = tester.widget<Material>(
          find.byKey(const ValueKey('card-pedido-50')),
        );
        expect(material.color, const Color(0xFFF1F1F1));
      },
    );
  }

  testWidgets('separa o histórico de motorista e passageiro', (tester) async {
    final ofertaAtiva = _criarCarona(id: 1);
    final ofertaFinalizada = _criarCarona(id: 2, status: 'FINALIZADA');
    final viagemFinalizada = SolicitacaoEnviada(
      id: 3,
      status: 'ACEITA',
      localEmbarque: 'Praça central',
      motorista: 'Henrique',
      idCarona: 4,
      destino: 'UniSalesiano',
      dataInicio: DateTime(2026, 8, 10),
      horario: '19:00:00',
      valor: 8,
      statusCarona: 'FINALIZADA',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: HistoricoCaronasTela(
          carregarOfertas: () async => {
            'sucesso': true,
            'dados': [ofertaAtiva, ofertaFinalizada],
          },
          carregarPedidos: () async => {
            'sucesso': true,
            'dados': [viagemFinalizada],
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Ofertas ativas'), findsOneWidget);
    expect(find.text('Caronas finalizadas'), findsOneWidget);

    final ofertaCinza = tester.widget<Material>(
      find.byKey(const ValueKey('card-carona-2')),
    );
    expect(ofertaCinza.color, const Color(0xFFF1F1F1));

    await tester.tap(find.text('Como passageiro'));
    await tester.pumpAndSettle();

    expect(find.text('Viagens confirmadas'), findsOneWidget);
    expect(find.text('Caronas encerradas'), findsOneWidget);

    final viagemCinza = tester.widget<Material>(
      find.byKey(const ValueKey('card-pedido-3')),
    );
    expect(viagemCinza.color, const Color(0xFFF1F1F1));
  });
}

Carona _criarCarona({required int id, String status = 'ATIVA'}) {
  return Carona(
    id: id,
    origem: 'Centro',
    destino: 'UniSalesiano',
    dataInicio: DateTime(2026, 8, 10),
    horario: '19:00:00',
    vagas: 3,
    valor: 8,
    recorrente: false,
    diasSemana: const [],
    status: status,
    motorista: 'João',
  );
}
