import 'package:diacritic/diacritic.dart';
import 'package:latlong2/latlong.dart';

import '../models/carona.dart';

class FiltroCaronas {
  static List<Carona> aplicar({
    required List<Carona> caronas,
    String destino = '',
    DateTime? data,
    int? horarioPreferidoEmMinutos,
    double? destinoLatitude,
    double? destinoLongitude,
    String? cidadePreferida,
  }) {
    final destinoNormalizado = _normalizarTexto(destino);
    final cidadeNormalizada = _normalizarTexto(cidadePreferida ?? '');
    final possuiCoordenadas =
        destinoLatitude != null && destinoLongitude != null;
    final priorizarCidade =
        destinoNormalizado.isEmpty &&
        !possuiCoordenadas &&
        cidadeNormalizada.isNotEmpty;

    final resultado = caronas.where((carona) {
      final destinoCorresponde =
          destinoNormalizado.isEmpty ||
          possuiCoordenadas ||
          _normalizarTexto(carona.destino).contains(destinoNormalizado);

      final dataCorresponde = data == null || _ocorreNaData(carona, data);

      return destinoCorresponde && dataCorresponde;
    }).toList();

    resultado.sort((primeira, segunda) {
      if (priorizarCidade) {
        final primeiraEhDaCidade = _caronaEhDaCidade(
          primeira,
          cidadeNormalizada,
        );
        final segundaEhDaCidade = _caronaEhDaCidade(segunda, cidadeNormalizada);

        if (primeiraEhDaCidade != segundaEhDaCidade) {
          return primeiraEhDaCidade ? -1 : 1;
        }
      }

      if (possuiCoordenadas) {
        final distanciaPrimeira = _calcularDistancia(
          primeira,
          destinoLatitude,
          destinoLongitude,
        );
        final distanciaSegunda = _calcularDistancia(
          segunda,
          destinoLatitude,
          destinoLongitude,
        );
        final comparacaoDistancia = distanciaPrimeira.compareTo(
          distanciaSegunda,
        );

        if (comparacaoDistancia != 0) {
          return comparacaoDistancia;
        }
      }

      if (horarioPreferidoEmMinutos != null) {
        final diferencaPrimeira =
            (_converterHorarioEmMinutos(primeira.horario) -
                    horarioPreferidoEmMinutos)
                .abs();
        final diferencaSegunda =
            (_converterHorarioEmMinutos(segunda.horario) -
                    horarioPreferidoEmMinutos)
                .abs();
        final comparacaoHorario = diferencaPrimeira.compareTo(diferencaSegunda);

        if (comparacaoHorario != 0) {
          return comparacaoHorario;
        }
      }

      final comparacaoData = primeira.dataInicio.compareTo(segunda.dataInicio);

      if (comparacaoData != 0) {
        return comparacaoData;
      }

      return _converterHorarioEmMinutos(
        primeira.horario,
      ).compareTo(_converterHorarioEmMinutos(segunda.horario));
    });

    return resultado;
  }

  static bool _caronaEhDaCidade(Carona carona, String cidadeNormalizada) {
    final locais = [
      carona.origemCidade,
      carona.destinoCidade,
      carona.origem,
      carona.destino,
    ];

    return locais.any(
      (local) => _normalizarTexto(local ?? '').contains(cidadeNormalizada),
    );
  }

  static double _calcularDistancia(
    Carona carona,
    double latitude,
    double longitude,
  ) {
    if (carona.destinoLatitude == null || carona.destinoLongitude == null) {
      return double.infinity;
    }

    return const Distance().as(
      LengthUnit.Kilometer,
      LatLng(latitude, longitude),
      LatLng(carona.destinoLatitude!, carona.destinoLongitude!),
    );
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
    return removeDiacritics(texto).toLowerCase().trim();
  }
}
