import '../core/licensed_rpc.dart';
import '../domain/loan_models.dart';

class CustomersRepository {
  const CustomersRepository();

  Future<List<Customer>> listCustomers() async {
    final rows = await licensedRpc('cobrapp_app_list_customers');
    return (rows as List)
        .map<Customer>((row) => _customerFromJson(Map<String, dynamic>.from(row as Map)))
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
    final rows = await licensedRpc(
      'cobrapp_app_create_customer',
      params: {
        'p_name': fullName,
        'p_document': identification,
        'p_phone': phone,
        'p_address': address,
        'p_notes': notes,
      },
    );
    final list = rows as List;
    if (list.isEmpty) throw StateError('O Supabase não retornou o cliente criado.');
    return _customerFromJson(Map<String, dynamic>.from(list.first as Map));
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
    final rows = await licensedRpc(
      'cobrapp_app_update_customer',
      params: {
        'p_id': id,
        'p_name': fullName,
        'p_document': identification,
        'p_phone': phone,
        'p_address': address,
        'p_notes': notes,
      },
    );
    final list = rows as List;
    if (list.isEmpty) throw StateError('Cliente não encontrado para atualizar.');
    return _customerFromJson(Map<String, dynamic>.from(list.first as Map));
  }

  Future<void> deleteCustomer(String id) async {
    await licensedRpc('cobrapp_app_delete_customer', params: {'p_id': id});
  }

  Future<void> deactivateCustomer(String id) async => deleteCustomer(id);

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
