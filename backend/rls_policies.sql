alter table public.leads enable row level security;

create policy leads_select_policy
on public.leads
for select
using (
  (
    auth.role() = 'admin'
    and tenant_id = (current_setting('request.jwt.claims', true)::jsonb ->> 'tenant_id')::uuid
  )
  or owner_id = auth.uid()
  or (
    public.leads.team_id is not null
    and exists (
      select 1
      from public.user_teams ut
      where ut.user_id = auth.uid()
        and ut.team_id = public.leads.team_id
    )
  )
);

create policy leads_insert_policy
on public.leads
for insert
with check (
  tenant_id = (current_setting('request.jwt.claims', true)::jsonb ->> 'tenant_id')::uuid
  and (
    auth.role() = 'admin'
    or auth.role() = 'counselor'
  )
);
