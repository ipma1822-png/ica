-- WMA CHAMPIONSHIP 2026 x ICA - OFFICIAL LOCAL ARENA PHASE 1

create table if not exists public.wma_events (
  id uuid primary key default gen_random_uuid(),
  code text not null unique,
  name_ko text not null,
  name_en text not null,
  brand_name text not null,
  event_date date not null,
  registration_opens date,
  challenge_starts date,
  challenge_ends date,
  status text not null default 'ACTIVE' check (status in ('DRAFT','ACTIVE','COMPLETED','ARCHIVED')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.wma_local_arenas (
  id uuid primary key default gen_random_uuid(),
  event_id uuid not null references public.wma_events(id),
  arena_number text unique,
  organization_name text not null,
  organization_name_en text,
  country_code text not null check (country_code ~ '^[A-Z]{2}$'),
  country_name text not null,
  state_province text,
  city text not null,
  district text,
  local_area text not null,
  official_area_key text not null,
  address text,
  arena_director_name text not null,
  arena_director_title text not null default 'Arena Director',
  contact_email text,
  contact_phone text,
  organization_logo text,
  arena_director_photo text,
  approval_date date,
  valid_from date,
  valid_until date,
  status text not null default 'PENDING' check (status in ('PENDING','VERIFIED','SUSPENDED','REVOKED','COMPLETED')),
  public_slug text not null unique default encode(gen_random_bytes(12),'hex'),
  admin_note text,
  created_by uuid references auth.users(id) default auth.uid(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint wma_arena_number_format check (arena_number is null or arena_number ~ '^WMA26-[A-Z]{2}-[A-Z0-9]{2,5}-[0-9]{3}$')
);

create unique index if not exists wma_one_verified_arena_per_area
on public.wma_local_arenas(event_id, official_area_key)
where status = 'VERIFIED';
create index if not exists wma_local_arenas_event_status_idx on public.wma_local_arenas(event_id,status);
create index if not exists wma_local_arenas_search_idx on public.wma_local_arenas(country_code,city,district);

alter table public.wma_events enable row level security;
alter table public.wma_local_arenas enable row level security;

revoke all on public.wma_events, public.wma_local_arenas from anon, authenticated;
grant select, insert, update, delete on public.wma_events, public.wma_local_arenas to authenticated;

drop policy if exists wma_admin_all_events on public.wma_events;
create policy wma_admin_all_events on public.wma_events for all to authenticated
using ((select private.ica_is_admin())) with check ((select private.ica_is_admin()));
drop policy if exists wma_admin_all_local_arenas on public.wma_local_arenas;
create policy wma_admin_all_local_arenas on public.wma_local_arenas for all to authenticated
using ((select private.ica_is_admin())) with check ((select private.ica_is_admin()));

insert into public.wma_events(code,name_ko,name_en,brand_name,event_date,registration_opens,challenge_starts,challenge_ends,status)
values ('WMA26','제10회 세계마샬아츠대회','WORLD MARTIAL ARTS CHAMPIONSHIP 2026','WMA CHAMPIONSHIP 2026','2026-12-12','2026-09-20','2026-09-26','2026-12-12','ACTIVE')
on conflict (code) do update set name_ko=excluded.name_ko,name_en=excluded.name_en,brand_name=excluded.brand_name,event_date=excluded.event_date,registration_opens=excluded.registration_opens,challenge_starts=excluded.challenge_starts,challenge_ends=excluded.challenge_ends,updated_at=now();

create or replace function public.wma_save_local_arena(p_data jsonb)
returns public.wma_local_arenas
language plpgsql security definer
set search_path=public,private,auth,pg_temp
as $$
declare v_row public.wma_local_arenas; v_event uuid;
begin
  if not private.ica_is_admin() then raise exception 'ICA_ADMIN_REQUIRED'; end if;
  select id into v_event from public.wma_events where code='WMA26';
  if nullif(p_data->>'id','') is null then
    insert into public.wma_local_arenas(event_id,organization_name,organization_name_en,country_code,country_name,state_province,city,district,local_area,official_area_key,address,arena_director_name,arena_director_title,contact_email,contact_phone,organization_logo,arena_director_photo,admin_note)
    values(v_event,trim(p_data->>'organization_name'),nullif(trim(p_data->>'organization_name_en'),''),upper(trim(p_data->>'country_code')),trim(p_data->>'country_name'),nullif(trim(p_data->>'state_province'),''),trim(p_data->>'city'),nullif(trim(p_data->>'district'),''),trim(p_data->>'local_area'),upper(trim(p_data->>'country_code'))||':'||lower(regexp_replace(trim(p_data->>'local_area'),'\s+','','g')),nullif(trim(p_data->>'address'),''),trim(p_data->>'arena_director_name'),coalesce(nullif(trim(p_data->>'arena_director_title'),''),'Arena Director'),nullif(trim(p_data->>'contact_email'),''),nullif(trim(p_data->>'contact_phone'),''),nullif(trim(p_data->>'organization_logo'),''),nullif(trim(p_data->>'arena_director_photo'),''),nullif(trim(p_data->>'admin_note'),'')) returning * into v_row;
  else
    update public.wma_local_arenas set organization_name=trim(p_data->>'organization_name'),organization_name_en=nullif(trim(p_data->>'organization_name_en'),''),country_code=upper(trim(p_data->>'country_code')),country_name=trim(p_data->>'country_name'),state_province=nullif(trim(p_data->>'state_province'),''),city=trim(p_data->>'city'),district=nullif(trim(p_data->>'district'),''),local_area=trim(p_data->>'local_area'),official_area_key=upper(trim(p_data->>'country_code'))||':'||lower(regexp_replace(trim(p_data->>'local_area'),'\s+','','g')),address=nullif(trim(p_data->>'address'),''),arena_director_name=trim(p_data->>'arena_director_name'),arena_director_title=coalesce(nullif(trim(p_data->>'arena_director_title'),''),'Arena Director'),contact_email=nullif(trim(p_data->>'contact_email'),''),contact_phone=nullif(trim(p_data->>'contact_phone'),''),organization_logo=nullif(trim(p_data->>'organization_logo'),''),arena_director_photo=nullif(trim(p_data->>'arena_director_photo'),''),admin_note=nullif(trim(p_data->>'admin_note'),''),updated_at=now()
    where id=(p_data->>'id')::uuid returning * into v_row;
  end if;
  if v_row.id is null then raise exception 'ARENA_NOT_FOUND'; end if; return v_row;
end $$;

create or replace function public.wma_approve_local_arena(p_arena_id uuid)
returns public.wma_local_arenas
language plpgsql security definer
set search_path=public,private,auth,pg_temp
as $$
declare v_row public.wma_local_arenas; v_region text; v_seq int;
begin
  if not private.ica_is_admin() then raise exception 'ICA_ADMIN_REQUIRED'; end if;
  select * into v_row from public.wma_local_arenas where id=p_arena_id for update;
  if v_row.id is null then raise exception 'ARENA_NOT_FOUND'; end if;
  if exists(select 1 from public.wma_local_arenas where event_id=v_row.event_id and official_area_key=v_row.official_area_key and status='VERIFIED' and id<>v_row.id) then raise exception 'OFFICIAL_AREA_ALREADY_ASSIGNED'; end if;
  if v_row.arena_number is null then
    v_region:=upper(substr(regexp_replace(coalesce(v_row.state_province,v_row.city),'[^A-Za-z0-9]','','g'),1,3));
    if length(v_region)<2 then v_region:=upper(substr(md5(v_row.official_area_key),1,3)); end if;
    perform pg_advisory_xact_lock(hashtext('WMA26-'||v_row.country_code||'-'||v_region));
    select coalesce(max(right(arena_number,3)::int),0)+1 into v_seq from public.wma_local_arenas where arena_number like 'WMA26-'||v_row.country_code||'-'||v_region||'-%';
    v_row.arena_number:='WMA26-'||v_row.country_code||'-'||v_region||'-'||lpad(v_seq::text,3,'0');
  end if;
  update public.wma_local_arenas set arena_number=v_row.arena_number,status='VERIFIED',approval_date=coalesce(approval_date,current_date),valid_from=coalesce(valid_from,current_date),valid_until=coalesce(valid_until,'2026-12-12'),updated_at=now() where id=p_arena_id returning * into v_row;
  return v_row;
end $$;

create or replace function public.wma_change_arena_status(p_arena_id uuid,p_status text)
returns public.wma_local_arenas language plpgsql security definer set search_path=public,private,auth,pg_temp as $$
declare v public.wma_local_arenas;
begin
 if not private.ica_is_admin() then raise exception 'ICA_ADMIN_REQUIRED'; end if;
 if upper(p_status) not in ('PENDING','VERIFIED','SUSPENDED','REVOKED','COMPLETED') then raise exception 'INVALID_STATUS'; end if;
 if upper(p_status)='VERIFIED' then return public.wma_approve_local_arena(p_arena_id); end if;
 update public.wma_local_arenas set status=upper(p_status),updated_at=now() where id=p_arena_id returning * into v; return v;
end $$;

create or replace function public.wma_verify_local_arena(p_key text)
returns jsonb language sql stable security definer set search_path=public,pg_temp as $$
select jsonb_build_object('arena_number',a.arena_number,'organization_name',a.organization_name,'organization_name_en',a.organization_name_en,'country_code',a.country_code,'country_name',a.country_name,'state_province',a.state_province,'city',a.city,'district',a.district,'local_area',a.local_area,'arena_director_name',a.arena_director_name,'arena_director_title',a.arena_director_title,'approval_date',a.approval_date,'valid_from',a.valid_from,'valid_until',a.valid_until,'status',a.status,'public_slug',a.public_slug,'organization_logo',a.organization_logo,'event_name_ko',e.name_ko,'event_name_en',e.name_en,'brand_name',e.brand_name,'event_date',e.event_date,'challenge_starts',e.challenge_starts,'challenge_ends',e.challenge_ends)
from public.wma_local_arenas a join public.wma_events e on e.id=a.event_id where (upper(a.arena_number)=upper(trim(p_key)) or a.public_slug=trim(p_key)) and a.status in ('VERIFIED','SUSPENDED','REVOKED','COMPLETED') limit 1 $$;

revoke all on function public.wma_save_local_arena(jsonb),public.wma_approve_local_arena(uuid),public.wma_change_arena_status(uuid,text),public.wma_verify_local_arena(text) from public,anon,authenticated;
grant execute on function public.wma_save_local_arena(jsonb),public.wma_approve_local_arena(uuid),public.wma_change_arena_status(uuid,text) to authenticated;
grant execute on function public.wma_verify_local_arena(text) to anon,authenticated;
notify pgrst,'reload schema';
