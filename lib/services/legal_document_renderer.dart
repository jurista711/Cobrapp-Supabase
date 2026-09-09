import '../domain/document_models.dart';

class LegalDocumentRenderer {
  const LegalDocumentRenderer();

  RenderedLegalDocument render(
    LegalDocumentTemplate template,
    LegalDocumentContext context,
  ) {
    final sections = template.sections
        .map(
          (section) => LegalDocumentSection(
            title: _replace(section.title, context.variables),
            body: _replace(section.body, context.variables),
          ),
        )
        .toList(growable: false);

    return RenderedLegalDocument(
      title: template.name,
      type: template.type,
      sections: sections,
    );
  }

  String _replace(String input, Map<String, String> values) {
    return input.replaceAllMapped(RegExp(r'\{\{([^}]+)\}\}'), (match) {
      final key = match.group(1)?.trim() ?? '';
      return values[key] ?? '';
    });
  }
}
