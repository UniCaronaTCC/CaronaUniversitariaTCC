import '../utils/conversores_json.dart';

class Notificacao {
  final int id;
  final String tipo;
  final String titulo;
  final String descricao;
  final DateTime criadoEm;
  final DateTime? lidaEm;
  final Map<String, dynamic> referencias;

  const Notificacao({
    required this.id,
    required this.tipo,
    required this.titulo,
    required this.descricao,
    required this.criadoEm,
    this.lidaEm,
    this.referencias = const {},
  });

  factory Notificacao.fromJson(Map<String, dynamic> json) {
    final id = converterJsonParaInt(json['id']);
    final data = DateTime.tryParse(json['criadoEm']?.toString() ?? '');
    final referencias = json['referencias'];
    if (id <= 0 ||
        data == null ||
        json['titulo'] is! String ||
        referencias is! Map) {
      throw const FormatException('Notificacao invalida');
    }
    return Notificacao(
      id: id,
      tipo: json['tipo']?.toString() ?? '',
      titulo: json['titulo'] as String,
      descricao: json['descricao']?.toString() ?? '',
      criadoEm: data.toLocal(),
      lidaEm: json['lidaEm'] == null
          ? null
          : DateTime.parse(json['lidaEm'].toString()).toLocal(),
      referencias: Map<String, dynamic>.from(referencias),
    );
  }
}

class PaginaNotificacoes {
  final List<Notificacao> itens;
  final int totalNaoLidas;
  final bool temMais;
  final int? proximoAntesDe;

  const PaginaNotificacoes({
    required this.itens,
    required this.totalNaoLidas,
    this.temMais = false,
    this.proximoAntesDe,
  });

  factory PaginaNotificacoes.fromJson(Map<String, dynamic> json) {
    if (json['itens'] is! List ||
        json['temMais'] is! bool ||
        json['totalNaoLidas'] is! num) {
      throw const FormatException('Lista de notificacoes invalida');
    }
    final itens = (json['itens'] as List)
        .map(
          (item) =>
              Notificacao.fromJson(Map<String, dynamic>.from(item as Map)),
        )
        .toList();
    final temMais = json['temMais'] as bool;
    final cursor = json['proximoAntesDe'] == null
        ? null
        : converterJsonParaInt(json['proximoAntesDe']);
    final total = converterJsonParaInt(json['totalNaoLidas']);
    if (total < 0 ||
        (temMais && (cursor == null || cursor <= 0 || itens.isEmpty))) {
      throw const FormatException('Paginacao invalida');
    }
    return PaginaNotificacoes(
      itens: itens,
      totalNaoLidas: total,
      temMais: temMais,
      proximoAntesDe: cursor,
    );
  }
}
