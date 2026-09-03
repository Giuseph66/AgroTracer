const { test, before } = require('node:test');
const assert = require('node:assert/strict');
const { v7: uuidv7 } = require('uuid');

const { payloadHash } = require('../dist/events/canonical.js');

const BASE = process.env.TRACEAGRO_API ?? 'http://localhost:3999';
const PROPERTY = '66666666-6666-4666-8666-666666666666';
const DEVICE = '44444444-4444-4444-8444-444444444444';
const ORG = '22222222-2222-4222-8222-222222222222';
const ACTOR = '33333333-3333-4333-8333-333333333333';
const VET = '33333333-3333-4333-8333-000000000002';
let sequence = 0;
let token;
let vetToken;

function event(overrides = {}) {
  const payload = overrides.payload ?? {};
  const now = new Date().toISOString();
  return {
    eventId: uuidv7(),
    schemaVersion: '1.0',
    eventType: 'WEIGHING',
    subjectType: 'ANIMAL',
    subjectId: overrides.animalId ?? uuidv7(),
    occurredAt: now,
    recordedAt: now,
    organizationId: ORG,
    actorId: ACTOR,
    deviceId: DEVICE,
    deviceSequence: ++sequence,
    appVersion: '0.3.0',
    propertyId: PROPERTY,
    signature: 'sig-stub-dev',
    sourceSystem: 'MOBILE_OFFLINE',
    ...overrides,
    payload,
    payloadHash: payloadHash(payload),
  };
}

async function login(email) {
  const password = email === 'carla@vet.example' ? 'campo-carla' : 'campo-joao';
  const response = await fetch(`${BASE}/v1/auth/dev-login`, {
    method: 'POST',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify({ email, password }),
  });
  assert.equal(response.status, 201);
  return (await response.json()).accessToken;
}

async function json(path, options = {}, accessToken = token) {
  const response = await fetch(`${BASE}${path}`, {
    ...options,
    headers: {
      ...options.headers,
      authorization: `Bearer ${accessToken}`,
    },
  });
  return { response, body: await response.json() };
}

before(async () => {
  token = await login('joao@santarita.example');
  vetToken = await login('carla@vet.example');
  const response = await json('/v1/anchors');
  assert.equal(response.response.ok, true);
  const state = await json(`/v1/devices/${DEVICE}/sync-state`);
  sequence = state.body.lastSequence + 1000;
});

test('catálogo veterinário e criação de piquete', async () => {
  const catalog = await json('/v1/catalog/vet-products');
  assert.equal(catalog.response.status, 200);
  assert.ok(catalog.body.data.some((item) => item.code === 'IVERMECTINA-1'));

  const paddock = await json(`/v1/properties/${PROPERTY}/paddocks`, {
    method: 'POST',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify({
      name: `Piquete teste ${uuidv7()}`,
      points: [
        { x: -49.32, y: -17.88 },
        { x: -49.31, y: -17.88 },
        { x: -49.31, y: -17.89 },
        { x: -49.32, y: -17.89 },
      ],
    }),
  });
  assert.equal(paddock.response.status, 201);
  assert.ok(paddock.body.areaHa > 0);
});

test('registro de animal e vacinação derivam carência do catálogo', async () => {
  const animalId = uuidv7();
  const register = event({
    eventType: 'REGISTER_ANIMAL',
    subjectId: animalId,
    animalId,
    payload: {
      speciesCode: 'BOVINE',
      sex: 'F',
      birthType: 'BORN_ON_PROPERTY',
      birthDate: '2026-01-01',
      breedCode: 'NELORE',
    },
  });
  const created = await json('/v1/events', {
    method: 'POST',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify(register),
  });
  assert.equal(created.body.status, 'ACCEPTED', JSON.stringify(created.body));

  const vaccination = event({
    eventType: 'VACCINATION',
    subjectId: animalId,
    animalId,
    payload: {
      productRef: 'IVERMECTINA-1',
      dosage: '1ml',
      route: 'SC',
      batchNumber: 'TEST-1',
    },
  });
  const accepted = await json('/v1/events', {
    method: 'POST',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify(vaccination),
  });
  assert.equal(accepted.body.status, 'ACCEPTED');

  const animals = await json(`/v1/animals?propertyId=${PROPERTY}`);
  const found = animals.body.data.find((item) => item.animalId === animalId);
  assert.ok(found);
  assert.equal(found.lifecycleStatus, 'ACTIVE');
  assert.ok(new Date(found.withdrawalUntil) > new Date());
});

