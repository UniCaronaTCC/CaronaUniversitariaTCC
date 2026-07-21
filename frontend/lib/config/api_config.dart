class ApiConfig {
  // Classe responsável por guardar as configurações da API

  // No emulador Android, 10.0.2.2 aponta para o localhost do computador.
  // Em outro ambiente, use --dart-define=API_BASE_URL=http://endereco:porta.
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:3000',
  );
}
