# Supabase migration files for PRINKLIN ZAM PROMOTIONS

This repository has the static GitHub Pages frontend only. The SQL in `supabase/migrations/20261113_001_core_schema.sql` is the first backend implementation phase for:

- departments
- service_categories
- profiles
- user_roles
- service_requests
- service_request_events
- service_request_internal_notes
- notifications
- support_threads
- support_messages
- support_internal_notes
- admin_audit_log

It includes:

- PostgreSQL enums for roles, request status, and thread status
- Row-level security setup and default-deny policies
- Helper functions for active-role checks
- Request number generation and updated-at triggers
- Department seed data for the six current departments

This is a schema and security layer only. It intentionally does not create any live Supabase objects in this repository and does not implement Auth, dashboards, or frontend integrations yet.
