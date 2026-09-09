import 'package:supabase_flutter/supabase_flutter.dart';

const _supabaseUrl = String.fromEnvironment('SUPABASE_URL');
const _supabasePublishableKey = String.fromEnvironment('SUPABASE_ANON_KEY');
const _ownerEmail = String.fromEnvironment('SUPABASE_OWNER_EMAIL');
const _ownerPassword = String.fromEnvironment('SUPABASE_OWNER_PASSWORD');

bool get hasSupabaseConfig =>
    _supabaseUrl.isNotEmpty &&
    _supabasePublishableKey.isNotEmpty &&
    _ownerEmail.isNotEmpty &&
    _ownerPassword.isNotEmpty;

Future<bool> initSupabase() async {
  if (!hasSupabaseConfig) {
    throw StateError(
      'Supabase não configurado. Configure SUPABASE_URL, SUPABASE_ANON_KEY, SUPABASE_OWNER_EMAIL e SUPABASE_OWNER_PASSWORD nos Secrets do GitHub.',
    );
  }

  await Supabase.initialize(
    url: _supabaseUrl,
    publishableKey: _supabasePublishableKey,
  );

  final client = Supabase.instance.client;
  if (client.auth.currentSession == null) {
    await client.auth.signInWithPassword(
      email: _ownerEmail,
      password: _ownerPassword,
    );
  }

  if (client.auth.currentUser == null) {
    throw StateError('Login invisível do dono não retornou usuário autenticado.');
  }

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

String get currentOwnerUserId {
  final user = supabaseRequired.auth.currentUser;
  if (user == null) {
    throw StateError('Usuário dono não autenticado.');
  }
  return user.id;
}
