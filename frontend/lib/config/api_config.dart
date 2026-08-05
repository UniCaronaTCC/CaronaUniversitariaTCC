class ApiConfig {
  // Classe responsável por guardar as configurações da API

  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:3000',
  );
}

// Emulador
// defaultValue: 'http://10.0.2.2:3000', <<

// Celular
// defaultValue: 'http://127.0.0.1:3000', <<