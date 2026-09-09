import 'package:supabase_flutter/supabase_flutter.dart';

const _supabaseUrl = String.fromEnvironment('SUPABASE_URL');
const _supabasePublishableKey = String.fromEnvironment('SUPABASE_ANON_KEY');

bool get hasSupabaseConfig =>
    _supabaseUrl.isNotEmpty && _supabasePublishableKey.isNotEmpty;

Future<bool> initSupabase() async {
  if (!hasSupabaseConfig) {
    return false;
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
