import '../utils/formatador_data.dart';

class Carona {
  final int id;
  final String origem;
  final String? origemCidade;
  final double? origemLatitude;
  final double? origemLongitude;

  final String destino;
  final String? destinoCidade;
  final double? destinoLatitude;
  final double? destinoLongitude;

  final DateTime dataInicio;
  final DateTime? dataFim;
  final String horario;
  final int vagas;
  final double valor;
  final bool recorrente;
  final List<String> diasSemana;
  final String? observacoes;
  final int idMotorista;
  final String motorista;

  const Carona({
    required this.id,
    required this.origem,
    this.origemCidade,
    this.origemLatitude,
    this.origemLongitude,
    required this.destino,
    this.destinoCidade,
    this.destinoLatitude,
    this.destinoLongitude,
    required this.dataInicio,
    this.dataFim,
    required this.horario,
    required this.vagas,
    required this.valor,
    required this.recorrente,
    required this.diasSemana,
    this.observacoes,
    this.idMotorista = 0,
    required this.motorista,
  });

  // Converte a resposta JSON do backend em uma Carona.
  factory Carona.fromJson(Map<String, dynamic> json) {
    final usuario = json['usuario'];

    return Carona(
      id: _converterInt(json['idCarona']),
      origem: json['origem']?.toString() ?? '',
      origemCidade: json['origemCidade']?.toString(),
      origemLatitude: _converterDoubleOpcional(json['origemLatitude']),
      origemLongitude: _converterDoubleOpcional(json['origemLongitude']),
      destino: json['destino']?.toString() ?? '',
      destinoCidade: json['destinoCidade']?.toString(),
      destinoLatitude: _converterDoubleOpcional(json['destinoLatitude']),
      destinoLongitude: _converterDoubleOpcional(json['destinoLongitude']),
      dataInicio: DateTime.parse(json['dataInicio'].toString()),
      dataFim: json['dataFim'] == null
          ? null
          : DateTime.tryParse(json['dataFim'].toString()),
      horario: json['horario']?.toString() ?? '',
      vagas: _converterInt(json['vagas']),
      valor: _converterDouble(json['valor']),
      recorrente: _converterBool(json['recorrente']),
      diasSemana: _converterDias(json['diasSemana']),
      observacoes: json['observacoes']?.toString(),
      idMotorista: usuario is Map
          ? _converterInt(usuario['idUsuario'] ?? usuario['id'])
          : 0,
      motorista: usuario is Map
          ? usuario['nome']?.toString() ?? 'Motorista'
          : 'Motorista',
    );
  }

  // Formata a data para o padrao brasileiro.
  String get dataFormatada => FormatadorData.relativa(dataInicio);

  // Remove os segundos do horario retornado pelo MySQL.
  String get horarioFormatado {
    final partes = horario.split(':');

    if (partes.length < 2) {
      return horario;
    }

    return '${partes[0]}:${partes[1]}';
  }

  // Formata o valor no padrao brasileiro.
  String get valorFormatado {
    final texto = valor.toStringAsFixed(2).replaceAll('.', ',');

    return 'R\$ $texto';
  }

  // Monta o periodo exibido no card.
  String get periodoFormatado {
    if (recorrente && diasSemana.isNotEmpty) {
      return '${diasSemana.join(', ')} - $horarioFormatado';
    }

    return '$dataFormatada - $horarioFormatado';
  }

  static int _converterInt(dynamic valor) {
    if (valor is int) {
      return valor;
    }

    return int.tryParse(valor?.toString() ?? '') ?? 0;
  }

  static double _converterDouble(dynamic valor) {
    if (valor is num) {
      return valor.toDouble();
    }

    return double.tryParse(valor?.toString() ?? '') ?? 0;
  }

  static double? _converterDoubleOpcional(dynamic valor) {
    if (valor == null) {
      return null;
    }

    return _converterDouble(valor);
  }

  static bool _converterBool(dynamic valor) {
    return valor == true || valor == 1 || valor?.toString() == '1';
  }

  static List<String> _converterDias(dynamic valor) {
    if (valor is! List) {
      return [];
    }

    return valor.map((dia) => dia.toString()).toList();
  }
}
