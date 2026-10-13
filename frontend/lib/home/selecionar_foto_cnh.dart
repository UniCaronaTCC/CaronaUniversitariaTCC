import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'camera_cnh.dart';
import 'recortar_cnh.dart';

Future<Uint8List?> selecionarFotoCnh(
  BuildContext context, {
  required String lado,
  required ImageSource origem,
  Future<XFile?> Function()? capturar,
  Future<XFile?> Function()? escolher,
  Future<Uint8List?> Function(Uint8List)? recortar,
}) async {
  if (origem == ImageSource.camera && capturar == null) {
    return fotografarCnhGuiada(context, lado);
  }
  final selecionar = origem == ImageSource.camera ? capturar : escolher;
  final arquivo =
      await (selecionar?.call() ??
          ImagePicker().pickImage(
            source: ImageSource.gallery,
            maxWidth: 2600,
            maxHeight: 2600,
            imageQuality: 95,
            requestFullMetadata: false,
          ));
  if (arquivo == null) return null;
  final bytes = await arquivo.readAsBytes();
  try {
    if (!context.mounted) return null;
    if (bytes.isEmpty || bytes.length > 5 * 1024 * 1024) {
      throw const FormatException(
        'A foto deve ter até 5 MB. Escolha outra foto.',
      );
    }
    return await (recortar?.call(bytes) ?? recortarCnh(context, bytes));
  } finally {
    bytes.fillRange(0, bytes.length, 0);
  }
}
