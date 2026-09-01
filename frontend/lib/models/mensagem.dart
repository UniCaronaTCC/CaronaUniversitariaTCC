import '../utils/conversores_json.dart';

class Mensagem {
  final int id;
  final String conteudo;
  final DateTime criadoEm;
  final int idRemetente;

  const Mensagem({
    required this.id,
    required this.conteudo,
    required this.criadoEm,
    required this.idRemetente,
  });

  factory Mensagem.fromJson(Map<String, dynamic> json) {
    final remetente = json['remetente'];

    if (remetente is! Map) {
      throw const FormatException('Mensagem incompleta');
    }

    return Mensagem(
      id: converterJsonParaInt(json['id']),
      conteudo: json['conteudo']?.toString() ?? '',
      criadoEm: DateTime.parse(json['criadoEm'].toString()).toLocal(),
      idRemetente: converterJsonParaInt(remetente['id']),
    );
  }
}
