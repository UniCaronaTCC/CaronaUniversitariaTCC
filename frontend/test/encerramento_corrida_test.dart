import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uni_carona/home/caronas_publicadas.dart';
import 'package:uni_carona/home/corrida_em_andamento.dart';
import 'package:uni_carona/home/detalhes_carona.dart';
import 'package:uni_carona/home/historico_caronas.dart';
import 'package:uni_carona/models/carona.dart';
import 'package:uni_carona/models/solicitacao_enviada.dart';
import 'package:uni_carona/services/auth_service.dart';
import 'package:uni_carona/services/estado_corrida.dart';

Carona carona(String status, {int id = 1}) => Carona(
  id: id,
  origem: 'Praça Central',
  destino: 'Campus',
  dataInicio: DateTime(2026, 10, 27),
  horario: '18:30:00',
  vagas: 2,
  valor: 8,
  recorrente: false,
  diasSemana: const [],
  status: status,
  idMotorista: 7,
  motorista: 'Motorista',
);
final encerrada = carona('ENCERRADA_POR_TEMPO');

void main() {
  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    AuthService.usuarioLogado = null;
    AuthService.tokenUsuarioLogado = null;
  });

  test('encerramento por tempo e diferente de conclusao normal', () {
    expect(encerrada.encerrada, isTrue);
    expect(encerrada.encerradaPorTempo, isTrue);
    expect(encerrada.finalizada, isFalse);
    expect(encerrada.emAndamento, isFalse);
    final pedido = SolicitacaoEnviada(
      id: 1,
      status: 'ACEITA',
      localEmbarque: 'Centro',
      motorista: 'Motorista',
      idCarona: 1,
      destino: 'Campus',
      dataInicio: DateTime(2026, 10, 27),
      horario: '18:30:00',
      valor: 8,
      statusCarona: 'ENCERRADA_POR_TEMPO',
    );
    expect(pedido.arquivada, isTrue);
    expect(pedido.caronaFinalizada, isFalse);
    expect(pedido.podeCancelar, isFalse);
    expect(pedido.podePagarPix, isFalse);
    expect(pedido.podeAcompanharCorrida, isFalse);
  });

  testWidgets('retira a corrida antiga de Suas caronas', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: CaronasPublicadasTela(
          carregarPublicadas: () async => {
            'sucesso': true,
            'dados': [encerrada],
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Você não possui caronas ativas'), findsOneWidget);
    expect(find.byKey(const ValueKey('card-carona-1')), findsNothing);
  });

  testWidgets('historico guarda o motivo e detalhes nao oferecem continuar', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: HistoricoCaronasTela(
          carregarOfertas: () async => {
            'sucesso': true,
            'dados': [encerrada],
          },
          carregarPedidos: () async => {
            'sucesso': true,
            'dados': <SolicitacaoEnviada>[],
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Caronas encerradas'), findsOneWidget);
    expect(find.text('Encerrada automaticamente por tempo'), findsOneWidget);
    AuthService.usuarioLogado = {'id': 7};
    await tester.pumpWidget(
      MaterialApp(home: DetalhesCaronaTela(carona: encerrada)),
    );
    await tester.pumpAndSettle();
    expect(find.text('CONTINUAR CORRIDA'), findsNothing);
    expect(find.text('INICIAR CORRIDA'), findsNothing);
    expect(find.text('EDITAR'), findsNothing);
    expect(find.text('Encerrada automaticamente por tempo'), findsOneWidget);
    AuthService.usuarioLogado = null;
  });

  testWidgets('tela aberta para acompanhamento e volta ao estado encerrado', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: CorridaEmAndamentoTela(
          carona: carona('EM_ANDAMENTO'),
          carregarEstado: (_) async => {'sucesso': true, 'dados': encerrada},
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Encerrada automaticamente por tempo'), findsOneWidget);
    expect(find.text('FINALIZAR'), findsNothing);
    await tester.pump(const Duration(minutes: 2));
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'consulta periodica nao encerra por falta de conexao e reage ao servidor',
    (tester) async {
      var consultas = 0;
      var informarEncerramento = false;
      var avisos = 0;
      final estado = EstadoCorrida(
        idCarona: 1,
        onEncerrada: (_) => avisos++,
        carregar: (_) async {
          consultas++;
          return informarEncerramento
              ? {'sucesso': true, 'dados': encerrada}
              : {'sucesso': false};
        },
      );
      estado.iniciar();
      await tester.pump();
      await tester.pump(const Duration(seconds: 30));
      expect(avisos, 0);
      expect(consultas, 2);
      informarEncerramento = true;
      await tester.pump(const Duration(seconds: 30));
      expect(avisos, 1);
      await tester.pump(const Duration(minutes: 1));
      expect(consultas, 3);
      estado.dispose();
    },
  );

  test(
    'nao duplica consulta e descarta resposta apos sair da corrida',
    () async {
      final resposta = Completer<Map<String, dynamic>>();
      var consultas = 0;
      var avisos = 0;
      final estado = EstadoCorrida(
        idCarona: 1,
        onEncerrada: (_) => avisos++,
        carregar: (_) {
          consultas++;
          return resposta.future;
        },
      );
      final primeira = estado.consultar();
      await estado.consultar();
      expect(consultas, 1);
      estado.dispose();
      resposta.complete({'sucesso': true, 'dados': encerrada});
      await primeira;
      expect(avisos, 0);
    },
  );
}
