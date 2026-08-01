-- TraceAgro — vínculos de acesso com vigência (Doc 7 / R28).

CREATE TABLE IF NOT EXISTS core.user_role_binding (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id         uuid NOT NULL REFERENCES core.app_user(id),
  organization_id uuid NOT NULL REFERENCES core.organization(id),
  role_code       text NOT NULL,
  valid_from      timestamptz NOT NULL DEFAULT now(),
  valid_to        timestamptz,
  created_at      timestamptz NOT NULL DEFAULT now(),
  CHECK (valid_to IS NULL OR valid_to > valid_from),
  UNIQUE (user_id, organization_id, role_code, valid_from)
);

CREATE INDEX IF NOT EXISTS user_role_binding_active_idx
  ON core.user_role_binding(user_id, organization_id, valid_from, valid_to);

INSERT INTO core.user_role_binding
  (user_id, organization_id, role_code, valid_from)
VALUES
  ('33333333-3333-4333-8333-333333333333',
   '22222222-2222-4222-8222-222222222222', 'OPER', now() - interval '1 day'),
  ('33333333-3333-4333-8333-333333333333',
   '22222222-2222-4222-8222-222222222222', 'PROD', now() - interval '1 day'),
  ('33333333-3333-4333-8333-000000000002',
   '22222222-2222-4222-8222-222222222222', 'VETE', now() - interval '1 day')
ON CONFLICT (user_id, organization_id, role_code, valid_from) DO NOTHING;

GRANT SELECT, INSERT, UPDATE ON core.user_role_binding TO traceagro_app;
