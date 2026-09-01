class SupabaseConfig {
  const SupabaseConfig._();

  static const url = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://kytkkjvzhvwjqzyaujak.supabase.co',
  );
  static const publishableKey = String.fromEnvironment(
    'SUPABASE_PUBLISHABLE_KEY',
    defaultValue: 'sb_publishable_76RHUiHgII8ENgRUMyLGmQ_ZL6zbx-h',
  );

  static bool get configurado => url.isNotEmpty && publishableKey.isNotEmpty;
}
