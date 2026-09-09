import 'package:cobrapp_supabase/main.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('abre a navegação principal', (tester) async {
    await tester.pumpWidget(const CobrApp());

    expect(find.text('CobrApp Supabase'), findsOneWidget);
    expect(find.text('Início'), findsWidgets);
    expect(find.text('Clientes'), findsOneWidget);
    expect(find.text('Empréstimos'), findsOneWidget);
    expect(find.text('Cobranças'), findsOneWidget);
    expect(find.text('Documentos'), findsOneWidget);
  });
}
