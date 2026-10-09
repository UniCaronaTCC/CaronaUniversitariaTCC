String normalizarNomeUsuario(String nome) {
  final nomeLimpo = nome.trim();
  if (nomeLimpo.isEmpty) return nomeLimpo;

  final inicial = String.fromCharCode(nomeLimpo.runes.first);
  return inicial.toUpperCase() + nomeLimpo.substring(inicial.length);
}
