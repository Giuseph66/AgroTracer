-- Conta de administração adicional para testes locais (Doc 7 §4/§5).

INSERT INTO core.app_user (id, oidc_subject, name, email, organization_id)
VALUES
  ('33333333-3333-4333-8333-000000000003', 'giuseph@gmail.com', 'Giuseph',
   'giuseph@gmail.com', '22222222-2222-4222-8222-222222222222')
ON CONFLICT (lower(email)) WHERE email IS NOT NULL DO NOTHING;

INSERT INTO core.user_role_binding
  (user_id, organization_id, role_code, valid_from)
SELECT
  '33333333-3333-4333-8333-000000000003',
  '22222222-2222-4222-8222-222222222222',
  'ADMO',
  now() - interval '1 day'
WHERE NOT EXISTS (
  SELECT 1 FROM core.user_role_binding
   WHERE user_id = '33333333-3333-4333-8333-000000000003'
     AND organization_id = '22222222-2222-4222-8222-222222222222'
     AND role_code = 'ADMO'
     AND valid_from <= now()
     AND (valid_to IS NULL OR valid_to > now())
);