test('embarque fecha ciclo de expedição, GTA e recebimento', async () => {
  const animalId = uuidv7();
  const register = event({
    eventType: 'REGISTER_ANIMAL',
    subjectId: animalId,
    animalId,
    payload: {
      sex: 'M',
      birthType: 'PURCHASED',
      birthDate: '2022-01-01',
      breedCode: 'NELORE',
    },
  });
  const created = await json('/v1/events', {
    method: 'POST',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify(register),
  });
  assert.equal(created.body.status, 'ACCEPTED', JSON.stringify(created.body));

  const shipmentId = uuidv7();
  const dispatched = await json('/v1/events', {
    method: 'POST',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify(event({
      eventType: 'SHIPMENT_DISPATCHED',
      subjectType: 'SHIPMENT',
      subjectId: shipmentId,
      payload: {
        shipmentId,
        animalIds: [animalId],
        destinationPropertyId: PROPERTY,
        purpose: 'VENDA',
      },
    })),
  });
  assert.equal(dispatched.body.status, 'ACCEPTED', JSON.stringify(dispatched.body));

  const gta = await json('/v1/events', {
    method: 'POST',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify(event({
      eventType: 'GTA_REGISTERED',
      subjectType: 'SHIPMENT',
      subjectId: shipmentId,
      payload: { shipmentId, gtaNumber: '123456', gtaUf: 'MT' },
    })),
  });
  assert.equal(gta.body.status, 'ACCEPTED', JSON.stringify(gta.body));

  const received = await json('/v1/events', {
    method: 'POST',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify(event({
      eventType: 'SHIPMENT_RECEIVED',
      subjectType: 'SHIPMENT',
      subjectId: shipmentId,
      payload: { shipmentId, readAnimalIds: [animalId] },
    })),
  });
  assert.equal(received.body.status, 'ACCEPTED', JSON.stringify(received.body));

  const detail = await json(`/v1/shipments/${shipmentId}`);
  assert.equal(detail.response.status, 200);
  assert.equal(detail.body.status, 'RECEIVED');
  assert.equal(detail.body.gtaNumber, '123456');
  assert.equal(detail.body.animals[0].received, true);

  const missing = await json(`/v1/shipments/${uuidv7()}`);
  assert.equal(missing.response.status, 404);

  const partialAnimalIds = [uuidv7(), uuidv7()];
  for (const partialAnimalId of partialAnimalIds) {
    const partialRegister = await json('/v1/events', {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify(event({
        eventType: 'REGISTER_ANIMAL',
        subjectId: partialAnimalId,
        animalId: partialAnimalId,
        payload: { sex: 'F', birthType: 'PURCHASED', breedCode: 'NELORE' },
      })),
    });
    assert.equal(partialRegister.body.status, 'ACCEPTED', JSON.stringify(partialRegister.body));
  }
  const partialShipmentId = uuidv7();
  const partialDispatch = await json('/v1/events', {
    method: 'POST',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify(event({
      eventType: 'SHIPMENT_DISPATCHED',
      subjectType: 'SHIPMENT',
      subjectId: partialShipmentId,
      payload: {
        shipmentId: partialShipmentId,
        animalIds: partialAnimalIds,
        destinationPropertyId: PROPERTY,
        purpose: 'VENDA',
      },
    })),
  });
  assert.equal(partialDispatch.body.status, 'ACCEPTED', JSON.stringify(partialDispatch.body));

  const partialReceived = await json('/v1/events', {
    method: 'POST',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify(event({
      eventType: 'SHIPMENT_RECEIVED',
      subjectType: 'SHIPMENT',
      subjectId: partialShipmentId,
      payload: { shipmentId: partialShipmentId, readAnimalIds: [partialAnimalIds[0]] },
    })),
  });
  assert.equal(partialReceived.body.status, 'ACCEPTED', JSON.stringify(partialReceived.body));

  const partialDetail = await json(`/v1/shipments/${partialShipmentId}`);
  assert.equal(partialDetail.body.status, 'RECEIVED_WITH_DISCREPANCY');
  assert.equal(partialDetail.body.animals.find((animal) => animal.animalId === partialAnimalIds[1]).discrepancy, 'MISSING');
});

test('ato sanitário privativo exige VETE vigente', async () => {
  const animalId = '11111111-1111-4111-8111-000000004088';
  const denied = await json('/v1/events', {
    method: 'POST',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify(event({
      eventType: 'DIAGNOSIS',
      actorId: ACTOR,
      animalId,
      subjectId: animalId,
      payload: { diagnosis: 'observação de teste' },
    })),
  });
  assert.equal(denied.body.status, 'REJECTED');
  assert.equal(denied.body.code, 'ERR-SAN-001');

  const accepted = await json('/v1/events', {
    method: 'POST',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify(event({
      eventType: 'DIAGNOSIS',
      actorId: VET,
      animalId,
      subjectId: animalId,
      payload: { diagnosis: 'observação veterinária de teste' },
    })),
  }, vetToken);
  assert.equal(accepted.body.status, 'ACCEPTED', JSON.stringify(accepted.body));
});
