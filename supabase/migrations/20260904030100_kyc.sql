-- M2 slice 3 / FR-2: tiered identity verification.
--
-- The point of tiering is in FR-2's own wording: meet the obligations "without
-- excluding farmers who lack formal documents". A smallholder with no government
-- ID must still be able to sell something, so tier 1 asks for what anyone has —
-- a name, a number, a barangay, a photograph — and only larger amounts require
-- documents not everyone holds.

create type public.kyc_submission_status as enum (
  'draft',      -- the farmer is still adding documents
  'submitted',  -- waiting for review
  'approved',
  'rejected',
  'withdrawn'
);

create type public.kyc_document_type as enum (
  'portrait',       -- tier 1: a photograph of the person
  'gov_id_front',   -- tier 2
  'gov_id_back',
  'selfie'          -- tier 2: matched against the ID
);

-- ---------------------------------------------------------------------------
-- What each tier requires
-- ---------------------------------------------------------------------------
--
-- A table rather than code, so "a farmer blocked at a tier boundary sees what
-- document is needed" is answered from data both the check and the interface read.

create table public.kyc_tier_requirements (
  tier          public.kyc_tier not null,
  document_type public.kyc_document_type not null,
  description   text not null,
  primary key (tier, document_type)
);

insert into public.kyc_tier_requirements (tier, document_type, description) values
  ('tier_1', 'portrait',     'A clear photo of your face.'),
  ('tier_2', 'gov_id_front', 'The front of a government ID.'),
  ('tier_2', 'gov_id_back',  'The back of the same ID.'),
  ('tier_2', 'selfie',       'A selfie, so we can check it matches the ID.');

-- ---------------------------------------------------------------------------
-- Submissions
-- ---------------------------------------------------------------------------

create table public.kyc_submissions (
  id              uuid primary key default gen_random_uuid(),
  subject_id      uuid not null references public.profiles (id) on delete cascade,
  requested_tier  public.kyc_tier not null,

  status          public.kyc_submission_status not null default 'draft',
  submitted_at    timestamptz,

  -- FR-2: every decision timestamped and attributable to a named reviewer.
  reviewed_by     uuid references auth.users (id),
  reviewed_at     timestamptz,
  decision_reason text,

  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now(),

  constraint kyc_submissions_tier_is_upgradeable
    check (requested_tier in ('tier_1', 'tier_2')),

  -- A decision without a reviewer and a time is not attributable, which is the
  -- whole point of the requirement.
  constraint kyc_submissions_decision_attributed
    check (
      status not in ('approved', 'rejected')
      or (reviewed_by is not null and reviewed_at is not null)
    ),

  -- A rejection must say why: FR-2 requires the farmer to learn what is needed.
  constraint kyc_submissions_rejection_explained
    check (status <> 'rejected' or length(btrim(coalesce(decision_reason, ''))) > 0),

  constraint kyc_submissions_submitted_at_recorded
    check (status = 'draft' or submitted_at is not null)
);

-- One live submission per person per tier: re-applying replaces a rejection
-- rather than queueing a second request for the same thing.
create unique index kyc_submissions_one_open_per_tier
  on public.kyc_submissions (subject_id, requested_tier)
  where status in ('draft', 'submitted');

create index kyc_submissions_subject_idx on public.kyc_submissions (subject_id);
create index kyc_submissions_review_queue_idx
  on public.kyc_submissions (submitted_at)
  where status = 'submitted';

-- ---------------------------------------------------------------------------
-- Documents
-- ---------------------------------------------------------------------------

create table public.kyc_documents (
  id             uuid primary key default gen_random_uuid(),
  submission_id  uuid not null references public.kyc_submissions (id) on delete cascade,
  document_type  public.kyc_document_type not null,

  -- Where the image lives in the private storage bucket. Nullable on purpose:
  -- this is the seam for moving to a verification provider that holds the images
  -- and returns only a result, at which point the reference below is populated
  -- instead and no biometric data sits in our storage at all.
  storage_path   text,

  -- A provider's reference, if one ever verifies on our behalf.
  provider_name      text,
  provider_reference text,

  uploaded_at    timestamptz not null default now(),

  -- A document record that points at neither an image nor a provider result is
  -- evidence of nothing.
  constraint kyc_documents_has_evidence
    check (storage_path is not null or provider_reference is not null),
  constraint kyc_documents_provider_named
    check ((provider_reference is null) = (provider_name is null))
);

create unique index kyc_documents_one_per_type
  on public.kyc_documents (submission_id, document_type);

create index kyc_documents_submission_idx on public.kyc_documents (submission_id);

comment on table public.kyc_documents is
  'Identity documents. PRD §9 classifies these as highly sensitive biometric data: '
  'readable only by the subject and compliance, never by other staff roles.';

