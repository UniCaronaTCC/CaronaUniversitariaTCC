import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SessaoService {
  const SessaoService._();

  static const _storage = FlutterSecureStorage();
  static const _chaveToken = 'token_usuario';
  static const _chaveUsuario = 'dados_usuario';

  static Future<void> salvar(String token, Map<String, dynamic> usuario) async {
    await _storage.write(key: _chaveToken, value: token);
    await _storage.write(key: _chaveUsuario, value: jsonEncode(usuario));
  }

  static Future<Map<String, dynamic>?> carregar() async {
    final token = await _storage.read(key: _chaveToken);
    final usuarioSalvo = await _storage.read(key: _chaveUsuario);

    if (token == null || usuarioSalvo == null) {
      return null;
    }

    final usuario = jsonDecode(usuarioSalvo);

    if (usuario is! Map) {
      return null;
    }

    return {'token': token, 'usuario': Map<String, dynamic>.from(usuario)};
  }

  static Future<void> limpar() async {
    await _storage.delete(key: _chaveToken);
    await _storage.delete(key: _chaveUsuario);
  }
}
