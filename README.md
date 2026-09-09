# CobrApp Supabase

Reconstrução funcional independente de um sistema profissional de gestão de empréstimos e cobranças, usando Flutter + Supabase.

## Regra do projeto

O comportamento do aplicativo de referência é usado como especificação funcional. A implementação neste repositório é nova, em Dart/Flutter, sem copiar código proprietário compilado.

## Backend

- Supabase / PostgreSQL
- Sem Firebase
- Configuração por `--dart-define`
- Nada de chaves privadas dentro do repositório

## Módulos-alvo

1. Dashboard
2. Clientes
3. Empréstimos
4. Parcelas e plano de pagamento
5. Cobranças e inadimplência
6. Pagamentos
7. Recibos
8. Caixa
9. Rotas
10. Relatórios
11. Gestão da carteira
12. Calculadora de crédito
13. Documentos jurídicos
14. Configurações

## Documentos jurídicos previstos

- Nota promissória
- Contrato de empréstimo
- Plano formal de pagamento
- Carta de cobrança
- Extrato/estado de conta
- Certificado de quitação
- Templates personalizados
- Geração, visualização, impressão e compartilhamento em PDF

## Estratégia

Cada módulo passa por: descoberta funcional → modelagem → implementação → testes → build → validação → congelamento.

O repositório anterior `jurista711/Cobrapp12` permanece preservado como referência e plano de retorno.