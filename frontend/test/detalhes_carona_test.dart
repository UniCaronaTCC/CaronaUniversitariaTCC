import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uni_carona/home/detalhes_carona.dart';
import 'package:uni_carona/models/carona.dart';
import 'package:uni_carona/services/auth_service.dart';
import 'package:uni_carona/widgets/painel_solicitacoes_carona.dart';

void main() {
  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    AuthService.usuarioLogado = null;
  });

  testWidgets('exibe os dados principais da carona', (tester) async {
    final carona = Carona(
      id: 1,
      origem: 'Rua de origem',
      origemCidade: 'Araçatuba, SP',
      destino: 'UniSalesiano, Araçatuba, SP',
      dataInicio: DateTime(2026, 7, 22),
      horario: '19:00:00',
      vagas: 3,
      valor: 5.5,
      recorrente: true,
      diasSemana: const ['SEG', 'QUA', 'SEX'],
      observacoes: 'Saída no horário combinado',
      motorista: 'João',
      veiculoModelo: 'Onix',
      veiculoCor: 'Branco',
      veiculoPlaca: '***1D23',
    );

    await tester.pumpWidget(
      MaterialApp(home: DetalhesCaronaTela(carona: carona)),
    );

    expect(find.text('Detalhes da carona'), findsOneWidget);
    expect(find.text('João'), findsOneWidget);
    expect(find.text('R\$ 5,50'), findsOneWidget);
    expect(find.text('22/07/2026\n19:00'), findsOneWidget);
    expect(find.text('SEG, QUA, SEX'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('Origem')).dy,
      lessThan(tester.getTopLeft(find.text('Pontos de embarque')).dy),
    );
    expect(
      tester.getTopLeft(find.text('Pontos de embarque')).dy,
      lessThan(tester.getTopLeft(find.text('Destino')).dy),
    );
    expect(find.text('UniSalesiano, Araçatuba, SP'), findsOneWidget);
    expect(find.text('Araçatuba, SP'), findsNothing);
    expect(find.text('3 vagas'), findsOneWidget);
    expect(find.text('Onix • Branco • ***1D23'), findsOneWidget);
    expect(find.text('SOLICITAR VAGA'), findsOneWidget);
  });

  testWidgets('não permite solicitar vaga na própria carona', (tester) async {
    AuthService.usuarioLogado = {'id': 7, 'nome': 'João'};

    final carona = Carona(
      id: 1,
      origem: 'Rua de origem',
      destino: 'UniSalesiano',
      dataInicio: DateTime(2026, 7, 22),
      horario: '19:00:00',
      vagas: 3,
      valor: 5.5,
      recorrente: false,
      diasSemana: const [],
      idMotorista: 7,
      motorista: 'João',
    );

    await tester.pumpWidget(
      MaterialApp(home: DetalhesCaronaTela(carona: carona)),
    );

    expect(find.text('SOLICITAR VAGA'), findsNothing);
    expect(find.text('EDITAR'), findsOneWidget);
    expect(find.text('EXCLUIR'), findsOneWidget);
    expect(find.byType(BottomNavigationBar), findsOneWidget);

    await AuthService.sair();
  });

  for (final status in ['ATIVA', 'FINALIZADA', 'CANCELADA']) {
    testWidgets('consulta do motorista sem gerenciamento: $status', (
      tester,
    ) async {
      AuthService.usuarioLogado = {'id': 7, 'nome': 'João'};
      final carona = Carona(
        id: 1,
        idMotorista: 7,
        motorista: 'João',
        origem: 'Centro',
        destino: 'UniSalesiano',
        dataInicio: DateTime(2026, 9, 22),
        horario: '19:00:00',
        vagas: 3,
        valor: 10,
        recorrente: true,
        diasSemana: const ['SEG', 'TER'],
        status: status,
      );
      await tester.pumpWidget(
        MaterialApp(
          home: DetalhesCaronaTela(
            carona: carona,
            somenteConsulta: true,
            indiceNavegacaoOrigem: 1,
          ),
        ),
      );
      expect(find.text('Detalhes da carona'), findsOneWidget);
      expect(find.text('22/09/2026\n19:00'), findsOneWidget);
      expect(find.text('SEG, TER'), findsOneWidget);
      expect(find.text('Gerenciar carona'), findsNothing);
      expect(find.text('EDITAR'), findsNothing);
      expect(find.text('EXCLUIR'), findsNothing);
      expect(find.text('INICIAR CORRIDA'), findsNothing);
      expect(find.text('SOLICITAR VAGA'), findsNothing);
      expect(find.text('Vagas disponíveis'), findsNothing);
      expect(find.byType(PainelSolicitacoesCarona), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('consulta cabe em tela estreita com texto ampliado', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final carona = Carona(
      id: 1,
      motorista: 'João Henrique de Souza Martins',
      origem: 'Avenida Joaquim Pompeu de Toledo, Araçatuba',
      destino: 'UniSalesiano, Rodovia Senador Teotônio Vilela',
      dataInicio: DateTime(2026, 9, 22),
      horario: '19:00:00',
      vagas: 3,
      valor: 9999.99,
      recorrente: false,
      diasSemana: const [],
      status: 'FINALIZADA',
    );
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(1.5)),
          child: child!,
        ),
        home: DetalhesCaronaTela(carona: carona, somenteConsulta: true),
      ),
    );
    expect(find.text('Carona finalizada'), findsOneWidget);
    expect(find.text('Vagas disponíveis'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.drag(
      find.byType(SingleChildScrollView),
      const Offset(0, -550),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
