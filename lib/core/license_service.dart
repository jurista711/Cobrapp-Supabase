import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

import 'supabase_config.dart';

class LicenseService {
  const LicenseService();

  static const _deviceIdKey = 'cobrapp_device_id';

  Future<String> getDeviceId() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_deviceIdKey);
    if (saved != null && saved.trim().length >= 10) {
      return saved;
    }

    final random = Random.secure();
    final parts = List.generate(4, (_) => random.nextInt(0xFFFFFFFF).toRadixString(16).padLeft(8, '0'));
    final id = 'cobrapp-${DateTime.now().microsecondsSinceEpoch}-${parts.join()}';
    await prefs.setString(_deviceIdKey, id);
    return id;
  }

  Future<LicenseResult> validateDevice() async {
    final client = supabaseOrNull;
    if (client == null) {
      return const LicenseResult(ok: false, message: 'Supabase não conectado neste APK.');
    }

    final deviceId = await getDeviceId();
    final response = await client.rpc(
      'cobrapp_app_validate_device',
      params: {'p_device_id': deviceId},
    );

    return LicenseResult.fromJson(Map<String, dynamic>.from(response as Map));
  }

  Future<LicenseResult> activateDevice(String activationCode) async {
    final client = supabaseOrNull;
    if (client == null) {
      return const LicenseResult(ok: false, message: 'Supabase não conectado neste APK.');
    }

    final deviceId = await getDeviceId();
    final response = await client.rpc(
      'cobrapp_app_activate_device',
      params: {
        'p_activation_code': activationCode.trim(),
        'p_device_id': deviceId,
        'p_device_name': 'Aparelho CobrApp',
      },
    );

    return LicenseResult.fromJson(Map<String, dynamic>.from(response as Map));
  }
}

class LicenseResult {
  const LicenseResult({required this.ok, required this.message});

  final bool ok;
  final String message;

  factory LicenseResult.fromJson(Map<String, dynamic> json) {
    return LicenseResult(
      ok: json['ok'] == true,
      message: (json['message'] ?? '').toString(),
    );
  }
}
