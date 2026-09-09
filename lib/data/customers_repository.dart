import '../core/supabase_config.dart';
import '../domain/loan_models.dart';

class CustomersRepository {
  const CustomersRepository();

  Future<List<Customer>> listCustomers() async {
    final rows = await supabase
        .from('customers')
        .select('id, full_name, identification, phone, email, address, active')
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
  }) async {
    final row = await supabase
        .from('customers')
        .insert({
          'full_name': fullName,
          'identification': identification,
          'phone': phone,
          'email': email,
          'address': address,
        })
        .select('id, full_name, identification, phone, email, address, active')
        .single();

    return _customerFromJson(Map<String, dynamic>.from(row));
  }

  Future<void> deactivateCustomer(String id) async {
    await supabase
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
      active: json['active'] as bool? ?? true,
    );
  }
}
