-- Waitlist signups for antidrift.tech.
-- The public (anon) key can't touch the table directly. It can only call
-- join_waitlist(), which validates input and inserts or merges by email,
-- so someone who signs up in the hero can answer the questions later.

create table public.signups (
  id          bigint generated always as identity primary key,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now(),
  email       text not null unique
              check (char_length(email) <= 254 and email ~ '^[^@\s]+@[^@\s]+\.[^@\s]+$'),
  agents      text[] not null default '{}'
              check (agents <@ array['claude-code', 'codex', 'cursor', 'other']),
  parallel    text check (parallel in ('1', '2-3', '4-9', '10+')),
  pay         text check (pay in ('free-only', 'once', 'monthly')),
  form        text check (form in ('hero', 'full')),
  source      text check (char_length(source) <= 500),
  campaign    text check (char_length(campaign) <= 200)
);

-- RLS on with no policies: nobody reads or writes the table through the API.
alter table public.signups enable row level security;
revoke all on public.signups from anon, authenticated;

create function public.join_waitlist(
  p_email    text,
  p_agents   text[] default '{}',
  p_parallel text default null,
  p_pay      text default null,
  p_form     text default null,
  p_source   text default null,
  p_campaign text default null
) returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.signups (email, agents, parallel, pay, form, source, campaign)
  values (lower(trim(p_email)), coalesce(p_agents, '{}'), p_parallel, p_pay, p_form,
          left(p_source, 500), left(p_campaign, 200))
  on conflict (email) do update set
    agents     = case when cardinality(excluded.agents) > 0 then excluded.agents else signups.agents end,
    parallel   = coalesce(excluded.parallel, signups.parallel),
    pay        = coalesce(excluded.pay, signups.pay),
    form       = case when excluded.form = 'full' then 'full' else signups.form end,
    updated_at = now();
end;
$$;

revoke execute on function public.join_waitlist from public;
grant execute on function public.join_waitlist to anon;
