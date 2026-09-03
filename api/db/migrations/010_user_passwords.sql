-- Credencial individual para o login local de desenvolvimento.
-- O hash usa scrypt; senha nunca é armazenada em texto puro.

ALTER TABLE core.app_user
  ADD COLUMN IF NOT EXISTS password_hash text;

-- Usuários semeados antes do login individual mantêm a credencial de
-- laboratório `campo`; contas novas recebem senha no endpoint administrativo.
UPDATE core.app_user
   SET password_hash =
     'scrypt$16384$8$1$p535Rkz_ckX4iIKflw11UA$W53vU8V7Sk7KsysXyIdSPoXynUaSGsCLC-jZIlPHobuvx7tUYAjPXGJPJ_ESg7oOqRerhZyRW5ulogs0HS0rOA'
 WHERE password_hash IS NULL
   AND lower(email) NOT IN (
     'joao@santarita.example', 'carla@vet.example', 'giuseph@gmail.com'
   );

UPDATE core.app_user
   SET password_hash = CASE lower(email)
     WHEN 'joao@santarita.example' THEN
       'scrypt$16384$8$1$rBc6BfpOCYuTx_yqJHspYw$v9gKgABlpNSB_dCPujMBuSwtJQ5Esv2JBrajlQZLf53vywv_5lLt_uD5DnANXSZz2zAbJlhLtpsAty72qh1JkA'
     WHEN 'carla@vet.example' THEN
       'scrypt$16384$8$1$nx3KDm7tn9BTMp3NSYuwjQ$17nYPc7EG0D10t5Xlc9Ah7k-lMZ6F0qRywA_npPb4-NGyG3htbizRm3HK-2XpjINmgRshXSTZlqWiYjRhL__zw'
     WHEN 'giuseph@gmail.com' THEN
       'scrypt$16384$8$1$bzQESuT1kVz3rjmMkrnjLQ$AwDNgKMjQ3iwxOFkihrHrzv6ZuuQkSO_7OuhS7eR7tiVal2nXRYfIHmck1P_6dbcde2pNorzc061hm92oT5BaQ'
     ELSE password_hash
   END
 WHERE password_hash IS NULL
   AND lower(email) IN (
   'joao@santarita.example', 'carla@vet.example', 'giuseph@gmail.com'
 );

ALTER TABLE core.app_user
  ALTER COLUMN password_hash SET NOT NULL;
