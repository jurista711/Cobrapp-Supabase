alter table if exists customers
  add column if not exists notes text;
