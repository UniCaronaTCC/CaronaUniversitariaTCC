import 'ponto_embarque.dart';

import '../utils/conversores_json.dart';
import '../utils/data_hora_utils.dart';
import '../utils/formatador_data.dart';
import '../utils/formatador_moeda.dart';

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

  final List<PontoEmbarque> pontosEmbarque;

  final DateTime dataInicio;
  final DateTime? dataFim;
  final String horario;
  final int vagas;
  final double valor;
  final bool recorrente;
  final List<String> diasSemana;
  final String? observacoes;
  final String status;
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
    this.pontosEmbarque = const [],
    required this.dataInicio,
    this.dataFim,
    required this.horario,
    required this.vagas,
    required this.valor,
    required this.recorrente,
    required this.diasSemana,
    this.observacoes,
    this.status = 'ATIVA',
    this.idMotorista = 0,
    required this.motorista,
  });

  // Converte a resposta JSON do backend em uma Carona.
  factory Carona.fromJson(Map<String, dynamic> json) {
    final usuario = json['usuario'];

    final pontosRecebidos = json['pontosEmbarque'];

    final pontosEmbarque = <PontoEmbarque>[];

    if (pontosRecebidos is List) {
      for (final item in pontosRecebidos) {
        if (item is Map) {
          pontosEmbarque.add(
            PontoEmbarque.fromJson(
              Map<String, dynamic>.from(item),
            ),
          );
        }
      }
    }

    return Carona(
      id: converterJsonParaInt(json['idCarona']),

      origem: json['origem']?.toString() ?? '',
      origemCidade: json['origemCidade']?.toString(),
      origemLatitude: converterJsonParaDoubleOpcional(
        json['origemLatitude'],
      ),
      origemLongitude: converterJsonParaDoubleOpcional(
        json['origemLongitude'],
      ),

      destino: json['destino']?.toString() ?? '',
      destinoCidade: json['destinoCidade']?.toString(),
      destinoLatitude: converterJsonParaDoubleOpcional(
        json['destinoLatitude'],
      ),
      destinoLongitude: converterJsonParaDoubleOpcional(
        json['destinoLongitude'],
      ),

      pontosEmbarque: pontosEmbarque,

      dataInicio: DateTime.parse(
        json['dataInicio'].toString(),
      ),

      dataFim: json['dataFim'] == null
          ? null
          : DateTime.tryParse(
        json['dataFim'].toString(),
      ),

      horario: json['horario']?.toString() ?? '',

      vagas: converterJsonParaInt(
        json['vagas'],
      ),

      valor: converterJsonParaDouble(
        json['valor'],
      ),

      recorrente: converterJsonParaBool(
        json['recorrente'],
      ),

      diasSemana: converterJsonParaListaString(
        json['diasSemana'],
      ),

      observacoes: json['observacoes']?.toString(),

      status: json['status']?.toString() ?? 'ATIVA',

      idMotorista: usuario is Map
          ? converterJsonParaInt(
        usuario['idUsuario'] ?? usuario['id'],
      )
          : 0,

      motorista: usuario is Map
          ? usuario['nome']?.toString() ?? 'Motorista'
          : 'Motorista',
    );
  }

  // Formata a data para o padrao brasileiro.
  String get dataFormatada =>
      FormatadorData.relativa(dataInicio);

  // Remove os segundos do horario retornado pelo MySQL.
  String get horarioFormatado =>
      DataHoraUtils.formatarHorarioTexto(horario);

  // Formata o valor no padrao brasileiro.
  String get valorFormatado =>
      formatarDoubleComoMoedaReal(valor);

  bool get finalizada => status == 'FINALIZADA';

  // Monta o periodo exibido no card.
  String get periodoFormatado {
    if (recorrente && diasSemana.isNotEmpty) {
      return '${diasSemana.join(', ')} - $horarioFormatado';
    }

    return '$dataFormatada - $horarioFormatado';
  }
}