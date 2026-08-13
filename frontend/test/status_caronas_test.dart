import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uni_carona/home/detalhes_carona.dart';
import 'package:uni_carona/models/carona.dart';
import 'package:uni_carona/services/auth_service.dart';
import 'package:uni_carona/widgets/card_carona_disponivel.dart';
import 'package:uni_carona/widgets/status_solicitacao.dart';

void main() {
  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
  });

  test('le o status enviado pelo backend', () {
    final carona = Carona.fromJson({
      'idCarona': 1,
      'origem': 'Rua A',
      'destino': 'Universidade',
      'dataInicio': '2026-08-04',
      'horario': '19:00:00',
      'vagas': 2,
      'valor': '5.50',
      'recorrente': false,
      'diasSemana': [],
      'status': 'FINALIZADA',
      'usuario': {'idUsuario': 7, 'nome': 'Joao'},
    });

    expect(carona.finalizada, isTrue);
    expect(carona.status, 'FINALIZADA');
    expect(carona.horarioFormatado, '19:00');
    expect(carona.valorFormatado, r'R$ 5,50');
  });

  testWidgets('mostra solicitacao expirada', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: StatusSolicitacao(status: 'EXPIRADA')),
      ),
    );

    expect(find.text('EXPIRADA'), findsOneWidget);
  });

  testWidgets('nao permite alterar uma carona finalizada', (tester) async {
    AuthService.usuarioLogado = {'id': 7, 'nome': 'Joao'};

    final carona = Carona(
      id: 1,
      origem: 'Rua A',
      destino: 'Universidade',
      dataInicio: DateTime(2026, 8, 4),
      horario: '19:00:00',
      vagas: 2,
      valor: 5.5,
      recorrente: false,
      diasSemana: const [],
      status: 'FINALIZADA',
      idMotorista: 7,
      motorista: 'Joao',
    );

    await tester.pumpWidget(
      MaterialApp(home: DetalhesCaronaTela(carona: carona)),
    );

    expect(find.text('FINALIZADA'), findsOneWidget);
    expect(find.text('EDITAR'), findsNothing);
    expect(find.text('EXCLUIR'), findsNothing);

    await AuthService.sair();
  });

  testWidgets('deixa o card da carona finalizada mais neutro', (tester) async {
    final carona = Carona(
      id: 2,
      origem: 'Rua A',
      destino: 'Universidade',
      dataInicio: DateTime(2026, 8, 4),
      horario: '19:00:00',
      vagas: 2,
      valor: 5.5,
      recorrente: false,
      diasSemana: const [],
      status: 'FINALIZADA',
      motorista: 'Joao',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: CardCaronaDisponivel(carona: carona)),
      ),
    );

    final material = tester.widget<Material>(
      find.byKey(const ValueKey('card-carona-2')),
    );

    expect(material.color, const Color(0xFFF1F1F1));
    expect(find.text('FINALIZADA'), findsOneWidget);
  });
}
