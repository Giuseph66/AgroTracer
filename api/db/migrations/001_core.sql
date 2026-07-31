-- TraceAgro — schema núcleo (Documento 4).
-- Princípio: evento é a fonte de verdade e é append-only; nada de estado
-- corrente editável. Projeções vivem em schema separado e são regeráveis.

CREATE EXTENSION IF NOT EXISTS postgis;

CREATE SCHEMA IF NOT EXISTS core;
CREATE SCHEMA IF NOT EXISTS read_model;

-- ---------------------------------------------------------------- cadastros

CREATE TABLE core.organization (
  id                uuid PRIMARY KEY,
  legal_name        text        NOT NULL,
  cnpj              varchar(14) UNIQUE,
  org_type          text        NOT NULL
                    CHECK (org_type IN ('FOUNDATION','PRODUCER','CERTIFIER',
                                        'SLAUGHTERHOUSE','CARRIER','AUDIT')),
  status            text        NOT NULL DEFAULT 'ACTIVE'
                    CHECK (status IN ('ACTIVE','SUSPENDED','ARCHIVED')),
  fabric_msp_id     text,
  created_at        timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE core.app_user (
  id                uuid PRIMARY KEY,
  oidc_subject      text UNIQUE,
  name              text        NOT NULL,
  email             text,
  organization_id   uuid        NOT NULL REFERENCES core.organization(id),
  -- credencial profissional (CRMV etc.) com vigência — validada em R17
  professional_credential jsonb,
  status            text        NOT NULL DEFAULT 'ACTIVE'
                    CHECK (status IN ('ACTIVE','SUSPENDED','REVOKED')),
  revoked_at        timestamptz,
  created_at        timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE core.property (
  id                uuid PRIMARY KEY,
  organization_id   uuid        NOT NULL REFERENCES core.organization(id),
  name              text        NOT NULL,
  state_registration text,
  uf                varchar(2),
  municipality      text,
  official_property_code text,
  geom              geometry(Polygon, 4674),
  created_at        timestamptz NOT NULL DEFAULT now(),
  UNIQUE (state_registration, uf)
);

CREATE TABLE core.device (
  id                uuid PRIMARY KEY,
  organization_id   uuid        NOT NULL REFERENCES core.organization(id),
  model             text,
  os_version        text,
  -- chave pública do par gerado no Keystore do aparelho; valida assinatura (R26)
  public_key        text UNIQUE,
  attestation       jsonb,
  status            text        NOT NULL DEFAULT 'ACTIVE'
                    CHECK (status IN ('ACTIVE','BLOCKED','REVOKED')),
  last_sequence     bigint      NOT NULL DEFAULT 0,
  enrolled_at       timestamptz NOT NULL DEFAULT now(),
  revoked_at        timestamptz
);

-- ------------------------------------------------------------------ animais

CREATE TABLE core.animal (
  id                uuid PRIMARY KEY,             -- animalId, imutável (R1)
  official_animal_id varchar(20),                 -- SISBOV/PNIB (R2)
  species_code      text        NOT NULL DEFAULT 'BOVINE',
  breed_code        text,
  sex               char(1)     NOT NULL CHECK (sex IN ('M','F')),
  birth_date        date,
  birth_type        text        NOT NULL
                    CHECK (birth_type IN ('BORN_ON_PROPERTY','PURCHASED',
                                          'IMPORTED_RECORD')),
  dam_id            uuid REFERENCES core.animal(id),
  sire_ref          text,
  created_at        timestamptz NOT NULL DEFAULT now()
);

CREATE UNIQUE INDEX animal_official_id_uq
  ON core.animal (official_animal_id) WHERE official_animal_id IS NOT NULL;

CREATE TABLE core.animal_identifier (
  id                uuid PRIMARY KEY,
  animal_id         uuid        NOT NULL REFERENCES core.animal(id),
  identifier_type   text        NOT NULL
                    CHECK (identifier_type IN ('RFID','VISUAL','OFFICIAL',
                                               'BIRTHMARK','OTHER')),
  rfid_code         varchar(24),
  visual_tag_number varchar(30),
  official_number   varchar(20),
  active            boolean     NOT NULL DEFAULT true,
  linked_at         timestamptz NOT NULL,
  unlinked_at       timestamptz,
  unlink_reason     text,
  link_event_id     uuid        NOT NULL,
  unlink_event_id   uuid
);

-- R3: um RFID ativo nunca em dois animais ao mesmo tempo.
CREATE UNIQUE INDEX animal_identifier_rfid_active_uq
  ON core.animal_identifier (rfid_code)
  WHERE active AND identifier_type = 'RFID';

-- R4: um identificador ativo por tipo por animal.
CREATE UNIQUE INDEX animal_identifier_type_active_uq
  ON core.animal_identifier (animal_id, identifier_type) WHERE active;

CREATE INDEX animal_identifier_animal_idx ON core.animal_identifier (animal_id);

-- ------------------------------------------------------------------ eventos

CREATE TABLE core.event (
  id                uuid PRIMARY KEY,             -- eventId (UUIDv7)
  schema_version    varchar(8)  NOT NULL,
  event_type        text        NOT NULL,
  subject_type      text        NOT NULL,
  animal_id         uuid REFERENCES core.animal(id),
  subject_id        uuid        NOT NULL,
  occurred_at       timestamptz NOT NULL,         -- fato (R24)
  recorded_at       timestamptz NOT NULL,         -- registro no dispositivo
  received_at       timestamptz NOT NULL DEFAULT now(),
  organization_id   uuid        NOT NULL REFERENCES core.organization(id),
  actor_id          uuid        NOT NULL REFERENCES core.app_user(id),
  device_id         uuid        NOT NULL REFERENCES core.device(id),
  device_sequence   bigint      NOT NULL,
  app_version       text        NOT NULL,
  property_id       uuid REFERENCES core.property(id),
  payload_hash      char(64)    NOT NULL,
  signature         text        NOT NULL,
  source_system     text        NOT NULL,
  correction_of     uuid REFERENCES core.event(id),
  corrected         boolean     NOT NULL DEFAULT false,
  sync_status       text        NOT NULL DEFAULT 'ACCEPTED_BY_API',
  blockchain_tx_id  text,
  clock_skew_ms     integer,
  time_suspect      boolean     NOT NULL DEFAULT false,
  -- R22: dedup secundário por dispositivo
  UNIQUE (device_id, device_sequence)
);

CREATE INDEX event_animal_idx      ON core.event (animal_id, occurred_at DESC);
CREATE INDEX event_subject_idx     ON core.event (subject_id, occurred_at DESC);
CREATE INDEX event_type_idx        ON core.event (event_type);
CREATE INDEX event_sync_status_idx ON core.event (sync_status);
CREATE INDEX event_correction_idx  ON core.event (correction_of)
  WHERE correction_of IS NOT NULL;

CREATE TABLE core.event_payload (
  event_id          uuid PRIMARY KEY REFERENCES core.event(id),
  schema_version    varchar(8)  NOT NULL,
  canonical_json    jsonb       NOT NULL
);

-- R7/R35: histórico não se apaga nem se edita. O papel da aplicação recebe
-- apenas INSERT/SELECT nestas tabelas (grants abaixo).
CREATE TABLE core.audit_log (
  id                uuid PRIMARY KEY,
  actor_id          uuid,
  organization_id   uuid,
  action            text        NOT NULL,
  target_type       text,
  target_id         text,
  detail            jsonb,
  ip                inet,
  user_agent        text,
  at                timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX audit_log_at_idx ON core.audit_log (at DESC);

-- ------------------------------------------------------- sync e blockchain

CREATE TABLE core.sync_job (
  id                uuid PRIMARY KEY,
  device_id         uuid        NOT NULL REFERENCES core.device(id),
  user_id           uuid,
  direction         text        NOT NULL CHECK (direction IN ('PUSH','PULL')),
  event_count       integer     NOT NULL DEFAULT 0,
  accepted_count    integer     NOT NULL DEFAULT 0,
  rejected_count    integer     NOT NULL DEFAULT 0,
  conflict_count    integer     NOT NULL DEFAULT 0,
  status            text        NOT NULL DEFAULT 'RECEIVED',
  clock_skew_ms     integer,
  started_at        timestamptz NOT NULL DEFAULT now(),
  finished_at       timestamptz
);

CREATE TABLE core.sync_conflict (
  id                uuid PRIMARY KEY,
  sync_job_id       uuid REFERENCES core.sync_job(id),
  event_id          uuid        NOT NULL,
  conflict_type     text        NOT NULL,
  resolution_status text        NOT NULL DEFAULT 'OPEN',
  resolved_by       uuid,
  resolved_at       timestamptz,
  detail            jsonb       NOT NULL,
  created_at        timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX sync_conflict_open_idx
  ON core.sync_conflict (resolution_status) WHERE resolution_status = 'OPEN';

CREATE TABLE core.blockchain_anchor (
  id                uuid PRIMARY KEY,
  subject_type      text        NOT NULL CHECK (subject_type IN ('EVENT','DOCUMENT')),
  subject_id        uuid        NOT NULL,
  payload_hash      char(64)    NOT NULL,
  channel           text        NOT NULL,
  chaincode_fn      text        NOT NULL,
  tx_id             text,
  block_number      bigint,
  status            text        NOT NULL DEFAULT 'PENDING'
                    CHECK (status IN ('PENDING','SUBMITTED','CONFIRMED','FAILED')),
  attempt           integer     NOT NULL DEFAULT 0,
  endorsing_orgs    jsonb,
  submitted_at      timestamptz,
  confirmed_at      timestamptz,
  last_error        text,
  created_at        timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX anchor_pending_idx ON core.blockchain_anchor (status, created_at)
  WHERE status IN ('PENDING','SUBMITTED');
CREATE INDEX anchor_subject_idx ON core.blockchain_anchor (subject_id);

-- ---------------------------------------------------------------- projeções
-- read_model.* é derivado: pode ser truncado e reconstruído por replay (R42).

CREATE TABLE read_model.animal_state (
  animal_id         uuid PRIMARY KEY REFERENCES core.animal(id),
  lifecycle_status  text        NOT NULL DEFAULT 'ACTIVE',
  current_property_id uuid,
  current_herd_lot  text,
  last_weight_kg    numeric(7,2),
  last_weight_at    timestamptz,
  gmd_kg_day        numeric(5,3),
  withdrawal_until  timestamptz,
  quarantined       boolean     NOT NULL DEFAULT false,
  event_count       integer     NOT NULL DEFAULT 0,
  updated_at        timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE read_model.weight_record (
  event_id          uuid PRIMARY KEY REFERENCES core.event(id),
  animal_id         uuid        NOT NULL REFERENCES core.animal(id),
  weight_kg         numeric(7,2) NOT NULL,
  weight_source     text        NOT NULL,
  occurred_at       timestamptz NOT NULL,
  valid             boolean     NOT NULL DEFAULT true
);

CREATE INDEX weight_record_animal_idx
  ON read_model.weight_record (animal_id, occurred_at DESC);

CREATE TABLE read_model.health_record (
  event_id          uuid PRIMARY KEY REFERENCES core.event(id),
  animal_id         uuid        NOT NULL REFERENCES core.animal(id),
  record_type       text        NOT NULL,
  product_ref       text,
  dosage            text,
  withdrawal_until  timestamptz,
  vet_user_id       uuid,
  occurred_at       timestamptz NOT NULL
);

CREATE INDEX health_record_animal_idx
  ON read_model.health_record (animal_id, occurred_at DESC);
