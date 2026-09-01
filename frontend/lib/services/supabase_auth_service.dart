import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/supabase_config.dart';

class SupabaseAuthService {
  const SupabaseAuthService._();

  static bool _inicializado = false;

  static bool get configurado => SupabaseConfig.configurado;

  static SupabaseClient get _cliente => Supabase.instance.client;

  static String? get tokenAtual =>
      _inicializado ? _cliente.auth.currentSession?.accessToken : null;

  static Future<void> inicializar() async {
    if (!configurado) return;

    await Supabase.initialize(
      url: SupabaseConfig.url,
      publishableKey: SupabaseConfig.publishableKey,
    );
    _inicializado = true;
  }

  static Future<AuthResponse> entrar(String email, String senha) {
    return _cliente.auth.signInWithPassword(email: email, password: senha);
  }

  static Future<AuthResponse> cadastrar(
    String nome,
    String email,
    String senha,
  ) {
    return _cliente.auth.signUp(
      email: email,
      password: senha,
      data: {'nome': nome},
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
