enum LegalDocumentType {
  promissoryNote,
  loanContract,
  formalPaymentPlan,
  collectionLetter,
  accountStatement,
  debtClearanceCertificate,
  custom,
}

class DocumentParty {
  const DocumentParty({
    required this.fullName,
    required this.identification,
    this.address,
    this.phone,
  });

  final String fullName;
  final String identification;
  final String? address;
  final String? phone;
}

class CompanyDocumentInfo {
  const CompanyDocumentInfo({
    required this.name,
    required this.identification,
    this.address,
    this.city,
    this.country,
    this.billHeader,
  });

  final String name;
  final String identification;
  final String? address;
  final String? city;
  final String? country;
  final String? billHeader;
}

class LegalDocumentTemplate {
  const LegalDocumentTemplate({
    required this.code,
    required this.name,
    required this.type,
    required this.language,
    required this.sections,
    this.systemTemplate = false,
    this.requiresCodebtor = false,
    this.requiresSignatures = true,
  });

  final String code;
  final String name;
  final LegalDocumentType type;
  final String language;
  final List<LegalDocumentSection> sections;
  final bool systemTemplate;
  final bool requiresCodebtor;
  final bool requiresSignatures;
}

class LegalDocumentSection {
  const LegalDocumentSection({
    required this.title,
    required this.body,
  });

  final String title;
  final String body;
}

class LegalDocumentContext {
  const LegalDocumentContext({
    required this.variables,
    this.customer,
    this.codebtor,
    this.company,
  });

  final Map<String, String> variables;
  final DocumentParty? customer;
  final DocumentParty? codebtor;
  final CompanyDocumentInfo? company;

  String value(String key) => variables[key] ?? '';
}

class RenderedLegalDocument {
  const RenderedLegalDocument({
    required this.title,
    required this.type,
    required this.sections,
  });

  final String title;
  final LegalDocumentType type;
  final List<LegalDocumentSection> sections;
}
