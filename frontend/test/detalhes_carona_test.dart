import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uni_carona/home/detalhes_carona.dart';
import 'package:uni_carona/models/carona.dart';
import 'package:uni_carona/services/auth_service.dart';

void main() {
  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
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
    );

    await tester.pumpWidget(
      MaterialApp(home: DetalhesCaronaTela(carona: carona)),
    );

    expect(find.text('Detalhes da carona'), findsOneWidget);
    expect(find.text('João'), findsOneWidget);
    expect(find.text('R\$ 5,50'), findsOneWidget);
    expect(find.text('19:00'), findsOneWidget);
    expect(find.text('UniSalesiano, Araçatuba, SP'), findsOneWidget);
    expect(find.text('Araçatuba, SP'), findsOneWidget);
    expect(find.text('3 vagas'), findsOneWidget);
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
}
