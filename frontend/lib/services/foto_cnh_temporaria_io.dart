import 'dart:io';

Future<void> descartarFotoCnh(String caminho) async {
  try {
    await File(caminho).delete();
  } on FileSystemException {
    // O sistema também pode remover a foto do cache antes deste descarte.
  }
}
