# Mapa funcional do aplicativo de referência

Este documento registra apenas comportamentos observados no material de referência analisado. Ele serve como especificação funcional para uma implementação nova.

## Empréstimos

Campos identificados no fluxo/documentos:

- valor do empréstimo
- taxa de juros
- tipo de juros
- total de juros
- dívida total
- número de parcelas
- frequência de pagamento
- data inicial
- data final
- juros de mora
- dias de carência
- observação

Tipos de juros observados:

- capital inicial
- cada parcela
- composto bancário

Frequências observadas:

- diária
- semanal
- quinzenal
- mensal
- personalizada

## Parcelas e pagamentos

Comportamentos observados:

- plano de pagamento
- histórico de pagamentos
- saldo de capital
- saldo de juros
- saldo total
- juros de mora acumulados
- pagamento extra de capital
- edição de vencimento
- opção de atualizar parcelas subsequentes
- movimentação de vencimentos em lote
- formas de pagamento

## Documentos

Tipos de documentos identificados:

- nota promissória
- contrato de empréstimo
- plano formal de pagamento
- carta de cobrança
- extrato/estado de conta
- certificado de quitação

Recursos observados:

- geração a partir de cliente + empréstimo + empresa
- suporte a codevedor/avalista
- assinatura do cliente e credor
- templates de sistema
- templates personalizados
- clonagem e edição de templates
- preview
- PDF
- compartilhamento
- impressão

## Dados variáveis usados em documentos

Exemplos observados:

- customer.fullName
- customer.identification
- customer.address
- loan.amount
- loan.interestRate
- loan.interestType
- loan.totalInterest
- loan.totalDebt
- loan.paymentsNumber
- loan.paymentFrequency
- loan.startDate
- loan.endDate
- loan.lateInterestRate
- loan.daysOfGrace
- loan.note
- payment.totalPaid
- company.name
- company.id
- context.currentDate
- context.currentDateInWords
- context.city
- context.country
- signature.lenderName
- codebtor.fullName
- codebtor.address

## Backend observado

O aplicativo de referência utiliza Firebase/Firestore em diversos fluxos. Neste projeto, esses comportamentos serão reimplementados sobre PostgreSQL/Supabase.

## Regra de implementação

Não copiar código compilado. Reproduzir comportamento, estrutura de dados e regras funcionais em código Dart/Flutter próprio.