-- R23 (API idempotente) precisa valer também para o que foi rejeitado ou virou
-- conflito: esses eventos não entram em core.event, então o veredicto de cada
-- eventId processado é registrado aqui e devolvido tal e qual no reenvio.

CREATE TABLE core.ingestion_verdict (
  event_id          uuid PRIMARY KEY,
  status            text        NOT NULL
                    CHECK (status IN ('ACCEPTED','REJECTED','CONFLICT')),
  code              text,
  detail            text,
  device_id         uuid,
  device_sequence   bigint,
  conflict_id       uuid,
  decided_at        timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX ingestion_verdict_device_idx
  ON core.ingestion_verdict (device_id, device_sequence);

GRANT SELECT, INSERT ON core.ingestion_verdict TO traceagro_app;
