class Instituicao {
  final int id;
  final String nome;
  final String? sigla;
  final String campus;
  final String municipio;
  final String uf;
  final double? distanciaKm;

  const Instituicao({
    required this.id,
    required this.nome,
    required this.sigla,
    required this.campus,
    required this.municipio,
    required this.uf,
    this.distanciaKm,
  });

  factory Instituicao.fromJson(Map<String, dynamic> json) {
    return Instituicao(
      id: int.parse(json['id'].toString()),
      nome: json['nome']?.toString() ?? '',
      sigla: json['sigla']?.toString(),
      campus: json['campus']?.toString() ?? '',
      municipio: json['municipio']?.toString() ?? '',
      uf: json['uf']?.toString() ?? '',
      distanciaKm: double.tryParse(json['distanciaKm']?.toString() ?? ''),
    );
  }
}
