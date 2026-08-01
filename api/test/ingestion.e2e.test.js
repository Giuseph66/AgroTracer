const { test, before, after } = require('node:test');
const assert = require('node:assert/strict');
const { randomUUID } = require('node:crypto');
const { v7: uuidv7 } = require('uuid');

const { payloadHash } = require('../dist/events/canonical.js');

/**
 * Testes de ingestão contra a API e o Postgres reais.
 *
 * Exigem `docker compose -f compose.dev.yml up -d` e a API rodando na porta
 * indicada por TRACEAGRO_API (padrão 3999). São os cenários do Documento 15
 * §3 e §4 que só têm valor quando exercitam o banco de verdade.
 */
const BASE = process.env.TRACEAGRO_API ?? 'http://localhost:3999';

const ANIMAL = '11111111-1111-4111-8111-000000004127';
const ANIMAL_2 = '11111111-1111-4111-8111-000000004088';
const DEVICE = '44444444-4444-4444-8444-444444444444';

let sequence = 0;
let token;

function headers(extra = {}) {
  return { ...extra, authorization: `Bearer ${token}` };
}

async function login() {
  const response = await fetch(`${BASE}/v1/auth/dev-login`, {
    method: 'POST',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify({
      email: 'joao@santarita.example',
      password: 'campo',
    }),
  });
  assert.equal(response.status, 201);
  token = (await response.json()).accessToken;
}

function makeEvent(overrides = {}) {
  const payload = overrides.payload ?? {
    weightKg: 305.5,
    weightSource: 'SCALE',
    scaleId: 'AT-2',
  };
  const now = new Date().toISOString();
  return {
    eventId: uuidv7(),
    schemaVersion: '1.0',
    eventType: 'WEIGHING',
    subjectType: 'ANIMAL',
    animalId: ANIMAL,
    subjectId: ANIMAL,
    occurredAt: now,
    recordedAt: now,
    organizationId: '22222222-2222-4222-8222-222222222222',
    actorId: '33333333-3333-4333-8333-333333333333',
    deviceId: DEVICE,
    deviceSequence: ++sequence,
    appVersion: '0.2.0',
    propertyId: '66666666-6666-4666-8666-666666666666',
    signature: 'sig-stub-dev',
    sourceSystem: 'MOBILE_OFFLINE',
    ...overrides,
    payload,
    payloadHash: overrides.payloadHash ?? payloadHash(payload),
  };
}

async function postEvent(event) {
  const res = await fetch(`${BASE}/v1/events`, {
    method: 'POST',
    headers: headers({ 'content-type': 'application/json' }),
    body: JSON.stringify(event),
  });
  return res.json();
}

before(async () => {
  await login();
  const res = await fetch(`${BASE}/v1/anchors`, {
    headers: headers(),
  }).catch(() => null);
  if (!res || !res.ok) {
    throw new Error(
      `API não respondeu em ${BASE}. Suba com: docker compose -f compose.dev.yml up -d && (cd api && npm start)`,
    );
  }
  const state = await (
    await fetch(`${BASE}/v1/devices/${DEVICE}/sync-state`, {
      headers: headers(),
    })
  ).json();
  sequence = state.lastSequence + 1000;
});

test('evento válido é aceito e persistido', async () => {
  const event = makeEvent();
  const verdict = await postEvent(event);
  assert.equal(verdict.status, 'ACCEPTED');

  const timeline = await (
    await fetch(`${BASE}/v1/animals/${ANIMAL}/timeline`, {
      headers: headers(),
    })
  ).json();
  const found = timeline.data.find((e) => e.eventId === event.eventId);
  assert.ok(found, 'evento deve aparecer na linha do tempo');
  assert.equal(found.payloadHash, event.payloadHash);
});

test('reenvio do mesmo eventId devolve o veredicto original (R22/R23)', async () => {
  const event = makeEvent();
  const first = await postEvent(event);
  const second = await postEvent(event);

  assert.equal(first.status, 'ACCEPTED');
  assert.equal(second.status, 'ACCEPTED');
  assert.equal(second.duplicate, true);

  const timeline = await (
    await fetch(`${BASE}/v1/animals/${ANIMAL}/timeline`, {
      headers: headers(),
    })
  ).json();
  const occurrences = timeline.data.filter((e) => e.eventId === event.eventId);
  assert.equal(occurrences.length, 1, 'reenvio não pode duplicar no histórico');
});

test('payload adulterado é rejeitado pelo hash', async () => {
  const event = makeEvent();
  event.payload = { ...event.payload, weightKg: 999 }; // hash agora não bate
  const verdict = await postEvent(event);

  assert.equal(verdict.status, 'REJECTED');
  assert.equal(verdict.code, 'ERR-EVT-HASH');
});

