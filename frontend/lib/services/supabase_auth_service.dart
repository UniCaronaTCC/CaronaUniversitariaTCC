import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/supabase_config.dart';
import '../utils/normalizacao_nome.dart';
import 'cliente_http_com_prazo.dart';

class SupabaseAuthService {
  const SupabaseAuthService._();

  static bool _inicializado = false;
  static Future<String?>? _renovacaoEmAndamento;

  static bool get configurado => SupabaseConfig.configurado;
  static bool get inicializado => _inicializado;

  static SupabaseClient get _cliente => Supabase.instance.client;

  static String? get tokenAtual =>
      _inicializado ? _cliente.auth.currentSession?.accessToken : null;

  static Future<void> inicializar({
    http.Client? cliente,
    FlutterAuthClientOptions authOptions = const FlutterAuthClientOptions(),
  }) async {
    if (!configurado) return;

    await Supabase.initialize(
      url: SupabaseConfig.url,
      publishableKey: SupabaseConfig.publishableKey,
      httpClient: cliente ?? ClienteHttpComPrazo(),
      authOptions: authOptions,
    );
    _inicializado = true;
  }

  static Future<AuthResponse> entrar(String email, String senha) {
    return _cliente.auth.signInWithPassword(email: email, password: senha);
  }

  static Future<String?> renovarSessao() async {
    if (!_inicializado) {
      return null;
    }

    final renovacaoAtual = _renovacaoEmAndamento;
    if (renovacaoAtual != null) {
      return renovacaoAtual.timeout(const Duration(seconds: 20));
    }

    final renovacao = _executarRenovacao().whenComplete(() {
      _renovacaoEmAndamento = null;
    });
    _renovacaoEmAndamento = renovacao;
    return renovacao.timeout(const Duration(seconds: 20));
  }

  static Future<String?> _executarRenovacao() async {
    try {
      final resposta = await _cliente.auth.refreshSession();
      return resposta.session?.accessToken;
    } on AuthSessionMissingException {
      return null;
    } on AuthApiException catch (erro) {
      if (const {
        'refresh_token_not_found',
        'refresh_token_already_used',
        'session_not_found',
        'session_expired',
        'user_not_found',
        'user_banned',
      }.contains(erro.code)) {
        return null;
      }
      rethrow;
    }
  }

  static Future<AuthResponse> cadastrar(
    String nome,
    String email,
    String senha,
  ) {
    return _cliente.auth.signUp(
      email: email,
      password: senha,
      data: {'nome': normalizarNomeUsuario(nome)},
    );
  }

  static Future<void> confirmarEmail(String email, String codigo) async {
    await _cliente.auth.verifyOTP(
      email: email,
      token: codigo,
      type: OtpType.signup,
    );
    await sair();
  }

  static Future<void> reenviarCodigo(String email) async {
    await _cliente.auth.resend(type: OtpType.signup, email: email);
  }

  static Future<void> solicitarRedefinicao(String email) async {
    await _cliente.auth.resetPasswordForEmail(email);
  }

  static Future<void> redefinirSenha(
    String email,
    String codigo,
    String novaSenha,
  ) async {
    await _cliente.auth.verifyOTP(
      email: email,
      token: codigo,
      type: OtpType.recovery,
    );
    await _cliente.auth.updateUser(UserAttributes(password: novaSenha));
    await sair();
  }

  static Future<void> sair() async {
    if (_inicializado) {
      await _cliente.auth.signOut();
    }
  }
}
