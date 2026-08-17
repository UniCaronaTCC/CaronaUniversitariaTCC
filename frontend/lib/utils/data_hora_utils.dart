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

  static String _doisDigitos(int valor) => valor.toString().padLeft(2, '0');
}
