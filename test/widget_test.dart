import 'package:cobrapp_supabase/main.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('abre a navegação principal roots', (tester) async {
    await tester.pumpWidget(const CobrApp());

    expect(find.text('Roots Cobrança'), findsWidgets);
    expect(find.text('Início'), findsWidgets);
    expect(find.text('Clientes'), findsWidgets);
    expect(find.text('Empréstimos'), findsWidgets);
    expect(find.text('Cobranças'), findsWidgets);
    expect(find.text('Caixa'), findsWidgets);
  });
}
