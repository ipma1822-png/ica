-- ICA SMART MULTI-SEARCH v1.0
-- Adds exact name + birth-date recovery without exposing birth dates in public results.

alter table public.ica_credentials
  add column if not exists birth_date date;

create index if not exists ica_credentials_name_birth_idx
  on public.ica_credentials (lower(btrim(person_name)), birth_date);

create or replace function public.ica_issue_credential(p_data jsonb)
returns jsonb
language plpgsql
security definer
set search_path = public, auth, pg_temp
as $$
declare
  v_issuer public.ica_issuers%rowtype;
  v_type public.ica_credential_types%rowtype;
  v_rule public.ica_number_rules%rowtype;
  v_id uuid;
  v_no text;
begin
  if auth.uid() is null or not private.ica_is_admin() then raise exception 'ICA_ADMIN_REQUIRED'; end if;
  select * into v_issuer from public.ica_issuers where code=upper(btrim(p_data->>'issuer_code')) and is_active;
  select * into v_type from public.ica_credential_types where code=upper(btrim(p_data->>'type_code')) and is_active;
  if v_issuer.id is null or v_type.id is null then raise exception 'INVALID_ISSUER_OR_TYPE'; end if;
  if nullif(btrim(p_data->>'person_name'),'') is null then raise exception 'PERSON_NAME_REQUIRED'; end if;

  select * into v_rule from public.ica_number_rules
  where issuer_id=v_issuer.id and credential_type_id=v_type.id and is_active for update;
  if v_rule.id is null then raise exception 'NUMBER_RULE_NOT_FOUND'; end if;
  v_no := v_rule.prefix||v_rule.separator||lpad(v_rule.next_value::text,v_rule.digits,'0');

  insert into public.ica_credentials(
    credential_no,issuer_id,credential_type_id,detail_type_id,detail_label,person_name,person_name_en,photo_url,
    qualification_name,discipline,rank_grade,position_title,birth_date,issued_on,valid_until,phone,email,postal_code,address,
    address_detail,admin_note,status,card_requested,document_requested,created_by
  ) values (
    v_no,v_issuer.id,v_type.id,nullif(p_data->>'detail_type_id','')::uuid,nullif(btrim(p_data->>'detail_label'),''),
    btrim(p_data->>'person_name'),nullif(btrim(p_data->>'person_name_en'),''),nullif(btrim(p_data->>'photo_url'),''),
    nullif(btrim(p_data->>'qualification_name'),''),nullif(btrim(p_data->>'discipline'),''),nullif(btrim(p_data->>'rank_grade'),''),
    nullif(btrim(p_data->>'position_title'),''),nullif(p_data->>'birth_date','')::date,
    coalesce(nullif(p_data->>'issued_on','')::date,current_date),nullif(p_data->>'valid_until','')::date,
    nullif(btrim(p_data->>'phone'),''),nullif(btrim(p_data->>'email'),''),nullif(btrim(p_data->>'postal_code'),''),
    nullif(btrim(p_data->>'address'),''),nullif(btrim(p_data->>'address_detail'),''),nullif(btrim(p_data->>'admin_note'),''),
    'VALID',coalesce((p_data->>'card_requested')::boolean,v_type.default_card),
    coalesce((p_data->>'document_requested')::boolean,v_type.default_document),auth.uid()
  ) returning id into v_id;

  update public.ica_number_rules set next_value=next_value+1,updated_at=now() where id=v_rule.id;
  insert into public.ica_status_history(credential_id,old_status,new_status,reason,changed_by)
  values(v_id,null,'VALID','INITIAL_ISSUE',auth.uid());
  return jsonb_build_object('id',v_id,'credential_no',v_no);
end;
$$;
revoke all on function public.ica_issue_credential(jsonb) from public;
grant execute on function public.ica_issue_credential(jsonb) to authenticated;

