import 'package:cobrapp_supabase/main.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('abre a tela de ativacao antes da navegacao principal', (tester) async {
    await tester.pumpWidget(const CobrApp());
    await tester.pump();

    expect(find.text('Ativar aparelho'), findsOneWidget);
    expect(find.text('Código de ativação'), findsOneWidget);
    expect(find.text('Ativar'), findsOneWidget);
    expect(find.text('Roots Cobrança'), findsNothing);
  });
}
