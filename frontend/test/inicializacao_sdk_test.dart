import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uni_carona/auth/login.dart';
import 'package:uni_carona/main.dart' as app;
import 'package:uni_carona/services/auth_service.dart';
import 'package:uni_carona/services/sessao_service.dart';
import 'package:uni_carona/services/supabase_auth_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final mensageiro =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  const preferencias = MethodChannel('plugins.flutter.io/shared_preferences');
  const links = MethodChannel('com.llfbandit.app_links/events');

  setUpAll(() async {
    mensageiro.setMockMethodCallHandler(
      preferencias,
      (call) async => call.method == 'getAll' ? <String, Object>{} : true,
    );
    mensageiro.setMockMethodCallHandler(links, (_) async => null);
    await SupabaseAuthService.inicializar(
      cliente: MockClient(
        (_) async => throw StateError('Sem rede neste teste'),
      ),
      authOptions: const FlutterAuthClientOptions(
        persistSession: false,
        autoRefreshToken: false,
        detectSessionInUri: false,
        authFlowType: AuthFlowType.implicit,
      ),
    );
  });
  tearDownAll(() async {
    await Supabase.instance.dispose();
    mensageiro.setMockMethodCallHandler(preferencias, null);
    mensageiro.setMockMethodCallHandler(links, null);
    AuthService.tokenUsuarioLogado = null;
    AuthService.usuarioLogado = null;
  });

  testWidgets(
    'main mantem restauracao real sem reutilizar token legado fora do SDK',
    (tester) async {
      FlutterSecureStorage.setMockInitialValues({});
      await SessaoService.salvar('token-legado-sintetico', {
        'id': 7,
        'nome': 'Pessoa teste',
      });
      AuthService.tokenUsuarioLogado = null;
      AuthService.usuarioLogado = null;
      var requisicoes = 0;
      await http.runWithClient(
        () async {
          try {
            app.main();
            await tester.pump();
            await tester.pumpAndSettle();
            expect(SupabaseAuthService.inicializado, isTrue);
            expect(find.byType(LoginTela), findsOneWidget);
            expect(find.byKey(const ValueKey('tela-abertura')), findsNothing);
            expect(AuthService.estaLogado, isFalse);
            expect(await SessaoService.carregar(), isNull);
            expect(requisicoes, 0);
            expect(tester.takeException(), isNull);
          } finally {
            await tester.pumpWidget(const SizedBox());
          }
        },
        () => MockClient((request) async {
          requisicoes++;
          throw StateError(
            'Inicializacao sem sessao nao deve consultar a rede',
          );
        }),
      );
    },
  );
}
