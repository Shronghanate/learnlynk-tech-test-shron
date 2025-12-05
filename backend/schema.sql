create extension if not exists "pgcrypto";

create or replace function public.update_updated_at_column()
returns trigger as $$
begin
  new.updated_at = now();
  return new;
end;
$$ language plpgsql;

create table if not exists public.leads (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null,
  owner_id uuid not null,
  email text,
  phone text,
  full_name text,
  stage text not null default 'new',
  source text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

drop trigger if exists trg_leads_update_updated_at on public.leads;
create trigger trg_leads_update_updated_at
before update on public.leads
for each row execute function public.update_updated_at_column();

create index if not exists idx_leads_tenant_id on public.leads (tenant_id);
create index if not exists idx_leads_owner_id on public.leads (owner_id);
create index if not exists idx_leads_stage on public.leads (stage);
create index if not exists idx_leads_created_at on public.leads (created_at);
create index if not exists idx_leads_tenant_owner_stage_created_at
  on public.leads (tenant_id, owner_id, stage, created_at);

create table if not exists public.applications (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null,
  lead_id uuid not null references public.leads(id) on delete cascade,
  program_id uuid,
  intake_id uuid,
  stage text not null default 'inquiry',
  status text not null default 'open',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

drop trigger if exists trg_applications_update_updated_at on public.applications;
create trigger trg_applications_update_updated_at
before update on public.applications
for each row execute function public.update_updated_at_column();

create index if not exists idx_applications_tenant_id on public.applications (tenant_id);
create index if not exists idx_applications_lead_id on public.applications (lead_id);
create index if not exists idx_applications_stage on public.applications (stage);
create index if not exists idx_applications_tenant_lead_stage
  on public.applications (tenant_id, lead_id, stage);

create table if not exists public.tasks (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null,
  application_id uuid not null references public.applications(id) on delete cascade,
  title text,
  type text not null,
  status text not null default 'open',
  due_at timestamptz not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint chk_tasks_due_after_created check (due_at >= created_at),
  constraint chk_tasks_type_allowed check (type in ('call','email','review'))
);

drop trigger if exists trg_tasks_update_updated_at on public.tasks;
create trigger trg_tasks_update_updated_at
before update on public.tasks
for each row execute function public.update_updated_at_column();

create index if not exists idx_tasks_tenant_id on public.tasks (tenant_id);
create index if not exists idx_tasks_due_at on public.tasks (due_at);
create index if not exists idx_tasks_status on public.tasks (status);
create index if not exists idx_tasks_tenant_due_status
  on public.tasks (tenant_id, due_at, status);

create index if not exists idx_tasks_due_date_tenant
  on public.tasks ((date(due_at at time zone 'utc')), tenant_id)
  where status = 'open';
