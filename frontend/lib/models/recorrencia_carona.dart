import 'carona.dart';

class RecorrenciaCarona {
  final int id;
  final bool ativa;
  final Carona configuracao;

  const RecorrenciaCarona({
    required this.id,
    required this.ativa,
    required this.configuracao,
  });

  factory RecorrenciaCarona.fromJson(Map<String, dynamic> json) {
    return RecorrenciaCarona(
      id: (json['idRecorrencia'] as num).toInt(),
      ativa: json['ativa'] == true,
      configuracao: Carona.fromJson({
        ...Map<String, dynamic>.from(json['dados'] as Map),
        'idCarona': 0,
        'recorrente': true,
      }),
    );
  }
}
