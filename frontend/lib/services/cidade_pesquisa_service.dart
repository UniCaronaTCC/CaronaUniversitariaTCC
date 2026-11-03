import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../models/campus_destino.dart';

class CidadePesquisaService {
  final FlutterSecureStorage storage;

  const CidadePesquisaService({this.storage = const FlutterSecureStorage()});

  String _chave(int idUsuario) {
    if (idUsuario <= 0) throw ArgumentError.value(idUsuario, 'idUsuario');
    return 'cidade_pesquisa_v1_$idUsuario';
  }

  Future<CidadeCampus?> carregar(int idUsuario) async {
    final salvo = await storage.read(key: _chave(idUsuario));
    if (salvo == null) return null;
    try {
      final json = jsonDecode(salvo);
      if (json is! Map<String, dynamic>) return null;
      final cidade = json['cidade'];
      final uf = json['uf'];
      if (cidade is! String ||
          cidade.trim().length < 2 ||
          cidade.trim().length > 100 ||
          uf is! String ||
          !CidadeCampus.estados.containsKey(uf)) {
        return null;
      }
      return CidadeCampus(cidade.trim(), uf);
    } on FormatException {
      return null;
    }
  }

  Future<void> salvar(int idUsuario, CidadeCampus cidade) async {
    final chave = _chave(idUsuario);
    final nome = cidade.cidade.trim();
    if (nome.length < 2 ||
        nome.length > 100 ||
        !CidadeCampus.estados.containsKey(cidade.uf)) {
      throw const FormatException('Cidade invalida');
    }
    await storage.write(
      key: chave,
      value: jsonEncode({'cidade': nome, 'uf': cidade.uf}),
    );
  }

  Future<void> usarLocalizacaoAtual(int idUsuario) =>
      storage.delete(key: _chave(idUsuario));
}
