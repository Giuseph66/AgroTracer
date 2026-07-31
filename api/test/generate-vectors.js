#!/usr/bin/env node
// Regenera test/vectors.json a partir da implementação TypeScript.
// Rode depois de `npm run build`. Os testes Dart e TS leem o resultado, então
// mudar a canonicalização exige regenerar aqui e ver os dois lados passarem.
const { createHash } = require('node:crypto');
const { writeFileSync } = require('node:fs');
const { join } = require('node:path');
const { canonicalJson } = require('../dist/events/canonical.js');

const inputs = [
  { name: 'objeto simples com chaves fora de ordem', value: { b: 2, a: 1 } },
  {
    name: 'payload de pesagem',
    value: { weightKg: 301.5, weightSource: 'SCALE', scaleId: 'AT-2' },
  },
  {
    name: 'inteiro em ponto flutuante sai sem casa decimal',
    value: { weightKg: 300.0 },
  },
  {
    name: 'aninhamento com lista',
    value: { animals: ['4127', '4088'], lot: { name: 'Recria 12', id: 3 } },
  },
  {
    name: 'null explícito é conteúdo',
    value: { correctionOf: null, reason: 'erro de digitação' },
  },
  { name: 'acentos em UTF-8', value: { note: 'vacinação aplicada às 14h' } },
  {
    name: 'payload de vacinação completo',
    value: {
      productRef: 'AFTOSA-BIV',
      dosage: '5ml',
      route: 'SC',
      batchNumber: 'L2291',
      withdrawalUntil: '2026-08-21T00:00:00.000Z',
    },
  },
];

const vectors = inputs.map((v) => {
  const canonical = canonicalJson(v.value);
  return {
    name: v.name,
    value: v.value,
    canonical,
    sha256: createHash('sha256').update(canonical, 'utf8').digest('hex'),
  };
});

writeFileSync(
  join(__dirname, 'vectors.json'),
  JSON.stringify(
    {
      _comment:
        'Vetores compartilhados de canonicalização (RFC 8785 simplificado). ' +
        'Consumidos por api/test/canonical.test.ts e app/test/canonical_test.dart. ' +
        'Se um lado divergir, todo evento vindo do app é rejeitado com ERR-EVT-HASH — ' +
        'por isso os dois leem exatamente este arquivo. Gerado por api/test/generate-vectors.js.',
      vectors,
    },
    null,
    2,
  ) + '\n',
);

console.log(`${vectors.length} vetores gravados em test/vectors.json`);
