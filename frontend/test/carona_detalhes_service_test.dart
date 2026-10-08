import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:uni_carona/models/carona.dart';
import 'package:uni_carona/services/auth_service.dart';
import 'package:uni_carona/services/carona_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    AuthService.tokenUsuarioLogado = 'token-teste';
  });
  tearDown(() {
    AuthService.tokenUsuarioLogado = null;
  });

  test(
    'consulta carona especifica com autenticacao e dados completos',
    () async {
      final resultado = await http.runWithClient(
        () => CaronaService.buscarDetalhesCarona(20),
        () => MockClient((request) async {
          expect(request.url.path.endsWith('/caronas/20'), isTrue);
          expect(request.method, 'GET');
          expect(request.headers['Authorization'], 'Bearer token-teste');
          return http.Response(
            jsonEncode({
              'sucesso': true,
              'dados': {
                'idCarona': 20,
                'origem': 'Centro',
                'destino': 'Campus',
                'dataInicio': '2026-10-08',
                'horario': '19:00:00',
                'vagas': 2,
                'valor': 8,
                'status': 'FINALIZADA',
                'observacoes': 'Portaria principal',
                'usuario': {
                  'idUsuario': 2,
                  'nome': 'Maria',
                  'veiculo': {
                    'modelo': 'Onix',
                    'cor': 'Branco',
                    'placa': '***1D23',
                  },
                },
              },
            }),
            200,
          );
        }),
      );
      expect(resultado['sucesso'], isTrue);
      final carona = resultado['dados'] as Carona;
      expect(carona.id, 20);
      expect(carona.status, 'FINALIZADA');
      expect(carona.origem, 'Centro');
      expect(carona.veiculoModelo, 'Onix');
      expect(carona.veiculoPlaca, '***1D23');
      expect(carona.observacoes, 'Portaria principal');
    },
  );

  test('nao consulta carona sem sessao', () async {
    AuthService.tokenUsuarioLogado = null;
    final resultado = await CaronaService.buscarDetalhesCarona(20);
    expect(resultado['sucesso'], isFalse);
    expect(resultado['mensagem'], 'Usuário não está logado');
  });

  test('preserva mensagem de carona inexistente ou nao autorizada', () async {
    final resultado = await http.runWithClient(
      () => CaronaService.buscarDetalhesCarona(20),
      () => MockClient(
        (_) async => http.Response(
          jsonEncode({'message': 'Carona não encontrada'}),
          404,
        ),
      ),
    );
    expect(resultado['sucesso'], isFalse);
    expect(resultado['mensagem'], 'Carona não encontrada');
  });

  test('resposta incompleta nao abre detalhes invalidos', () async {
    final resultado = await http.runWithClient(
      () => CaronaService.buscarDetalhesCarona(20),
      () => MockClient((_) async => http.Response('{"dados":{}}', 200)),
    );
    expect(resultado['sucesso'], isFalse);
  });
}