create or replace function public.ica_verify_credential(p_credential_no text)
returns jsonb
language plpgsql
stable
security definer
set search_path = public, pg_temp
as $$
declare q text:=upper(btrim(p_credential_no)); result jsonb;
begin
  if q='' then return null; end if;
  select jsonb_build_object(
    'source','ICA','status',c.status,'credential_no',c.credential_no,'person_name',c.person_name,
    'person_name_en',c.person_name_en,'photo_url',c.photo_url,'issuer_code',i.code,'issuer_name',i.name_ko,'issuer_name_en',i.name_en,
    'type_code',t.code,'type_name',t.name_ko,'detail_name',coalesce(d.name_ko,c.detail_label),
    'qualification_name',c.qualification_name,'discipline',c.discipline,'rank_grade',c.rank_grade,
    'position_title',c.position_title,'issued_on',c.issued_on,'valid_until',c.valid_until,'verified_by','ICA'
  ) into result
  from public.ica_credentials c join public.ica_issuers i on i.id=c.issuer_id
  join public.ica_credential_types t on t.id=c.credential_type_id
  left join public.ica_detail_types d on d.id=c.detail_type_id
  where upper(c.credential_no)=q;
  if result is not null then return result; end if;

  select jsonb_build_object(
    'source','LEGACY','status','VALID','credential_no',l.certificate_no,'person_name',l.name,'person_name_en',l.name_en,
    'issuer_code',l.organization_code,'issuer_name',case when l.organization_code='WTKF' then '세계태권검도연맹' else '국제경찰무도연합회' end,
    'type_code','DAN','type_name',case when l.organization_code='WTKF' then '태권검도 단증' when l.certificate_no ilike '%경호무술%' then '경호무술 단증' else '경찰무도 단증' end,
    'rank_grade',case when l.rank_no is null then null else l.rank_no::text||'단' end,
    'issued_on',l.issued_at,'valid_until',null,'verified_by','ICA'
  ) into result from public.gms_legacy_members l where upper(btrim(l.certificate_no))=q limit 1;
  return result;
end;
$$;
revoke all on function public.ica_verify_credential(text) from public;
grant execute on function public.ica_verify_credential(text) to anon,authenticated;

create or replace function public.ica_find_credentials_by_identity(p_name text,p_birth_date date)
returns jsonb
language plpgsql
stable
security definer
set search_path = public, pg_temp
as $$
declare q text:=lower(btrim(p_name)); result jsonb;
begin
  if q='' or p_birth_date is null then return '[]'::jsonb; end if;
  select coalesce(jsonb_agg(x order by (x->>'issued_on') desc nulls last),'[]'::jsonb) into result
  from (
    select jsonb_build_object(
      'source','ICA','status',c.status,'credential_no',c.credential_no,'person_name',c.person_name,'person_name_en',c.person_name_en,
      'photo_url',c.photo_url,'issuer_code',i.code,'issuer_name',i.name_ko,'issuer_name_en',i.name_en,
      'type_code',t.code,'type_name',t.name_ko,'detail_name',coalesce(d.name_ko,c.detail_label),
      'qualification_name',c.qualification_name,'discipline',c.discipline,'rank_grade',c.rank_grade,
      'position_title',c.position_title,'issued_on',c.issued_on,'valid_until',c.valid_until,'verified_by','ICA'
    ) x
    from public.ica_credentials c join public.ica_issuers i on i.id=c.issuer_id
    join public.ica_credential_types t on t.id=c.credential_type_id left join public.ica_detail_types d on d.id=c.detail_type_id
    where lower(btrim(c.person_name))=q and c.birth_date=p_birth_date
    union all
    select jsonb_build_object(
      'source','LEGACY','status','VALID','credential_no',l.certificate_no,'person_name',l.name,'person_name_en',l.name_en,
      'issuer_code',l.organization_code,'issuer_name',case when l.organization_code='WTKF' then '세계태권검도연맹' else '국제경찰무도연합회' end,
      'type_code','DAN','type_name',case when l.organization_code='WTKF' then '태권검도 단증' else '경찰무도 단증' end,
      'rank_grade',case when l.rank_no is null then null else l.rank_no::text||'단' end,'issued_on',l.issued_at,'valid_until',null,'verified_by','ICA'
    ) x
    from public.gms_legacy_members l where lower(btrim(l.name))=q and l.birth_date=p_birth_date and nullif(btrim(l.certificate_no),'') is not null
  ) s;
  return result;
end;
$$;
revoke all on function public.ica_find_credentials_by_identity(text,date) from public;
grant execute on function public.ica_find_credentials_by_identity(text,date) to anon,authenticated;

notify pgrst, 'reload schema';