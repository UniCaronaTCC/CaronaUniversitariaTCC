import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uni_carona/services/auth_service.dart';
import 'package:uni_carona/services/sessao_service.dart';

void main() {
  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    AuthService.tokenUsuarioLogado = null;
    AuthService.usuarioLogado = null;
  });

  test('não reutiliza token salvo fora da sessão do Supabase', () async {
    await SessaoService.salvar('token-teste', {
      'id': 1,
      'nome': 'João',
      'email': 'joao@email.com',
    });

    await AuthService.carregarSessao();

    expect(AuthService.tokenUsuarioLogado, isNull);
    expect(AuthService.usuarioLogado, isNull);
    expect(AuthService.estaLogado, isFalse);
  });

  test('remove a sessão ao sair', () async {
    await SessaoService.salvar('token-teste', {'id': 1, 'nome': 'João'});

    await AuthService.carregarSessao();
    await AuthService.sair();
    final sessao = await SessaoService.carregar();

    expect(sessao, isNull);
    expect(AuthService.estaLogado, isFalse);
  });
}
