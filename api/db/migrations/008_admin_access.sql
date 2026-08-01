-- Administração de usuários e roles (Doc 7 §4/§5).

CREATE UNIQUE INDEX IF NOT EXISTS app_user_email_uq
  ON core.app_user (lower(email)) WHERE email IS NOT NULL;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
     WHERE conname = 'user_role_binding_role_code_check'
  ) THEN
    ALTER TABLE core.user_role_binding
      ADD CONSTRAINT user_role_binding_role_code_check
      CHECK (role_code IN (
        'OPER', 'PROD', 'TECN', 'VETE', 'CERT', 'TRAN',
        'FRIG', 'AUDI', 'ADMO', 'ADMP', 'PUBL'
      ));
  END IF;
END $$;

-- Administrador do laboratório. O vínculo é temporal e pode ser encerrado
-- pela própria central; não há papel implícito no código.
INSERT INTO core.user_role_binding
  (user_id, organization_id, role_code, valid_from)
SELECT
  '33333333-3333-4333-8333-333333333333',
  '22222222-2222-4222-8222-222222222222',
  'ADMO',
  now() - interval '1 day'
WHERE NOT EXISTS (
  SELECT 1 FROM core.user_role_binding
   WHERE user_id = '33333333-3333-4333-8333-333333333333'
     AND organization_id = '22222222-2222-4222-8222-222222222222'
     AND role_code = 'ADMO'
     AND valid_from <= now()
     AND (valid_to IS NULL OR valid_to > now())
);
