class FormatadorData {
  const FormatadorData._();

  static String relativa(DateTime data, {DateTime? referencia}) {
    final agora = referencia ?? DateTime.now();
    final diaInformado = DateTime(data.year, data.month, data.day);
    final hoje = DateTime(agora.year, agora.month, agora.day);
    final diferenca = diaInformado.difference(hoje).inDays;

    if (diferenca == 0) {
      return 'Hoje';
    }

    if (diferenca == 1) {
      return 'Amanhã';
    }

    return completa(data);
  }

  static String completa(DateTime data) {
    final dia = data.day.toString().padLeft(2, '0');
    final mes = data.month.toString().padLeft(2, '0');

    return '$dia/$mes';
  }
}