-- ---------------------------------------------------------------------------
-- Transaction ceilings
-- ---------------------------------------------------------------------------
--
-- PLACEHOLDER VALUES. The real thresholds come from the legal opinion in PRD Q6.
-- They are stored as settings precisely so answering Q6 is a configuration change
-- rather than a migration, and they are deliberately conservative meanwhile.

insert into public.platform_settings (key, value, description) values
  ('kyc_tier_0_max_transaction_php', '0',
   'PLACEHOLDER pending Q6. An unverified account cannot transact.'),
  ('kyc_tier_0_max_30day_php', '0',
   'PLACEHOLDER pending Q6.'),
  ('kyc_tier_1_max_transaction_php', '10000',
   'PLACEHOLDER pending Q6. Single-transaction ceiling at tier 1.'),
  ('kyc_tier_1_max_30day_php', '50000',
   'PLACEHOLDER pending Q6. Rolling 30-day ceiling at tier 1.'),
  ('kyc_tier_2_max_transaction_php', '500000',
   'PLACEHOLDER pending Q6. Single-transaction ceiling at tier 2.'),
  ('kyc_tier_2_max_30day_php', '2000000',
   'PLACEHOLDER pending Q6. Rolling 30-day ceiling at tier 2.');

-- What a person has already transacted in the rolling window. Counts confirmed
-- lines only: a reservation somebody declined never moved any money.
create or replace function public.transacted_last_30_days(p_user uuid)
returns numeric
language sql
stable
security definer          -- sums lines the caller may not each be able to read
set search_path = ''
as $$
  select coalesce(sum(ol.line_total), 0)
  from public.order_lines ol
  where (ol.farmer_id = p_user or ol.buyer_id = p_user)
    and ol.status = 'confirmed'
    and ol.responded_at >= now() - interval '30 days';
$$;

-- Returns null when the amount is permitted, or a sentence explaining the block.
-- A message rather than a boolean because FR-2 requires the person to be told
-- what is needed and why — a bare refusal fails the requirement.
create or replace function public.kyc_ceiling_breach(p_user uuid, p_amount numeric)
returns text
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_tier      public.kyc_tier;
  v_max_txn   numeric;
  v_max_30    numeric;
  v_used      numeric;
  v_tier_name text;
begin
  select kyc_tier into v_tier from public.profiles where id = p_user;
  if v_tier is null then
    return 'We could not find your account.';
  end if;

  v_tier_name := replace(v_tier::text, '_', ' ');

  v_max_txn := public.setting_int('kyc_' || v_tier::text || '_max_transaction_php', 0);
  v_max_30  := public.setting_int('kyc_' || v_tier::text || '_max_30day_php', 0);

  if v_tier = 'tier_0' then
    return 'Your account is not verified yet, so it cannot be used to trade. '
        || 'Send a photo of yourself to get started.';
  end if;

  if p_amount > v_max_txn then
    return format(
      'This is %s pesos, and %s allows up to %s pesos in one transaction. '
      || 'Send a government ID and a selfie to raise the limit.',
      trim(to_char(p_amount, 'FM999999999.00')),
      v_tier_name,
      trim(to_char(v_max_txn, 'FM999999999')));
  end if;

  v_used := public.transacted_last_30_days(p_user);

  if v_used + p_amount > v_max_30 then
    return format(
      'This would take you to %s pesos in 30 days, and %s allows up to %s. '
      || 'Send a government ID and a selfie to raise the limit.',
      trim(to_char(v_used + p_amount, 'FM999999999.00')),
      v_tier_name,
      trim(to_char(v_max_30, 'FM999999999')));
  end if;

  return null;
end;
$$;

-- ---------------------------------------------------------------------------
-- Review
-- ---------------------------------------------------------------------------

