const { test } = require('node:test');
const assert = require('node:assert/strict');
const { createHash } = require('node:crypto');

const { canonicalJson, payloadHash } = require('../dist/events/canonical.js');
const { vectors } = require('./vectors.json');

test('canonicalização confere com os vetores compartilhados', () => {
  for (const v of vectors) {
    assert.equal(canonicalJson(v.value), v.canonical, v.name);
    assert.equal(payloadHash(v.value), v.sha256, `hash: ${v.name}`);
  }
});

test('ordem das chaves de entrada não muda o hash', () => {
  const a = { weightKg: 301.5, weightSource: 'SCALE', scaleId: 'AT-2' };
  const b = { scaleId: 'AT-2', weightSource: 'SCALE', weightKg: 301.5 };
  assert.equal(payloadHash(a), payloadHash(b));
});

test('undefined é omitido, null é preservado', () => {
  assert.equal(canonicalJson({ a: 1, b: undefined }), '{"a":1}');
  assert.equal(canonicalJson({ a: 1, b: null }), '{"a":1,"b":null}');
});

test('número não finito não é serializável', () => {
  assert.throws(() => canonicalJson({ x: Infinity }));
  assert.throws(() => canonicalJson({ x: NaN }));
});

test('hash é SHA-256 do UTF-8 canônico', () => {
  const payload = { note: 'vacinação' };
  const expected = createHash('sha256')
    .update(canonicalJson(payload), 'utf8')
    .digest('hex');
  assert.equal(payloadHash(payload), expected);
});
