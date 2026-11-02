-- Word-of-mouth referrals: every signup gets a short personal code, and a
-- signup that arrives through someone's link records whose code it was.

alter table public.signups
  add column ref_code    text unique check (ref_code ~ '^[a-z0-9]{5}$'),
  add column referred_by text check (referred_by ~ '^[a-z0-9]{5}$');

-- Changing the signature and return type means replacing the function.
drop function public.join_waitlist(text, text[], text, text, text, text, text);

create function public.join_waitlist(
  p_email       text,
  p_agents      text[] default '{}',
  p_parallel    text default null,
  p_pay         text default null,
  p_form        text default null,
  p_source      text default null,
  p_campaign    text default null,
  p_referred_by text default null
) returns text
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_code text;
  v_ref  text := lower(p_referred_by);
begin
  -- Ignore codes that don't belong to anyone.
  if v_ref is not null and not exists (select 1 from public.signups where ref_code = v_ref) then
    v_ref := null;
  end if;

  loop
    v_code := substr(translate(encode(extensions.gen_random_bytes(8), 'base64'), '+/=OIl01', ''), 1, 5);
    v_code := lower(v_code);
    exit when length(v_code) = 5 and v_code ~ '^[a-z0-9]{5}$'
          and not exists (select 1 from public.signups where ref_code = v_code);
  end loop;

  insert into public.signups (email, agents, parallel, pay, form, source, campaign, ref_code, referred_by)
  values (lower(trim(p_email)), coalesce(p_agents, '{}'), p_parallel, p_pay, p_form,
          left(p_source, 500), left(p_campaign, 200), v_code, v_ref)
  on conflict (email) do update set
    agents      = case when cardinality(excluded.agents) > 0 then excluded.agents else signups.agents end,
    parallel    = coalesce(excluded.parallel, signups.parallel),
    pay         = coalesce(excluded.pay, signups.pay),
    form        = case when excluded.form = 'full' then 'full' else signups.form end,
    ref_code    = coalesce(signups.ref_code, excluded.ref_code),
    -- First referrer wins, and nobody can refer themselves.
    referred_by = coalesce(signups.referred_by,
                           nullif(excluded.referred_by, coalesce(signups.ref_code, excluded.ref_code))),
    updated_at  = now()
  returning ref_code into v_code;

  return v_code;
end;
$$;

revoke execute on function public.join_waitlist from public;
grant execute on function public.join_waitlist to anon;
