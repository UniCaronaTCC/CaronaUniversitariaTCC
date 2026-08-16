class PontoEmbarque {
  final int? id;
  final String? nome;
  final String endereco;
  final double latitude;
  final double longitude;
  final int ordem;

  const PontoEmbarque({
    this.id,
    this.nome,
    required this.endereco,
    required this.latitude,
    required this.longitude,
    required this.ordem,
  });

  factory PontoEmbarque.fromJson(Map<String, dynamic> json) {
    return PontoEmbarque(
      id: json['idPontoEmbarque'] == null
          ? null
          : int.tryParse(json['idPontoEmbarque'].toString()),
      nome: json['nome']?.toString(),
      endereco: json['endereco']?.toString() ?? '',
      latitude: double.tryParse(json['latitude'].toString()) ?? 0,
      longitude: double.tryParse(json['longitude'].toString()) ?? 0,
      ordem: int.tryParse(json['ordem'].toString()) ?? 1,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'nome': nome,
      'endereco': endereco,
      'latitude': latitude,
      'longitude': longitude,
    };
  }
}