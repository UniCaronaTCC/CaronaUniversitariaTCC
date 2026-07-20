import '../models/carona.dart';

class FiltroCaronas {
  // Aplica os filtros sobre as caronas ja carregadas.
  static List<Carona> aplicar({
    required List<Carona> caronas,
    String destino = '',
    DateTime? data,
    int? horarioMinimoEmMinutos,
  }) {
    final destinoNormalizado = _normalizarTexto(destino);

    return caronas.where((carona) {
      final destinoCorresponde =
          destinoNormalizado.isEmpty ||
          _normalizarTexto(carona.destino).contains(destinoNormalizado);

      final dataCorresponde = data == null || _ocorreNaData(carona, data);

      final horarioCorresponde =
          horarioMinimoEmMinutos == null ||
          _converterHorarioEmMinutos(carona.horario) >= horarioMinimoEmMinutos;

      return destinoCorresponde && dataCorresponde && horarioCorresponde;
    }).toList();
  }

  static bool _ocorreNaData(Carona carona, DateTime dataEscolhida) {
    final data = _somenteData(dataEscolhida);
    final inicio = _somenteData(carona.dataInicio);

    if (!carona.recorrente) {
      return data == inicio;
    }

    if (data.isBefore(inicio)) {
      return false;
    }

    if (carona.dataFim != null) {
      final fim = _somenteData(carona.dataFim!);

      if (data.isAfter(fim)) {
        return false;
      }
    }

    final diaSemana = _obterDiaSemana(data);

    return carona.diasSemana.contains(diaSemana);
  }

  static DateTime _somenteData(DateTime data) {
    return DateTime(data.year, data.month, data.day);
  }

  static String _obterDiaSemana(DateTime data) {
    const dias = ['SEG', 'TER', 'QUA', 'QUI', 'SEX', 'SAB', 'DOM'];

    return dias[data.weekday - 1];
  }

  static int _converterHorarioEmMinutos(String horario) {
    final partes = horario.split(':');

    if (partes.length < 2) {
      return 0;
    }

    final hora = int.tryParse(partes[0]) ?? 0;
    final minuto = int.tryParse(partes[1]) ?? 0;

    return (hora * 60) + minuto;
  }

  // Permite buscar mesmo sem digitar os acentos.
  static String _normalizarTexto(String texto) {
    return texto
        .toLowerCase()
        .replaceAll(RegExp(r'[áàãâä]'), 'a')
        .replaceAll(RegExp(r'[éèêë]'), 'e')
        .replaceAll(RegExp(r'[íìîï]'), 'i')
        .replaceAll(RegExp(r'[óòõôö]'), 'o')
        .replaceAll(RegExp(r'[úùûü]'), 'u')
        .replaceAll('ç', 'c')
        .trim();
  }
}
