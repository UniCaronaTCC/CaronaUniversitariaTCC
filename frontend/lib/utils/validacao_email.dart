class ValidacaoEmail {
  const ValidacaoEmail._();

  static const mensagem = 'Informe um e-mail válido';

  static bool ehValido(String email) {
    final emailLimpo = email.trim();
    final formatoEmail = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

    return formatoEmail.hasMatch(emailLimpo);
  }
}
