import 'package:supabase_flutter/supabase_flutter.dart';

const _supabaseUrl = String.fromEnvironment('SUPABASE_URL');
const _supabasePublishableKey = String.fromEnvironment('SUPABASE_ANON_KEY');

bool get hasSupabaseConfig =>
    _supabaseUrl.isNotEmpty && _supabasePublishableKey.isNotEmpty;

Future<bool> initSupabase() async {
  if (!hasSupabaseConfig) {
    throw StateError(
      'Supabase não configurado. Configure SUPABASE_URL e SUPABASE_ANON_KEY nos Secrets do GitHub.',
    );
  }

  await Supabase.initialize(
    url: _supabaseUrl,
    publishableKey: _supabasePublishableKey,
  );
  return true;
}

SupabaseClient? get supabaseOrNull {
  if (!hasSupabaseConfig) {
    return null;
  }
  return Supabase.instance.client;
}

SupabaseClient get supabaseRequired {
  final client = supabaseOrNull;
  if (client == null) {
    throw StateError('Supabase não configurado neste APK.');
  }
  return client;
}
