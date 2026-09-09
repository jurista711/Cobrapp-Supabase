import '../core/supabase_config.dart';
import '../domain/loan_models.dart';

class CustomersRepository {
  const CustomersRepository();

  static const _fields =
      'id, user_id, name, phone, document, address, notes, created_at';

  Future<List<Customer>> listCustomers() async {
    final ownerId = currentOwnerUserId;

    final rows = await supabaseRequired
        .from('cobrapp_customers')
        .select(_fields)
        .eq('user_id', ownerId)
        .order('name');

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
    final ownerId = currentOwnerUserId;

    final row = await supabaseRequired
        .from('cobrapp_customers')
        .insert({
          'user_id': ownerId,
          'name': fullName,
          'document': identification,
          'phone': phone,
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
    final ownerId = currentOwnerUserId;

    final row = await supabaseRequired
        .from('cobrapp_customers')
        .update({
          'name': fullName,
          'document': identification,
          'phone': phone,
          'address': address,
          'notes': notes,
        })
        .eq('id', id)
        .eq('user_id', ownerId)
        .select(_fields)
        .single();

    return _customerFromJson(Map<String, dynamic>.from(row));
  }

  Future<void> deleteCustomer(String id) async {
    final ownerId = currentOwnerUserId;
    await supabaseRequired
        .from('cobrapp_customers')
        .delete()
        .eq('id', id)
        .eq('user_id', ownerId);
  }

  Future<void> deactivateCustomer(String id) async {
    await deleteCustomer(id);
  }

  Customer _customerFromJson(Map<String, dynamic> json) {
    return Customer(
      id: json['id'].toString(),
      fullName: (json['name'] ?? '').toString(),
      identification: (json['document'] ?? '').toString(),
      phone: json['phone'] as String?,
      email: null,
      address: json['address'] as String?,
      notes: json['notes'] as String?,
      active: true,
    );
  }
}
