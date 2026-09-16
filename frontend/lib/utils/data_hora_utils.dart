import 'package:flutter/material.dart';

import '../widgets/seletor_horario.dart';

class DataHoraUtils {
  const DataHoraUtils._();

  static Future<DateTime?> selecionarData(
    BuildContext context, {
    DateTime? dataInicial,
    required String textoAjuda,
  }) {
    final agora = DateTime.now();
    final hoje = DateTime(agora.year, agora.month, agora.day);

    return showDatePicker(
      context: context,
      initialDate: dataInicial ?? hoje,
      firstDate: hoje,
      lastDate: DateTime(hoje.year + 2, hoje.month, hoje.day),
      helpText: textoAjuda,
      cancelText: 'CANCELAR',
      confirmText: 'CONFIRMAR',
    );
  }

  static Future<TimeOfDay?> selecionarHorario(
    BuildContext context, {
    TimeOfDay? horarioInicial,
    required String textoAjuda,
  }) => SeletorHorario.abrir(
    context,
    titulo: textoAjuda,
    horarioInicial: horarioInicial,
  );

  static String formatarDataExibicao(DateTime data) =>
      '${_doisDigitos(data.day)}/${_doisDigitos(data.month)}';

  static String formatarDataBackend(DateTime data) =>
      '${data.year}-${_doisDigitos(data.month)}-${_doisDigitos(data.day)}';

  static String formatarHorario(TimeOfDay horario) =>
      '${_doisDigitos(horario.hour)}:${_doisDigitos(horario.minute)}';

  static String formatarHorarioTexto(String horario) {
    final partes = horario.split(':');

    return partes.length >= 2 ? '${partes[0]}:${partes[1]}' : horario;
  }

  static DateTime? interpretarInstanteEmBrasilia(Object? valor) {
    if (valor == null) return null;

    final instante = DateTime.tryParse(valor.toString());
    if (instante == null) return null;

    final brasilia = instante.toUtc().subtract(const Duration(hours: 3));
    return DateTime(
      brasilia.year,
      brasilia.month,
      brasilia.day,
      brasilia.hour,
      brasilia.minute,
      brasilia.second,
      brasilia.millisecond,
      brasilia.microsecond,
    );
  }

  static String _doisDigitos(int valor) => valor.toString().padLeft(2, '0');
}
