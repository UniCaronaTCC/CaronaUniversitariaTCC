int converterJsonParaInt(dynamic valor) {
  if (valor is int) {
    return valor;
  }

  return int.tryParse(valor?.toString() ?? '') ?? 0;
}

double converterJsonParaDouble(dynamic valor) {
  if (valor is num) {
    return valor.toDouble();
  }

  return double.tryParse(valor?.toString() ?? '') ?? 0;
}

double? converterJsonParaDoubleOpcional(dynamic valor) {
  return valor == null ? null : converterJsonParaDouble(valor);
}

bool converterJsonParaBool(dynamic valor) {
  return valor == true || valor == 1 || valor?.toString() == '1';
}

List<String> converterJsonParaListaString(dynamic valor) {
  if (valor is! List) {
    return [];
  }

  return valor.map((item) => item.toString()).toList();
}
