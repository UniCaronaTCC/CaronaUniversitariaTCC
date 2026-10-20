import 'dart:typed_data';
import 'ocr_cnh_stub.dart'
    if (dart.library.io) 'ocr_cnh_mobile.dart'
    as plataforma;

typedef LerCnh = Future<Map<String, dynamic>> Function(Uint8List foto);

Future<Map<String, dynamic>> lerCnhNoCelular(Uint8List foto) =>
    plataforma.lerCnh(foto);
