import 'package:cobrapp_supabase/domain/document_models.dart';
import 'package:cobrapp_supabase/services/legal_document_renderer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('substitui variáveis do template jurídico', () {
    const template = LegalDocumentTemplate(
      code: 'test_contract',
      name: 'Contrato',
      type: LegalDocumentType.loanContract,
      language: 'pt',
      sections: [
        LegalDocumentSection(
          title: 'Contrato de {{customer.fullName}}',
          body: 'Valor: {{loan.amount}}',
        ),
      ],
    );

    const context = LegalDocumentContext(
      variables: {
        'customer.fullName': 'Cliente Teste',
        'loan.amount': 'R$ 1.000,00',
      },
    );

    final result = const LegalDocumentRenderer().render(template, context);

    expect(result.sections.single.title, 'Contrato de Cliente Teste');
    expect(result.sections.single.body, 'Valor: R$ 1.000,00');
  });
}
