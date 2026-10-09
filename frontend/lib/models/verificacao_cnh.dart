class VerificacaoCnh {
  final String status;
  final String? categoria;
  final DateTime? validade;

  const VerificacaoCnh({
    this.status = 'NAO_ENVIADA',
    this.categoria,
    this.validade,
  });

  factory VerificacaoCnh.fromPerfil(Map<String, dynamic> perfil) {
    return VerificacaoCnh(
      status: perfil['statusVerificacaoCnh']?.toString() ?? 'NAO_ENVIADA',
      categoria: perfil['cnhCategoria']?.toString().trim().toUpperCase(),
      validade: DateTime.tryParse(perfil['cnhValidade']?.toString() ?? ''),
    );
  }

  bool permiteOferecerCarona([DateTime? agora]) {
    if (status != 'APROVADA' ||
        !RegExp(r'^A?[BCDE]$').hasMatch(categoria ?? '') ||
        validade == null) {
      return false;
    }
    final local = (agora ?? DateTime.now()).toUtc().subtract(
      const Duration(hours: 3),
    );
    final hoje = DateTime(local.year, local.month, local.day);
    final diaValidade = DateTime(
      validade!.year,
      validade!.month,
      validade!.day,
    );
    return !diaValidade.isBefore(hoje);
  }

  String get validadeFormatada => validade == null
      ? ''
      : '${validade!.day.toString().padLeft(2, '0')}/${validade!.month.toString().padLeft(2, '0')}/${validade!.year}';

  String get textoStatus {
    if (permiteOferecerCarona()) return 'CNH conferida';
    if (status == 'APROVADA') return 'CNH precisa ser atualizada';
    if (status == 'RECUSADA') return 'Envie novas fotos da CNH';
    if (status == 'EM_ANALISE') return 'Verificação em andamento';
    return 'Verificar CNH';
  }
}
