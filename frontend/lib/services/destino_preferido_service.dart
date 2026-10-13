import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../mapa/models/localizacao_selecionada.dart';

class DestinoPreferidoService {
  final FlutterSecureStorage storage;

  const DestinoPreferidoService({this.storage = const FlutterSecureStorage()});

  String _chave(int idUsuario) {
    if (idUsuario <= 0) throw ArgumentError.value(idUsuario, 'idUsuario');
    return 'destino_preferido_v1_$idUsuario';
  }

  Future<LocalizacaoSelecionada?> carregar(int idUsuario) async {
    final salvo = await storage.read(key: _chave(idUsuario));
    if (salvo == null) return null;
    try {
      final json = jsonDecode(salvo);
      if (json is! Map<String, dynamic>) return null;
      return LocalizacaoSelecionada.fromJson(json);
    } on FormatException {
      return null;
    }
  }

  Future<void> salvar(int idUsuario, LocalizacaoSelecionada destino) async {
    final chave = _chave(idUsuario);
    if (!destino.coordenadasValidas || destino.endereco.trim().isEmpty) {
      throw const FormatException('Destino invalido');
    }
    await storage.write(key: chave, value: jsonEncode(destino.toJson()));
  }
}
