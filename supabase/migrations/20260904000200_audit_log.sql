-- M1 Foundation: the audit trail (FR-28).
--
-- FR-28 requires records that "cannot be edited or deleted by any role including
-- administrators". Convention will not achieve that, so it is enforced three ways:
--   1. No UPDATE or DELETE grant is ever issued on the table.
--   2. RLS carries no UPDATE or DELETE policy, so both deny by default.
--   3. A trigger raises on UPDATE or DELETE, which catches even a superuser path.
-- Inserts go through a SECURITY DEFINER function so an actor cannot be forged.

create table public.audit_log (
  id            bigint generated always as identity primary key,
  occurred_at   timestamptz not null default now(),

  -- Who. Null actor means the system acted (a scheduled job, a trigger with no
  -- authenticated session); it is never "unknown".
  actor_id      uuid references auth.users (id),
  actor_roles   text[] not null default array[]::text[],

  -- What.
  action        text not null,
  entity_table  text not null,
  entity_id     text,
  operation     public.audit_operation,

  -- Before and after. Null on insert / delete respectively.
  before_state  jsonb,
  after_state   jsonb,

  -- Context for investigation.
  context       jsonb not null default '{}'::jsonb,

  constraint audit_log_action_not_blank check (length(btrim(action)) > 0),
  constraint audit_log_entity_table_not_blank check (length(btrim(entity_table)) > 0)
);

create index audit_log_occurred_at_idx on public.audit_log (occurred_at desc);
create index audit_log_actor_id_idx    on public.audit_log (actor_id);
create index audit_log_entity_idx      on public.audit_log (entity_table, entity_id);

comment on table public.audit_log is
  'Append-only audit trail. No role may update or delete a row -- see FR-28.';

-- ---------------------------------------------------------------------------
-- Immutability
-- ---------------------------------------------------------------------------

create or replace function public.reject_audit_mutation()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  raise exception
    'audit_log is append-only: % is not permitted (FR-28)', tg_op
    using errcode = 'insufficient_privilege';
end;
$$;

create trigger audit_log_no_update
  before update on public.audit_log
  for each row execute function public.reject_audit_mutation();

create trigger audit_log_no_delete
  before delete on public.audit_log
  for each row execute function public.reject_audit_mutation();

-- Truncate would bypass row-level triggers, so it is blocked at statement level.
create trigger audit_log_no_truncate
  before truncate on public.audit_log
  for each statement execute function public.reject_audit_mutation();

-- ---------------------------------------------------------------------------
-- Recording
-- ---------------------------------------------------------------------------

-- SECURITY DEFINER so callers can append without holding INSERT on the table. The
-- actor is taken from the session, never from an argument, so it cannot be spoofed.
create or replace function public.record_audit_event(
  p_action       text,
  p_entity_table text,
  p_entity_id    text default null,
  p_operation    public.audit_operation default null,
  p_before       jsonb default null,
  p_after        jsonb default null,
  p_context      jsonb default '{}'::jsonb
)
returns bigint
language plpgsql
security definer
set search_path = ''
as $$
declare
  new_id bigint;
begin
  insert into public.audit_log (
    actor_id, actor_roles, action, entity_table, entity_id,
    operation, before_state, after_state, context
  )
  values (
    auth.uid(),
    public.current_roles(),
    p_action,
    p_entity_table,
    p_entity_id,
    p_operation,
    p_before,
    p_after,
    coalesce(p_context, '{}'::jsonb)
  )
  returning id into new_id;

  return new_id;
end;
$$;

comment on function public.record_audit_event is
  'Appends an audit entry. The actor is read from the session and cannot be passed in.';

-- Generic table trigger. Attach to any table whose changes must be recorded.
create or replace function public.audit_row_change()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_before jsonb;
  v_after  jsonb;
  v_id     text;
begin
  if tg_op = 'INSERT' then
    v_after := to_jsonb(new);
    v_id    := (to_jsonb(new) ->> 'id');
  elsif tg_op = 'UPDATE' then
    v_before := to_jsonb(old);
    v_after  := to_jsonb(new);
    v_id     := (to_jsonb(new) ->> 'id');
  else
    v_before := to_jsonb(old);
    v_id     := (to_jsonb(old) ->> 'id');
  end if;

  perform public.record_audit_event(
    p_action       => tg_table_name || '.' || lower(tg_op),
    p_entity_table => tg_table_name,
    p_entity_id    => v_id,
    p_operation    => lower(tg_op)::public.audit_operation,
    p_before       => v_before,
    p_after        => v_after
  );

  return coalesce(new, old);
end;
$$;

-- ---------------------------------------------------------------------------
-- Row-level security
-- ---------------------------------------------------------------------------

alter table public.audit_log enable row level security;

-- Compliance and admin may read the trail. Deliberately no policy for anyone else:
-- the audit log records other people's actions and is not user-facing.
create policy "compliance and admin read audit log"
  on public.audit_log for select
  to authenticated
  using ( public.has_any_role('compliance', 'admin') );

-- No INSERT policy: appends go through record_audit_event(), which is SECURITY
-- DEFINER. No UPDATE or DELETE policy, by design -- both deny by default.

-- Belt and braces alongside RLS: never grant write access on the table itself.
revoke update, delete, truncate on public.audit_log from anon, authenticated;
