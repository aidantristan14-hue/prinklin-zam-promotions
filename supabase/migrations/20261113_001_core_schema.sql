-- Phase 1: Core database schema, enums, security helpers, and RLS
-- This file is a migration blueprint for Supabase. It is not executed here.

create extension if not exists pgcrypto;

create type app_role as enum (
  'customer',
  'support_agent',
  'department_administrator',
  'administrator',
  'super_administrator'
);

create type request_status as enum (
  'new',
  'reviewing',
  'awaiting_customer',
  'in_progress',
  'resolved',
  'closed',
  'cancelled'
);

create type support_thread_status as enum (
  'open',
  'waiting_for_customer',
  'waiting_for_staff',
  'resolved',
  'closed'
);

create type notification_kind as enum (
  'request_created',
  'request_status_changed',
  'message_received',
  'support_assigned',
  'general'
);

create sequence if not exists service_requests_request_number_seq start 1 increment by 1;

create table if not exists departments (
  id uuid primary key default gen_random_uuid(),
  slug text not null unique,
  name text not null unique,
  description text,
  active boolean not null default true,
  sort_order integer not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists service_categories (
  id uuid primary key default gen_random_uuid(),
  department_id uuid not null references departments(id) on delete restrict,
  slug text not null,
  name text not null,
  description text,
  active boolean not null default true,
  sort_order integer not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (department_id, slug),
  unique (id, department_id)
);

create table if not exists profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  display_name text not null,
  phone_e164 text,
  avatar_object_path text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists user_roles (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete restrict,
  role app_role not null,
  department_id uuid references departments(id) on delete restrict,
  granted_by uuid references auth.users(id) on delete set null,
  granted_at timestamptz not null default now(),
  revoked_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint user_roles_department_scope_check
    check (
      (role = 'department_administrator' and department_id is not null)
      or (role in ('administrator', 'super_administrator') and department_id is null)
      or (role in ('customer', 'support_agent') and true)
    )
);

create index if not exists user_roles_user_active_idx
  on user_roles (user_id, revoked_at, role);
create index if not exists user_roles_department_active_idx
  on user_roles (department_id, role, revoked_at);
create unique index if not exists user_roles_active_global_role_idx
  on user_roles (user_id, role)
  where department_id is null and revoked_at is null;
create unique index if not exists user_roles_active_department_role_idx
  on user_roles (user_id, role, department_id)
  where department_id is not null and revoked_at is null;

create table if not exists service_requests (
  id uuid primary key default gen_random_uuid(),
  request_number text not null unique,
  customer_id uuid not null references auth.users(id) on delete restrict,
  department_id uuid not null references departments(id) on delete restrict,
  service_category_id uuid not null,
  status request_status not null default 'new',
  subject text not null,
  description text not null,
  contact_phone text,
  assigned_to uuid references auth.users(id) on delete set null,
  submitted_at timestamptz not null default now(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  closed_at timestamptz,
  constraint service_requests_category_match_fk
    foreign key (service_category_id, department_id)
    references service_categories(id, department_id) on delete restrict,
  constraint service_requests_subject_check check (length(trim(subject)) > 0),
  constraint service_requests_description_check check (length(trim(description)) > 0),
  constraint service_requests_contact_phone_check check (contact_phone is null or length(trim(contact_phone)) between 4 and 30)
);

create index if not exists service_requests_customer_created_idx
  on service_requests (customer_id, created_at desc);
create index if not exists service_requests_department_status_idx
  on service_requests (department_id, status, created_at desc);
create index if not exists service_requests_assignee_status_idx
  on service_requests (assigned_to, status, created_at desc);
create index if not exists service_requests_category_idx
  on service_requests (service_category_id, created_at desc);

create table if not exists service_request_events (
  id uuid primary key default gen_random_uuid(),
  service_request_id uuid not null references service_requests(id) on delete restrict,
  actor_user_id uuid references auth.users(id) on delete set null,
  event_type text not null,
  old_status request_status,
  new_status request_status,
  customer_visible boolean not null default true,
  message text,
  created_at timestamptz not null default now(),
  constraint service_request_events_event_type_check check (
    event_type in (
      'created',
      'status_changed',
      'assigned',
      'customer_message',
      'staff_note',
      'reopened',
      'closed',
      'cancelled',
      'notification'
    )
  ),
  constraint service_request_events_status_pair_check
    check (
      (event_type <> 'status_changed')
      or (new_status is not null)
    )
);

create index if not exists service_request_events_request_created_idx
  on service_request_events (service_request_id, created_at desc);
create index if not exists service_request_events_visible_idx
  on service_request_events (service_request_id, customer_visible, created_at desc);

create table if not exists service_request_internal_notes (
  id uuid primary key default gen_random_uuid(),
  service_request_id uuid not null references service_requests(id) on delete restrict,
  author_user_id uuid references auth.users(id) on delete set null,
  body text not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint service_request_internal_notes_body_check check (length(trim(body)) > 0)
);

create index if not exists service_request_internal_notes_request_idx
  on service_request_internal_notes (service_request_id, created_at desc);

create table if not exists notifications (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  service_request_id uuid references service_requests(id) on delete cascade,
  kind notification_kind not null,
  title text not null,
  body text not null,
  read_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint notifications_title_check check (length(trim(title)) > 0),
  constraint notifications_body_check check (length(trim(body)) > 0)
);

create index if not exists notifications_user_created_idx
  on notifications (user_id, created_at desc);
create index if not exists notifications_unread_idx
  on notifications (user_id, created_at desc)
  where read_at is null;

create table if not exists support_threads (
  id uuid primary key default gen_random_uuid(),
  customer_id uuid not null references auth.users(id) on delete restrict,
  department_id uuid references departments(id) on delete restrict,
  service_request_id uuid references service_requests(id) on delete restrict,
  assigned_to uuid references auth.users(id) on delete set null,
  subject text not null,
  status support_thread_status not null default 'open',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  closed_at timestamptz,
  constraint support_threads_subject_check check (length(trim(subject)) > 0)
);

create index if not exists support_threads_customer_updated_idx
  on support_threads (customer_id, updated_at desc);
create index if not exists support_threads_department_status_idx
  on support_threads (department_id, status, updated_at desc);
create index if not exists support_threads_assignee_status_idx
  on support_threads (assigned_to, status, updated_at desc);
create index if not exists support_threads_request_idx
  on support_threads (service_request_id);

create table if not exists support_messages (
  id uuid primary key default gen_random_uuid(),
  thread_id uuid not null references support_threads(id) on delete restrict,
  sender_user_id uuid not null references auth.users(id) on delete restrict,
  body text not null,
  created_at timestamptz not null default now(),
  constraint support_messages_body_check check (length(trim(body)) > 0)
);

create index if not exists support_messages_thread_created_idx
  on support_messages (thread_id, created_at desc);

create table if not exists support_internal_notes (
  id uuid primary key default gen_random_uuid(),
  thread_id uuid not null references support_threads(id) on delete restrict,
  author_user_id uuid references auth.users(id) on delete set null,
  body text not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint support_internal_notes_body_check check (length(trim(body)) > 0)
);

create index if not exists support_internal_notes_thread_idx
  on support_internal_notes (thread_id, created_at desc);

create table if not exists admin_audit_log (
  id uuid primary key default gen_random_uuid(),
  actor_user_id uuid references auth.users(id) on delete set null,
  action text not null,
  entity_type text not null,
  entity_id uuid,
  department_id uuid references departments(id) on delete set null,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  constraint admin_audit_action_check check (length(trim(action)) > 0),
  constraint admin_audit_entity_type_check check (length(trim(entity_type)) > 0)
);

create index if not exists admin_audit_actor_idx
  on admin_audit_log (actor_user_id, created_at desc);
create index if not exists admin_audit_entity_idx
  on admin_audit_log (entity_type, entity_id, created_at desc);
create index if not exists admin_audit_department_idx
  on admin_audit_log (department_id, created_at desc);

create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create trigger profiles_set_updated_at
before update on profiles
for each row execute function public.set_updated_at();

create trigger departments_set_updated_at
before update on departments
for each row execute function public.set_updated_at();

create trigger service_categories_set_updated_at
before update on service_categories
for each row execute function public.set_updated_at();

create trigger user_roles_set_updated_at
before update on user_roles
for each row execute function public.set_updated_at();

create trigger service_requests_set_updated_at
before update on service_requests
for each row execute function public.set_updated_at();

create trigger service_request_internal_notes_set_updated_at
before update on service_request_internal_notes
for each row execute function public.set_updated_at();

create trigger notifications_set_updated_at
before update on notifications
for each row execute function public.set_updated_at();

create trigger support_threads_set_updated_at
before update on support_threads
for each row execute function public.set_updated_at();

create trigger support_internal_notes_set_updated_at
before update on support_internal_notes
for each row execute function public.set_updated_at();

create or replace function public.has_active_role(_user_id uuid, _role app_role, _department_id uuid default null)
returns boolean
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select exists (
    select 1
    from public.user_roles ur
    where ur.user_id = _user_id
      and ur.role = _role
      and ur.revoked_at is null
      and (
        (_department_id is null and ur.department_id is null)
        or (_department_id is not null and ur.department_id = _department_id)
      )
  );
$$;

create or replace function public.has_global_admin_access()
returns boolean
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select public.has_active_role(auth.uid(), 'administrator', null)
      or public.has_active_role(auth.uid(), 'super_administrator', null);
$$;

create or replace function public.has_department_scope(_department_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select public.has_active_role(auth.uid(), 'department_administrator', _department_id)
      or public.has_active_role(auth.uid(), 'support_agent', _department_id)
      or public.has_active_role(auth.uid(), 'administrator', null)
      or public.has_active_role(auth.uid(), 'super_administrator', null);
$$;

create or replace function public.generate_request_number()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if new.request_number is null or new.request_number = '' then
    new.request_number := 'SR-' || to_char(now(), 'YYYYMMDD') || '-' || lpad(nextval('service_requests_request_number_seq')::text, 6, '0');
  end if;
  return new;
end;
$$;

create trigger service_requests_request_number_before_insert
before insert on service_requests
for each row execute function public.generate_request_number();

alter table departments enable row level security;
alter table service_categories enable row level security;
alter table profiles enable row level security;
alter table user_roles enable row level security;
alter table service_requests enable row level security;
alter table service_request_events enable row level security;
alter table service_request_internal_notes enable row level security;
alter table notifications enable row level security;
alter table support_threads enable row level security;
alter table support_messages enable row level security;
alter table support_internal_notes enable row level security;
alter table admin_audit_log enable row level security;

create policy "departments_public_select"
on departments
for select
using (active = true);

create policy "departments_admin_all"
on departments
for all
using (
  public.has_active_role(auth.uid(), 'administrator', null)
  or public.has_active_role(auth.uid(), 'super_administrator', null)
)
with check (
  public.has_active_role(auth.uid(), 'administrator', null)
  or public.has_active_role(auth.uid(), 'super_administrator', null)
);

create policy "service_categories_public_select"
on service_categories
for select
using (active = true);

create policy "service_categories_admin_all"
on service_categories
for all
using (
  public.has_active_role(auth.uid(), 'administrator', null)
  or public.has_active_role(auth.uid(), 'super_administrator', null)
)
with check (
  public.has_active_role(auth.uid(), 'administrator', null)
  or public.has_active_role(auth.uid(), 'super_administrator', null)
);

create policy "profiles_select_own"
on profiles
for select
using (id = auth.uid());

create policy "profiles_insert_own"
on profiles
for insert
with check (id = auth.uid());

create policy "profiles_update_own"
on profiles
for update
using (id = auth.uid())
with check (id = auth.uid());

create policy "user_roles_select_own"
on user_roles
for select
using (user_id = auth.uid());

create policy "user_roles_admin_only"
on user_roles
for all
using (
  public.has_active_role(auth.uid(), 'super_administrator', null)
  or public.has_active_role(auth.uid(), 'administrator', null)
)
with check (
  public.has_active_role(auth.uid(), 'super_administrator', null)
  or public.has_active_role(auth.uid(), 'administrator', null)
);

create policy "service_requests_customer_select_own"
on service_requests
for select
using (customer_id = auth.uid());

create policy "service_requests_customer_insert_own"
on service_requests
for insert
with check (
  customer_id = auth.uid()
  and status = 'new'
);

create policy "service_requests_staff_select_authorized"
on service_requests
for select
using (
  public.has_active_role(auth.uid(), 'support_agent', department_id)
  or public.has_active_role(auth.uid(), 'department_administrator', department_id)
  or public.has_active_role(auth.uid(), 'administrator', null)
  or public.has_active_role(auth.uid(), 'super_administrator', null)
  or customer_id = auth.uid()
);

create policy "service_requests_staff_update_authorized"
on service_requests
for update
using (
  public.has_active_role(auth.uid(), 'support_agent', department_id)
  or public.has_active_role(auth.uid(), 'department_administrator', department_id)
  or public.has_active_role(auth.uid(), 'administrator', null)
  or public.has_active_role(auth.uid(), 'super_administrator', null)
)
with check (
  customer_id = old.customer_id
  and department_id = old.department_id
);

create policy "service_request_events_select_own"
on service_request_events
for select
using (
  exists (
    select 1
    from public.service_requests sr
    where sr.id = service_request_id
      and sr.customer_id = auth.uid()
  )
  or public.has_active_role(auth.uid(), 'support_agent', (
      select department_id from public.service_requests sr where sr.id = service_request_id
    ))
  or public.has_active_role(auth.uid(), 'department_administrator', (
      select department_id from public.service_requests sr where sr.id = service_request_id
    ))
  or public.has_active_role(auth.uid(), 'administrator', null)
  or public.has_active_role(auth.uid(), 'super_administrator', null)
);

create policy "service_request_events_insert_staff_only"
on service_request_events
for insert
with check (
  public.has_active_role(auth.uid(), 'support_agent', (
      select department_id from public.service_requests sr where sr.id = service_request_id
    ))
  or public.has_active_role(auth.uid(), 'department_administrator', (
      select department_id from public.service_requests sr where sr.id = service_request_id
    ))
  or public.has_active_role(auth.uid(), 'administrator', null)
  or public.has_active_role(auth.uid(), 'super_administrator', null)
);

create policy "service_request_internal_notes_staff_only"
on service_request_internal_notes
for all
using (
  public.has_active_role(auth.uid(), 'support_agent', (
      select department_id from public.service_requests sr where sr.id = service_request_id
    ))
  or public.has_active_role(auth.uid(), 'department_administrator', (
      select department_id from public.service_requests sr where sr.id = service_request_id
    ))
  or public.has_active_role(auth.uid(), 'administrator', null)
  or public.has_active_role(auth.uid(), 'super_administrator', null)
)
with check (
  public.has_active_role(auth.uid(), 'support_agent', (
      select department_id from public.service_requests sr where sr.id = service_request_id
    ))
  or public.has_active_role(auth.uid(), 'department_administrator', (
      select department_id from public.service_requests sr where sr.id = service_request_id
    ))
  or public.has_active_role(auth.uid(), 'administrator', null)
  or public.has_active_role(auth.uid(), 'super_administrator', null)
);

create policy "notifications_select_own"
on notifications
for select
using (user_id = auth.uid());

create policy "notifications_update_own_read_state"
on notifications
for update
using (user_id = auth.uid())
with check (user_id = auth.uid());

create policy "support_threads_select_own"
on support_threads
for select
using (
  customer_id = auth.uid()
  or public.has_active_role(auth.uid(), 'support_agent', department_id)
  or public.has_active_role(auth.uid(), 'department_administrator', department_id)
  or public.has_active_role(auth.uid(), 'administrator', null)
  or public.has_active_role(auth.uid(), 'super_administrator', null)
);

create policy "support_threads_customer_insert_own"
on support_threads
for insert
with check (
  customer_id = auth.uid()
  and department_id is not null
);

create policy "support_threads_staff_update_authorized"
on support_threads
for update
using (
  public.has_active_role(auth.uid(), 'support_agent', department_id)
  or public.has_active_role(auth.uid(), 'department_administrator', department_id)
  or public.has_active_role(auth.uid(), 'administrator', null)
  or public.has_active_role(auth.uid(), 'super_administrator', null)
)
with check (
  customer_id = old.customer_id
);

create policy "support_messages_select_own"
on support_messages
for select
using (
  sender_user_id = auth.uid()
  or exists (
    select 1
    from public.support_threads st
    where st.id = thread_id
      and st.customer_id = auth.uid()
  )
  or public.has_active_role(auth.uid(), 'support_agent', (
      select department_id from public.support_threads st where st.id = thread_id
    ))
  or public.has_active_role(auth.uid(), 'department_administrator', (
      select department_id from public.support_threads st where st.id = thread_id
    ))
  or public.has_active_role(auth.uid(), 'administrator', null)
  or public.has_active_role(auth.uid(), 'super_administrator', null)
);

create policy "support_messages_insert_own"
on support_messages
for insert
with check (
  sender_user_id = auth.uid()
  and exists (
    select 1
    from public.support_threads st
    where st.id = thread_id
      and st.customer_id = auth.uid()
  )
);

create policy "support_messages_staff_insert_authorized"
on support_messages
for insert
with check (
  sender_user_id = auth.uid()
  and (
    public.has_active_role(auth.uid(), 'support_agent', (
      select department_id from public.support_threads st where st.id = thread_id
    ))
    or public.has_active_role(auth.uid(), 'department_administrator', (
      select department_id from public.support_threads st where st.id = thread_id
    ))
    or public.has_active_role(auth.uid(), 'administrator', null)
    or public.has_active_role(auth.uid(), 'super_administrator', null)
  )
);

create policy "support_internal_notes_staff_only"
on support_internal_notes
for all
using (
  public.has_active_role(auth.uid(), 'support_agent', (
    select department_id from public.support_threads st where st.id = thread_id
  ))
  or public.has_active_role(auth.uid(), 'department_administrator', (
    select department_id from public.support_threads st where st.id = thread_id
  ))
  or public.has_active_role(auth.uid(), 'administrator', null)
  or public.has_active_role(auth.uid(), 'super_administrator', null)
)
with check (
  public.has_active_role(auth.uid(), 'support_agent', (
    select department_id from public.support_threads st where st.id = thread_id
  ))
  or public.has_active_role(auth.uid(), 'department_administrator', (
    select department_id from public.support_threads st where st.id = thread_id
  ))
  or public.has_active_role(auth.uid(), 'administrator', null)
  or public.has_active_role(auth.uid(), 'super_administrator', null)
);

create policy "admin_audit_log_admin_only"
on admin_audit_log
for select
using (
  public.has_active_role(auth.uid(), 'administrator', null)
  or public.has_active_role(auth.uid(), 'super_administrator', null)
);

create policy "admin_audit_log_no_direct_client_write"
on admin_audit_log
for insert with check (false);
create policy "admin_audit_log_no_direct_client_update"
on admin_audit_log
for update using (false) with check (false);
create policy "admin_audit_log_no_direct_client_delete"
on admin_audit_log
for delete using (false);

insert into departments (slug, name, description, sort_order)
values
  ('technology', 'Technology', 'Technology and digital product development services.', 1),
  ('digital-services', 'Digital Services', 'Digital products and service support.', 2),
  ('crypto-finance', 'Crypto & Finance', 'Information, education, and fintech topics.', 3),
  ('real-estate', 'Real Estate', 'Property and land opportunities.', 4),
  ('gadgets', 'Gadgets', 'Gadget and electronic enquiries.', 5),
  ('publications', 'Publications', 'Educational and digital publication content.', 6)
on conflict (slug) do nothing;

insert into service_categories (department_id, slug, name, description, sort_order)
select d.id, 'website-development', 'Website Development', 'Responsive business and marketing websites.', 1
from departments d where d.slug = 'technology'
union all
select d.id, 'software-development', 'Software Development', 'Business software and workflow tools.', 2
from departments d where d.slug = 'technology'
union all
select d.id, 'digital-subscriptions', 'Digital Subscriptions', 'Account and fulfilment support for digital services.', 1
from departments d where d.slug = 'digital-services'
union all
select d.id, 'sms-otp', 'SMS and OTP', 'Verification, activation, and messaging-related service enquiries.', 2
from departments d where d.slug = 'digital-services'
on conflict (department_id, slug) do nothing;

commit;
