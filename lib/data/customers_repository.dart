import '../core/supabase_config.dart';
import '../domain/loan_models.dart';

class CustomersRepository {
  const CustomersRepository();

  static const _fields =
      'id, full_name, identification, phone, email, address, notes, active';

  Future<List<Customer>> listCustomers() async {
    final client = supabaseOrNull;
    if (client == null) {
      return const <Customer>[];
    }

    final rows = await client
        .from('customers')
        .select(_fields)
        .eq('active', true)
        .order('full_name');

    return rows
        .map<Customer>((row) => _customerFromJson(Map<String, dynamic>.from(row)))
        .toList();
  }

  Future<Customer> createCustomer({
    required String fullName,
    required String identification,
    String? phone,
    String? email,
    String? address,
    String? notes,
  }) async {
    final client = supabaseOrNull;
    if (client == null) {
      throw StateError('Supabase não configurado neste APK.');
    }

    final row = await client
        .from('customers')
        .insert({
          'full_name': fullName,
          'identification': identification,
          'phone': phone,
          'email': email,
          'address': address,
          'notes': notes,
        })
        .select(_fields)
        .single();

    return _customerFromJson(Map<String, dynamic>.from(row));
  }

  Future<Customer> updateCustomer({
    required String id,
    required String fullName,
    required String identification,
    String? phone,
    String? email,
    String? address,
    String? notes,
  }) async {
    final client = supabaseOrNull;
    if (client == null) {
      throw StateError('Supabase não configurado neste APK.');
    }

    final row = await client
        .from('customers')
        .update({
          'full_name': fullName,
          'identification': identification,
          'phone': phone,
          'email': email,
          'address': address,
          'notes': notes,
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('id', id)
        .select(_fields)
        .single();

    return _customerFromJson(Map<String, dynamic>.from(row));
  }

  Future<void> deleteCustomer(String id) async {
    final client = supabaseOrNull;
    if (client == null) {
      throw StateError('Supabase não configurado neste APK.');
    }

    await client.from('customers').delete().eq('id', id);
  }

  Future<void> deactivateCustomer(String id) async {
    final client = supabaseOrNull;
    if (client == null) {
      throw StateError('Supabase não configurado neste APK.');
    }

    await client
        .from('customers')
        .update({'active': false, 'updated_at': DateTime.now().toIso8601String()})
        .eq('id', id);
  }

  Customer _customerFromJson(Map<String, dynamic> json) {
    return Customer(
      id: json['id'].toString(),
      fullName: json['full_name'].toString(),
      identification: json['identification'].toString(),
      phone: json['phone'] as String?,
      email: json['email'] as String?,
      address: json['address'] as String?,
      notes: json['notes'] as String?,
      active: json['active'] as bool? ?? true,
    );
  }
}
