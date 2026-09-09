import 'license_service.dart';
import 'supabase_config.dart';

Future<dynamic> licensedRpc(
  String functionName, {
  Map<String, dynamic> params = const <String, dynamic>{},
}) async {
  final deviceId = await const LicenseService().getDeviceId();
  return supabaseRequired.rpc(
    functionName,
    params: <String, dynamic>{
      'p_device_id': deviceId,
      ...params,
    },
  );
}
