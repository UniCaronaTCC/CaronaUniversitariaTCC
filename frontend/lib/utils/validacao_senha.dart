class ValidacaoSenha {
  const ValidacaoSenha._();

  static const mensagem =
      'A senha deve ter pelo menos 8 caracteres, com letras e números';

  static bool ehValida(String senha) {
    final temLetra = RegExp(r'[A-Za-zÀ-ÖØ-öø-ÿ]').hasMatch(senha);
    final temNumero = RegExp(r'[0-9]').hasMatch(senha);

    return senha.length >= 8 && temLetra && temNumero;
  }
}
