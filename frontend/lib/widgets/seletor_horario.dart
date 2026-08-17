import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../config/app_colors.dart';

class SeletorHorario {
  const SeletorHorario._();

  static Future<TimeOfDay?> abrir(
    BuildContext context, {
    required String titulo,
    TimeOfDay? horarioInicial,
  }) {
    final horario = horarioInicial ?? TimeOfDay.now();
    final agora = DateTime.now();
    var horarioEscolhido = horario;

    return showModalBottomSheet<TimeOfDay>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  titulo,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 180,
                child: CupertinoDatePicker(
                  mode: CupertinoDatePickerMode.time,
                  use24hFormat: true,
                  initialDateTime: DateTime(
                    agora.year,
                    agora.month,
                    agora.day,
                    horario.hour,
                    horario.minute,
                  ),
                  onDateTimeChanged: (novoHorario) {
                    horarioEscolhido = TimeOfDay(
                      hour: novoHorario.hour,
                      minute: novoHorario.minute,
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('CANCELAR'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primary,
                      ),
                      onPressed: () => Navigator.pop(context, horarioEscolhido),
                      child: const Text('CONFIRMAR'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
