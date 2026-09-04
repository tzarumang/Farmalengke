-- TEST SUPPORT ONLY. Applied after the migrations to mirror the table-level grants
-- Supabase issues automatically. RLS, not the absence of grants, is what protects
-- the data -- so the tests must run with the grants present.

grant select, insert, update, delete on public.profiles   to authenticated;
grant select, insert, update, delete on public.user_roles to authenticated;
grant select, insert                 on public.audit_log  to authenticated;

grant execute on function public.record_audit_event(text, text, text, public.audit_operation, jsonb, jsonb, jsonb) to authenticated;
grant execute on function public.current_roles()  to authenticated;
grant execute on function public.has_role(public.user_role) to authenticated;
grant execute on function public.has_any_role(public.user_role[]) to authenticated;

-- The immutability guarantee from FR-28 must hold even though the grant above is
-- deliberately generous. Re-assert the revoke the migration performs.
revoke update, delete, truncate on public.audit_log from anon, authenticated;

-- M2 tables. Same posture: a broad grant, narrowed by policy.
grant select, insert, update, delete on public.regions            to authenticated;
grant select, insert, update, delete on public.commodities        to authenticated;
grant select, insert, update, delete on public.region_commodities to authenticated;
grant select, insert, update, delete on public.trade_units        to authenticated;
grant select, insert, update, delete on public.commodity_units    to authenticated;
grant select, insert, update, delete on public.farms              to authenticated;
grant select, insert, update, delete on public.farm_crops         to authenticated;
grant select, insert, update, delete on public.produce_listings   to authenticated;

grant execute on function public.commodity_unit_to_kg(uuid, text, text) to authenticated;