test('peso fora da faixa plausível é rejeitado', async () => {
  const payload = { weightKg: 4200, weightSource: 'MANUAL' };
  const verdict = await postEvent(makeEvent({ payload }));

  assert.equal(verdict.status, 'REJECTED');
  assert.equal(verdict.code, 'ERR-PES-001');
});

test('assinatura ausente é rejeitada antes das regras de negócio', async () => {
  const verdict = await postEvent(makeEvent({ signature: '' }));
  assert.equal(verdict.status, 'REJECTED');
  assert.equal(verdict.code, 'ERR-EVT-SIGNATURE');
});

test('evento de animal desconhecido vira conflito, não erro genérico', async () => {
  const unknown = randomUUID();
  const verdict = await postEvent(
    makeEvent({ animalId: unknown, subjectId: unknown }),
  );

  assert.equal(verdict.status, 'CONFLICT');
  assert.equal(verdict.code, 'SUBJECT_UNKNOWN');
});

test('RFID ativo em outro animal gera IDENTIFIER_TAKEN (R3)', async () => {
  const payload = { rfidCode: '982000123456789', identifierType: 'RFID' };
  const verdict = await postEvent(
    makeEvent({
      eventType: 'LINK_IDENTIFIER',
      animalId: ANIMAL_2,
      subjectId: ANIMAL_2,
      payload,
    }),
  );

  assert.equal(verdict.status, 'CONFLICT');
  assert.equal(verdict.code, 'IDENTIFIER_TAKEN');
  assert.ok(verdict.conflictId, 'conflito deve ser rastreável por id');
});

test('lote fora de ordem é processado por deviceSequence (R27)', async () => {
  const a = makeEvent();
  const b = makeEvent();
  // Envia o mais novo primeiro; o servidor precisa reordenar.
  const res = await fetch(`${BASE}/v1/sync/batches`, {
    method: 'POST',
    headers: headers({ 'content-type': 'application/json' }),
    body: JSON.stringify({
      batchId: uuidv7(),
      deviceId: DEVICE,
      clockSkewMs: 0,
      events: [b, a],
    }),
  });
  const body = await res.json();

  assert.equal(res.status, 201);
  assert.equal(body.results.length, 2);
  assert.equal(body.results[0].eventId, a.eventId, 'menor sequence primeiro');
  assert.ok(body.results.every((r) => r.status === 'ACCEPTED'));
  assert.ok(body.syncJobId);
});

test('falha de um evento não derruba o lote', async () => {
  const good = makeEvent();
  const bad = makeEvent({ payload: { weightKg: 9000, weightSource: 'MANUAL' } });

  const res = await fetch(`${BASE}/v1/sync/batches`, {
    method: 'POST',
    headers: headers({ 'content-type': 'application/json' }),
    body: JSON.stringify({
      batchId: uuidv7(),
      deviceId: DEVICE,
      events: [good, bad],
    }),
  });
  const body = await res.json();

  const goodVerdict = body.results.find((r) => r.eventId === good.eventId);
  const badVerdict = body.results.find((r) => r.eventId === bad.eventId);
  assert.equal(goodVerdict.status, 'ACCEPTED');
  assert.equal(badVerdict.status, 'REJECTED');
});

test('evento aceito é ancorado e a prova fica disponível', async () => {
  const event = makeEvent();
  await postEvent(event);

  // A ancoragem é assíncrona por definição (Doc 8 §5); o worker roda a cada 3s.
  let anchor;
  for (let i = 0; i < 15; i++) {
    const res = await fetch(`${BASE}/v1/anchors/${event.eventId}/proof`, {
      headers: headers(),
    });
    if (res.ok) {
      anchor = await res.json();
      if (anchor.status === 'CONFIRMED') break;
    }
    await new Promise((r) => setTimeout(r, 1000));
  }

  assert.ok(anchor, 'âncora deve existir para evento aceito');
  assert.equal(anchor.status, 'CONFIRMED');
  assert.equal(anchor.payloadHash, event.payloadHash);
  assert.ok(anchor.txId);
  assert.deepEqual(anchor.endorsingOrgs, [
    'OrgFundacaoMSP',
    'OrgProdutoresMSP',
  ]);
});

test('projeção de peso é recalculada pelo servidor, não informada', async () => {
  const weight = 333.7;
  const event = makeEvent({
    payload: { weightKg: weight, weightSource: 'SCALE', scaleId: 'AT-2' },
  });
  await postEvent(event);

  const animals = await (
    await fetch(
      `${BASE}/v1/animals?propertyId=66666666-6666-4666-8666-666666666666`,
      { headers: headers() },
    )
  ).json();
  const animal = animals.data.find((a) => a.animalId === ANIMAL);

  assert.equal(Number(animal.lastWeightKg), weight);
});
