import 'package:flutter/material.dart';

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
  }) => showTimePicker(
    context: context,
    initialTime: horarioInicial ?? TimeOfDay.now(),
    helpText: textoAjuda,
    cancelText: 'CANCELAR',
    confirmText: 'CONFIRMAR',
  );

  static String formatarDataExibicao(DateTime data) =>
      '${_doisDigitos(data.day)}/${_doisDigitos(data.month)}/${data.year}';

  static String formatarDataBackend(DateTime data) =>
      '${data.year}-${_doisDigitos(data.month)}-${_doisDigitos(data.day)}';

  static String formatarHorario(TimeOfDay horario) =>
      '${_doisDigitos(horario.hour)}:${_doisDigitos(horario.minute)}';

  static String _doisDigitos(int valor) => valor.toString().padLeft(2, '0');
}
