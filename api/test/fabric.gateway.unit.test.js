const { test } = require('node:test');
const assert = require('node:assert/strict');

const { FabricGateway } = require('../dist/anchor/fabric.gateway.js');

const anchor = {
  chaincodeFn: 'RecordEvent',
  channel: 'traceagro-main',
  eventId: '018f407d-2a39-7ca4-85de-1b776d0c0f12',
  payloadHash: 'a'.repeat(64),
};

test('gateway simulado continua explícito e não exige credenciais Fabric', async () => {
  const original = process.env.FABRIC_MODE;
  process.env.FABRIC_MODE = 'simulated';
  try {
    const result = await new FabricGateway().submit(anchor);
    assert.equal(result.txId.length, 64);
    assert.ok(Number.isInteger(result.blockNumber));
  } finally {
    if (original === undefined) delete process.env.FABRIC_MODE;
    else process.env.FABRIC_MODE = original;
  }
});

test('modo real falha fechado sem configuração Fabric', async () => {
  const original = {...process.env};
  for (const key of Object.keys(process.env)) {
    if (key.startsWith('FABRIC_')) delete process.env[key];
  }
  process.env.FABRIC_MODE = 'real';
  try {
    await assert.rejects(
      () => new FabricGateway().submit(anchor),
      /FABRIC_ENDORSING_ORGS obrigatório/,
    );
  } finally {
    for (const key of Object.keys(process.env)) delete process.env[key];
    Object.assign(process.env, original);
  }
});
