create extension if not exists pgcrypto;

create table if not exists customers (
  id uuid primary key default gen_random_uuid(),
  full_name text not null,
  identification text not null,
  phone text,
  email text,
  address text,
  active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create unique index if not exists customers_identification_uq on customers (identification);

create table if not exists loans (
  id uuid primary key default gen_random_uuid(),
  customer_id uuid not null references customers(id) on delete restrict,
  amount numeric(14,2) not null check (amount > 0),
  interest_rate numeric(9,4) not null default 0,
  interest_type text not null check (interest_type in ('initial_capital','each_payment','bank_compound')),
  payments_number integer not null check (payments_number > 0),
  payment_frequency text not null check (payment_frequency in ('daily','weekly','biweekly','monthly','custom')),
  start_date date not null,
  end_date date not null,
  total_interest numeric(14,2) not null default 0,
  total_debt numeric(14,2) not null,
  late_interest_rate numeric(9,4),
  days_of_grace integer not null default 0 check (days_of_grace >= 0),
  late_fee numeric(14,2) not null default 0,
  note text,
  status text not null default 'active' check (status in ('active','completed','cancelled','renewed')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists loans_customer_id_idx on loans(customer_id);
create index if not exists loans_status_idx on loans(status);

create table if not exists installments (
  id uuid primary key default gen_random_uuid(),
  loan_id uuid not null references loans(id) on delete cascade,
  number integer not null check (number > 0),
  due_date date not null,
  principal numeric(14,2) not null default 0,
  interest numeric(14,2) not null default 0,
  total numeric(14,2) not null check (total >= 0),
  paid_amount numeric(14,2) not null default 0,
  late_interest_paid numeric(14,2) not null default 0,
  status text not null default 'pending' check (status in ('pending','paid','overdue')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (loan_id, number)
);

create index if not exists installments_due_date_idx on installments(due_date);
create index if not exists installments_status_idx on installments(status);

create table if not exists payments (
  id uuid primary key default gen_random_uuid(),
  loan_id uuid not null references loans(id) on delete restrict,
  installment_id uuid references installments(id) on delete set null,
  paid_at timestamptz not null default now(),
  total_paid numeric(14,2) not null check (total_paid > 0),
  principal_paid numeric(14,2) not null default 0,
  interest_paid numeric(14,2) not null default 0,
  late_interest_paid numeric(14,2) not null default 0,
  extra_capital_paid numeric(14,2) not null default 0,
  method text,
  note text,
  created_at timestamptz not null default now()
);

create index if not exists payments_loan_id_idx on payments(loan_id);
create index if not exists payments_paid_at_idx on payments(paid_at);

create table if not exists document_templates (
  id uuid primary key default gen_random_uuid(),
  code text not null unique,
  name text not null,
  document_type text not null,
  language text not null default 'pt',
  body jsonb not null default '{}'::jsonb,
  system_template boolean not null default false,
  active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists generated_documents (
  id uuid primary key default gen_random_uuid(),
  loan_id uuid references loans(id) on delete set null,
  customer_id uuid references customers(id) on delete set null,
  template_id uuid references document_templates(id) on delete set null,
  title text not null,
  document_type text not null,
  storage_path text,
  snapshot jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);
