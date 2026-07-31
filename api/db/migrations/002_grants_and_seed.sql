-- Defesa em profundidade da R7/R35: o papel usado pela aplicação não recebe
-- UPDATE nem DELETE em tabelas de histórico. Correção só cria evento novo.

CREATE ROLE traceagro_app LOGIN PASSWORD 'traceagro_app_dev';

GRANT USAGE ON SCHEMA core, read_model TO traceagro_app;

-- Cadastros: leitura e escrita normais.
GRANT SELECT, INSERT, UPDATE ON
  core.organization, core.app_user, core.property, core.device
  TO traceagro_app;

-- Histórico imutável: só INSERT e SELECT.
GRANT SELECT, INSERT ON
  core.event, core.event_payload, core.audit_log, core.animal
  TO traceagro_app;

-- animal_identifier aceita UPDATE apenas para inativação (active/unlink_*);
-- a coluna do vínculo em si nunca muda — controlado na aplicação.
GRANT SELECT, INSERT, UPDATE ON core.animal_identifier TO traceagro_app;

GRANT SELECT, INSERT, UPDATE ON
  core.sync_job, core.sync_conflict, core.blockchain_anchor
  TO traceagro_app;

-- Projeções são regeráveis: DELETE liberado para replay.
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA read_model
  TO traceagro_app;

-- Correção de evento marca o alvo (corrected=true) — única mutação permitida.
CREATE OR REPLACE FUNCTION core.mark_event_corrected(target uuid)
RETURNS void
LANGUAGE sql
SECURITY DEFINER
AS $$
  UPDATE core.event SET corrected = true WHERE id = target;
$$;

GRANT EXECUTE ON FUNCTION core.mark_event_corrected(uuid) TO traceagro_app;

-- ------------------------------------------------------------------- seed
-- Dados mínimos do laboratório: organização, usuário, propriedade,
-- dispositivo e o rebanho de demonstração da Fazenda Santa Rita.

INSERT INTO core.organization (id, legal_name, cnpj, org_type, fabric_msp_id)
VALUES
  ('22222222-2222-4222-8222-222222222222', 'Fazenda Santa Rita Agropecuária',
   '12345678000190', 'PRODUCER', 'OrgProdutoresMSP'),
  ('22222222-2222-4222-8222-000000000001', 'Fundação TraceAgro',
   '98765432000110', 'FOUNDATION', 'OrgFundacaoMSP');

INSERT INTO core.app_user (id, oidc_subject, name, email, organization_id,
                           professional_credential)
VALUES
  ('33333333-3333-4333-8333-333333333333', 'joao.p', 'João P.',
   'joao@santarita.example', '22222222-2222-4222-8222-222222222222', NULL),
  ('33333333-3333-4333-8333-000000000002', 'carla.m', 'Dra. Carla M.',
   'carla@vet.example', '22222222-2222-4222-8222-222222222222',
   '{"type":"CRMV","number":"8812","uf":"GO","validUntil":"2027-12-31"}');

INSERT INTO core.property (id, organization_id, name, state_registration, uf,
                           municipality, official_property_code)
VALUES
  ('66666666-6666-4666-8666-666666666666',
   '22222222-2222-4222-8222-222222222222', 'Fazenda Santa Rita',
   '1234567', 'GO', 'Jataí', 'GO-0001234');

INSERT INTO core.device (id, organization_id, model, os_version, public_key,
                         status)
VALUES
  ('44444444-4444-4444-8444-444444444444',
   '22222222-2222-4222-8222-222222222222', 'Field Terminal A1', 'Android 14',
   'dev-public-key-placeholder', 'ACTIVE');

INSERT INTO core.animal (id, official_animal_id, breed_code, sex, birth_date,
                         birth_type)
VALUES
  ('11111111-1111-4111-8111-000000004127', '076000123456789', 'NELORE', 'F',
   '2025-05-20', 'BORN_ON_PROPERTY'),
  ('11111111-1111-4111-8111-000000004088', NULL, 'NELORE', 'M',
   '2025-03-14', 'BORN_ON_PROPERTY'),
  ('11111111-1111-4111-8111-000000003950', '076000123456655', 'ABERDEEN', 'F',
   '2024-09-02', 'PURCHASED'),
  ('11111111-1111-4111-8111-000000004201', NULL, 'NELORE', 'M',
   '2025-10-11', 'BORN_ON_PROPERTY');

INSERT INTO core.animal_identifier (id, animal_id, identifier_type, rfid_code,
                                    visual_tag_number, active, linked_at,
                                    link_event_id)
VALUES
  ('aaaa1111-1111-4111-8111-000000000001',
   '11111111-1111-4111-8111-000000004127', 'RFID', '982000123456789', NULL,
   true, now() - interval '420 days', '00000000-0000-4000-8000-000000000001'),
  ('aaaa1111-1111-4111-8111-000000000002',
   '11111111-1111-4111-8111-000000004127', 'VISUAL', NULL, '4127',
   true, now() - interval '420 days', '00000000-0000-4000-8000-000000000001'),
  ('aaaa1111-1111-4111-8111-000000000003',
   '11111111-1111-4111-8111-000000004088', 'RFID', '982000123456702', NULL,
   true, now() - interval '400 days', '00000000-0000-4000-8000-000000000002'),
  ('aaaa1111-1111-4111-8111-000000000004',
   '11111111-1111-4111-8111-000000004088', 'VISUAL', NULL, '4088',
   true, now() - interval '400 days', '00000000-0000-4000-8000-000000000002'),
  ('aaaa1111-1111-4111-8111-000000000005',
   '11111111-1111-4111-8111-000000003950', 'RFID', '982000123456655', NULL,
   true, now() - interval '300 days', '00000000-0000-4000-8000-000000000003'),
  ('aaaa1111-1111-4111-8111-000000000006',
   '11111111-1111-4111-8111-000000003950', 'VISUAL', NULL, '3950',
   true, now() - interval '300 days', '00000000-0000-4000-8000-000000000003'),
  ('aaaa1111-1111-4111-8111-000000000007',
   '11111111-1111-4111-8111-000000004201', 'RFID', '982000123456790', NULL,
   true, now() - interval '200 days', '00000000-0000-4000-8000-000000000004'),
  ('aaaa1111-1111-4111-8111-000000000008',
   '11111111-1111-4111-8111-000000004201', 'VISUAL', NULL, '4201',
   true, now() - interval '200 days', '00000000-0000-4000-8000-000000000004');

INSERT INTO read_model.animal_state (animal_id, current_property_id,
                                     current_herd_lot, last_weight_kg,
                                     last_weight_at, gmd_kg_day)
VALUES
  ('11111111-1111-4111-8111-000000004127',
   '66666666-6666-4666-8666-666666666666', 'Recria 12', 287.50,
   now() - interval '3 hours', 0.590),
  ('11111111-1111-4111-8111-000000004088',
   '66666666-6666-4666-8666-666666666666', 'Recria 12', 312.00,
   now() - interval '3 hours', 0.640),
  ('11111111-1111-4111-8111-000000003950',
   '66666666-6666-4666-8666-666666666666', 'Engorda 03', 401.20,
   now() - interval '10 days', 0.480),
  ('11111111-1111-4111-8111-000000004201',
   '66666666-6666-4666-8666-666666666666', 'Recria 12', 198.00,
   now() - interval '12 days', 0.710);

UPDATE read_model.animal_state
SET withdrawal_until = now() + interval '11 days', quarantined = true
WHERE animal_id = '11111111-1111-4111-8111-000000003950';
