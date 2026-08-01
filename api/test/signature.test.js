const { test } = require('node:test');
const assert = require('node:assert/strict');
const { generateKeyPairSync, sign } = require('node:crypto');

const {
  eventSigningInput,
  verifyEventSignature,
} = require('../dist/events/events.service.js');

function envelope() {
  return {
    eventId: '0190f6e1-7c2a-7ef0-8d15-4f3b6ad5f3c1',
    eventType: 'WEIGHING',
    subjectId: '11111111-1111-4111-8111-000000003950',
    occurredAt: '2026-07-31T21:00:00.000Z',
    deviceSequence: 42,
    payloadHash: 'a'.repeat(64),
  };
}

test('assinatura ECDSA P-256 valida a mensagem canônica do evento', () => {
  const { privateKey, publicKey } = generateKeyPairSync('ec', {
    namedCurve: 'prime256v1',
  });
  const event = envelope();
  const signature = sign(
    'sha256',
    Buffer.from(eventSigningInput(event)),
    { key: privateKey, dsaEncoding: 'der' },
  ).toString('base64url');
  const publicPem = publicKey.export({ type: 'spki', format: 'pem' });

  assert.equal(verifyEventSignature({ ...event, signature }, publicPem), true);
  assert.equal(
    verifyEventSignature({ ...event, signature: `${signature}x` }, publicPem),
    false,
  );
});
