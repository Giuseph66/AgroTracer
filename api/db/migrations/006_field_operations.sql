-- TraceAgro — operações de campo (catálogo, áreas e embarques).
-- Migração aditiva: mantém o histórico de eventos intacto.

CREATE TABLE IF NOT EXISTS core.vet_product (
  id                         uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  code                       text NOT NULL UNIQUE,
  name                       text NOT NULL,
  active_ingredient          text,
  withdrawal_slaughter_days  integer NOT NULL DEFAULT 0 CHECK (withdrawal_slaughter_days >= 0),
  withdrawal_milk_days       integer NOT NULL DEFAULT 0 CHECK (withdrawal_milk_days >= 0),
  active                     boolean NOT NULL DEFAULT true,
  created_at                 timestamptz NOT NULL DEFAULT now()
);

INSERT INTO core.vet_product
  (code, name, active_ingredient, withdrawal_slaughter_days, withdrawal_milk_days)
VALUES
  ('AFTOSA-BIV', 'Vacina contra febre aftosa', 'Antígenos inativados', 0, 0),
  ('CLOSTRI-8', 'Clostridioses 8 vias', 'Bacterinas clostridiais', 0, 0),
  ('IVERMECTINA-1', 'Ivermectina 1%', 'Ivermectina', 28, 0)
ON CONFLICT (code) DO NOTHING;

CREATE TABLE IF NOT EXISTS core.paddock (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  property_id uuid NOT NULL REFERENCES core.property(id),
  name        text NOT NULL,
  geom        geometry(Polygon, 4674) NOT NULL,
  version     integer NOT NULL DEFAULT 1,
  valid_from  timestamptz NOT NULL DEFAULT now(),
  valid_to    timestamptz,
  active      boolean NOT NULL DEFAULT true,
  created_at  timestamptz NOT NULL DEFAULT now(),
  UNIQUE (property_id, name, version)
);

CREATE INDEX IF NOT EXISTS paddock_property_idx ON core.paddock(property_id, active);

ALTER TABLE read_model.animal_state
  ADD COLUMN IF NOT EXISTS current_paddock_id uuid REFERENCES core.paddock(id);

ALTER TABLE read_model.health_record
  ADD COLUMN IF NOT EXISTS withdrawal_scope text NOT NULL DEFAULT 'SLAUGHTER',
  ADD COLUMN IF NOT EXISTS batch_id text;

CREATE TABLE IF NOT EXISTS core.shipment (
  id                   uuid PRIMARY KEY,
  origin_property_id   uuid NOT NULL REFERENCES core.property(id),
  destination_property_id uuid,
  purpose              text NOT NULL,
  carrier_org_id       uuid,
  vehicle_plate        text,
  gta_number           text,
  gta_uf               varchar(2),
  status               text NOT NULL DEFAULT 'DRAFT'
                       CHECK (status IN ('DRAFT','DISPATCHED','RECEIVED','RECEIVED_WITH_DISCREPANCY','CANCELLED')),
  expected_arrival     timestamptz,
  created_at           timestamptz NOT NULL DEFAULT now(),
  dispatched_at        timestamptz,
  received_at          timestamptz
);

CREATE TABLE IF NOT EXISTS core.shipment_animal (
  shipment_id  uuid NOT NULL REFERENCES core.shipment(id),
  animal_id    uuid NOT NULL REFERENCES core.animal(id),
  received     boolean NOT NULL DEFAULT false,
  discrepancy  text,
  PRIMARY KEY (shipment_id, animal_id)
);

CREATE INDEX IF NOT EXISTS shipment_status_idx ON core.shipment(status, created_at DESC);
CREATE INDEX IF NOT EXISTS shipment_animal_animal_idx ON core.shipment_animal(animal_id);

GRANT SELECT, INSERT, UPDATE ON
  core.vet_product, core.paddock, core.shipment, core.shipment_animal
  TO traceagro_app;
GRANT SELECT, INSERT, UPDATE ON read_model.health_record TO traceagro_app;