create or replace function public.submit_kyc(p_submission_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_sub     record;
  v_missing text;
begin
  select * into v_sub from public.kyc_submissions where id = p_submission_id for update;

  if not found or v_sub.subject_id <> auth.uid() then
    raise exception 'submission not found' using errcode = 'insufficient_privilege';
  end if;

  if v_sub.status <> 'draft' then
    raise exception 'this application has already been sent' using errcode = 'check_violation';
  end if;

  -- Refuse an incomplete application rather than letting a farmer wait for a
  -- review that was always going to be rejected.
  select string_agg(r.description, ' ')
    into v_missing
  from public.kyc_tier_requirements r
  where r.tier = v_sub.requested_tier
    and not exists (
      select 1 from public.kyc_documents d
      where d.submission_id = v_sub.id and d.document_type = r.document_type
    );

  if v_missing is not null then
    raise exception 'still needed: %', v_missing using errcode = 'check_violation';
  end if;

  update public.kyc_submissions
     set status = 'submitted', submitted_at = now()
   where id = p_submission_id;
end;
$$;

create or replace function public.review_kyc(
  p_submission_id uuid,
  p_approve       boolean,
  p_reason        text default null
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_sub record;
begin
  if not public.has_any_role('compliance', 'admin') then
    raise exception 'only compliance may review an application'
      using errcode = 'insufficient_privilege';
  end if;

  select * into v_sub from public.kyc_submissions where id = p_submission_id for update;
  if not found then
    raise exception 'submission not found' using errcode = 'insufficient_privilege';
  end if;

  if v_sub.status <> 'submitted' then
    raise exception 'this application is not awaiting review' using errcode = 'check_violation';
  end if;

  -- A reviewer approving their own application is the obvious way this control
  -- would be defeated.
  if v_sub.subject_id = auth.uid() then
    raise exception 'a reviewer cannot decide their own application'
      using errcode = 'insufficient_privilege';
  end if;

  if not p_approve and length(btrim(coalesce(p_reason, ''))) = 0 then
    raise exception 'a rejection must say what was wrong' using errcode = 'check_violation';
  end if;

  update public.kyc_submissions
     set status = case when p_approve then 'approved' else 'rejected' end::public.kyc_submission_status,
         reviewed_by = auth.uid(),
         reviewed_at = now(),
         decision_reason = p_reason
   where id = p_submission_id;

  -- Approval is what actually moves the tier. Only ever upward here; a downgrade
  -- is a separate compliance action, not a side effect of an application.
  if p_approve and v_sub.requested_tier > (
       select kyc_tier from public.profiles where id = v_sub.subject_id) then
    update public.profiles
       set kyc_tier = v_sub.requested_tier
     where id = v_sub.subject_id;
  end if;
end;
$$;

-- ---------------------------------------------------------------------------
-- Triggers
-- ---------------------------------------------------------------------------

create trigger kyc_submissions_touch_updated_at
  before update on public.kyc_submissions
  for each row execute function public.touch_updated_at();

create trigger kyc_submissions_audit
  after insert or update or delete on public.kyc_submissions
  for each row execute function public.audit_row_change();

-- Documents are audited by reference. The audit trail records that a document
-- existed and when, never its contents: copying biometric data into a second,
-- permanently un-deletable table would defeat the 5-year retention limit in §9.
create or replace function public.audit_kyc_document()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform public.record_audit_event(
    p_action       => 'kyc_documents.' || lower(tg_op),
    p_entity_table => 'kyc_documents',
    p_entity_id    => coalesce(new.id, old.id)::text,
    p_operation    => lower(tg_op)::public.audit_operation,
    p_context      => jsonb_build_object(
      'document_type', coalesce(new.document_type, old.document_type),
      'submission_id', coalesce(new.submission_id, old.submission_id))
  );
  return coalesce(new, old);
end;
$$;

create trigger kyc_documents_audit
  after insert or update or delete on public.kyc_documents
  for each row execute function public.audit_kyc_document();

-- ---------------------------------------------------------------------------
-- Row-level security
-- ---------------------------------------------------------------------------

alter table public.kyc_tier_requirements enable row level security;
alter table public.kyc_submissions enable row level security;
alter table public.kyc_documents enable row level security;

create policy "signed-in users read tier requirements"
  on public.kyc_tier_requirements for select to authenticated using (true);
create policy "admin writes tier requirements"
  on public.kyc_tier_requirements for all to authenticated
  using (public.has_role('admin')) with check (public.has_role('admin'));

create policy "read own submissions"
  on public.kyc_submissions for select to authenticated
  using ((select auth.uid()) = subject_id);

-- Compliance only. Identity verification is not something the trading desk,
-- buyers, or bagsakan operators have any reason to see.
create policy "compliance reads submissions"
  on public.kyc_submissions for select to authenticated
  using (public.has_any_role('compliance', 'admin'));

create policy "create own submission"
  on public.kyc_submissions for insert to authenticated
  with check ((select auth.uid()) = subject_id and status = 'draft');

-- A subject may edit only while it is a draft, and may not move it out of draft:
-- sending it is submit_kyc()'s job, which checks the documents are complete.
create policy "edit own draft submission"
  on public.kyc_submissions for update to authenticated
  using ((select auth.uid()) = subject_id and status = 'draft')
  with check ((select auth.uid()) = subject_id and status = 'draft');

create policy "read own documents"
  on public.kyc_documents for select to authenticated
  using (exists (
    select 1 from public.kyc_submissions s
    where s.id = kyc_documents.submission_id and s.subject_id = (select auth.uid())
  ));

create policy "compliance reads documents"
  on public.kyc_documents for select to authenticated
  using (public.has_any_role('compliance', 'admin'));

create policy "attach documents to own draft"
  on public.kyc_documents for insert to authenticated
  with check (exists (
    select 1 from public.kyc_submissions s
    where s.id = kyc_documents.submission_id
      and s.subject_id = (select auth.uid())
      and s.status = 'draft'
  ));

create policy "remove documents from own draft"
  on public.kyc_documents for delete to authenticated
  using (exists (
    select 1 from public.kyc_submissions s
    where s.id = kyc_documents.submission_id
      and s.subject_id = (select auth.uid())
      and s.status = 'draft'
  ));
