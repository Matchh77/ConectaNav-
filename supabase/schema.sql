-- ConectaNav — schema Supabase (Postgres). Cole no SQL Editor e execute.
create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  role text not null check (role in ('candidato','empresa')),
  consent_at timestamptz not null default now(),
  free_unlock_used boolean not null default false
);
create table public.candidates (
  user_id uuid primary key references auth.users(id) on delete cascade,
  name text not null check (char_length(name) between 2 and 80),
  age int not null check (age between 16 and 29),
  bairro text not null, turno text not null,
  ifms boolean not null default false,
  tags text[] not null default '{}'
    check (tags <@ array['Atendimento ao Cliente','Operador de Caixa','Reposição de Estoque','Informática Básica','Vendas','Pacote Office']),
  courses jsonb not null default '[]'
    check (jsonb_typeof(courses)='array' and jsonb_array_length(courses)<=10),
  updated_at timestamptz not null default now()
);
-- telefone separado: só o dono e empresas que desbloquearam conseguem ler
create table public.candidate_contacts (
  user_id uuid primary key references public.candidates(user_id) on delete cascade,
  phone text not null check (char_length(phone) between 10 and 20)
);
create table public.jobs (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references auth.users(id) on delete cascade,
  company text not null, bairro text not null, cargo text not null, turno text not null,
  tags text[] not null default '{}',
  status text not null default 'aberta' check (status in ('aberta','encerrada')),
  created_at timestamptz not null default now()
);
create table public.applications (
  id uuid primary key default gen_random_uuid(),
  job_id uuid not null references public.jobs(id) on delete cascade,
  candidate_id uuid not null references public.candidates(user_id) on delete cascade,
  status text not null default 'Análise' check (status in ('Análise','Entrevista Agendada','Não selecionado')),
  created_at timestamptz not null default now(),
  unique (job_id, candidate_id)
);
create table public.unlocks (
  company_id uuid not null references auth.users(id) on delete cascade,
  candidate_id uuid not null references public.candidates(user_id) on delete cascade,
  method text not null check (method in ('free','pix')),
  payment_id text,
  created_at timestamptz not null default now(),
  primary key (company_id, candidate_id)
);

create function public.is_empresa() returns boolean language sql stable security definer set search_path=public as
$$ select exists(select 1 from profiles where id=auth.uid() and role='empresa') $$;
create function public.is_candidato() returns boolean language sql stable security definer set search_path=public as
$$ select exists(select 1 from profiles where id=auth.uid() and role='candidato') $$;

alter table public.profiles enable row level security;
alter table public.candidates enable row level security;
alter table public.candidate_contacts enable row level security;
alter table public.jobs enable row level security;
alter table public.applications enable row level security;
alter table public.unlocks enable row level security;

create policy p_sel on profiles for select to authenticated using (id=auth.uid());
create policy p_ins on profiles for insert to authenticated with check (id=auth.uid() and free_unlock_used=false);

create policy c_own on candidates for all to authenticated using (user_id=auth.uid()) with check (user_id=auth.uid() and is_candidato());
create policy c_emp on candidates for select to authenticated using (is_empresa());

create policy cc_own on candidate_contacts for all to authenticated using (user_id=auth.uid()) with check (user_id=auth.uid());
create policy cc_unl on candidate_contacts for select to authenticated
  using (exists(select 1 from unlocks u where u.company_id=auth.uid() and u.candidate_id=candidate_contacts.user_id));

create policy j_sel on jobs for select to authenticated using (true);
create policy j_ins on jobs for insert to authenticated with check (owner_id=auth.uid() and is_empresa());
create policy j_upd on jobs for update to authenticated using (owner_id=auth.uid()) with check (owner_id=auth.uid());
create policy j_del on jobs for delete to authenticated using (owner_id=auth.uid());

create policy a_cand_sel on applications for select to authenticated using (candidate_id=auth.uid());
create policy a_cand_ins on applications for insert to authenticated
  with check (candidate_id=auth.uid() and status='Análise' and exists(select 1 from jobs j where j.id=job_id and j.status='aberta'));
create policy a_cand_del on applications for delete to authenticated using (candidate_id=auth.uid());
create policy a_emp_sel on applications for select to authenticated using (exists(select 1 from jobs j where j.id=job_id and j.owner_id=auth.uid()));
create policy a_emp_upd on applications for update to authenticated
  using (exists(select 1 from jobs j where j.id=job_id and j.owner_id=auth.uid()))
  with check (exists(select 1 from jobs j where j.id=job_id and j.owner_id=auth.uid()));

create policy u_sel on unlocks for select to authenticated using (company_id=auth.uid());
-- (sem policy de insert: só via RPC abaixo ou pelo webhook do Pix com service role)

create function public.unlock_free(p_candidate uuid) returns void language plpgsql security definer set search_path=public as $$
declare v_used boolean;
begin
  select free_unlock_used into v_used from profiles where id=auth.uid() and role='empresa' for update;
  if not found then raise exception 'Apenas empresas podem desbloquear contatos'; end if;
  if v_used then raise exception 'Franquia grátis já utilizada'; end if;
  if not exists(select 1 from candidates where user_id=p_candidate) then raise exception 'Candidato inexistente'; end if;
  insert into unlocks(company_id,candidate_id,method) values (auth.uid(),p_candidate,'free');
  update profiles set free_unlock_used=true where id=auth.uid();
end $$;
revoke all on function public.unlock_free(uuid) from public, anon;
grant execute on function public.unlock_free(uuid) to authenticated;

-- LGPD: exclusão da conta e de todos os dados (cascade)
create function public.delete_my_account() returns void language sql security definer set search_path=public,auth as
$$ delete from auth.users where id=auth.uid() $$;
revoke all on function public.delete_my_account() from public, anon;
grant execute on function public.delete_my_account() to authenticated;

alter publication supabase_realtime add table public.applications, public.unlocks, public.jobs;
