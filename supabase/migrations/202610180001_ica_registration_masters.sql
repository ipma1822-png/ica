-- Additive master data only; no credentials, numbering rules, schema, or RPC changes.
-- Date uses existing issued_on; original document number uses credential_no.
-- Rollback: deactivate these two new master entries after checking usage.
begin;
insert into public.ica_issuers(code,name_ko,name_en,is_active)
values ('KUKKIWON','국기원','KUKKIWON',true) on conflict(code) do nothing;
insert into public.ica_credential_types(code,name_ko,name_en,is_active,default_card,default_document)
values ('AWD','표창장·상장·공로상','Award / Commendation',true,false,false)
on conflict(code) do nothing;
commit;
