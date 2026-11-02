-- A referral is recorded only when an email first signs up. Before this,
-- re-submitting through a friend's link could attach a referrer later.

create or replace function public.join_waitlist(
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
    -- Only the first signup's referrer counts; re-submitting never adds one.
    referred_by = signups.referred_by,
    updated_at  = now()
  returning ref_code into v_code;

  return v_code;
end;
$$;

