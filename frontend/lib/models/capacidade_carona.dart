class CapacidadeCarona {
  final int total;
  final int aceitos;
  final int livres;

  const CapacidadeCarona({
    required this.total,
    required this.aceitos,
    required this.livres,
  });

  factory CapacidadeCarona.fromJson(Map<String, dynamic> json) {
    final total = json['capacidadePassageiros'];
    final aceitos = json['passageirosAceitos'];
    final livres = json['vagasDisponiveis'];
    if (total is! int ||
        aceitos is! int ||
        livres is! int ||
        total < 1 ||
        total > 4 ||
        aceitos < 0 ||
        livres < 0 ||
        aceitos + livres != total) {
      throw const FormatException('Capacidade de carona inválida');
    }
    return CapacidadeCarona(total: total, aceitos: aceitos, livres: livres);
  }
}
