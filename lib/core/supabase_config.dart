import 'package:supabase_flutter/supabase_flutter.dart';

const _supabaseUrl = String.fromEnvironment('SUPABASE_URL');
const _supabasePublishableKey = String.fromEnvironment('SUPABASE_ANON_KEY');

bool get hasSupabaseConfig =>
    _supabaseUrl.isNotEmpty && _supabasePublishableKey.isNotEmpty;

Future<void> initSupabase() async {
  if (!hasSupabaseConfig) {
    throw StateError(
      'SUPABASE_URL e SUPABASE_ANON_KEY são obrigatórios via --dart-define.',
    );
  }

  await Supabase.initialize(
    url: _supabaseUrl,
    publishableKey: _supabasePublishableKey,
  );
}

SupabaseClient get supabase => Supabase.instance.client;
