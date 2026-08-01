const { test } = require('node:test');
const assert = require('node:assert/strict');

const BASE = process.env.TRACEAGRO_API ?? 'http://localhost:3999';

async function json(path, options) {
  const response = await fetch(`${BASE}${path}`, options);
  return { response, body: await response.json() };
}

test('sessão local devolve identidade e roles do usuário', async () => {
  const config = await json('/v1/auth/config');
  assert.equal(config.response.status, 200);
  assert.equal(config.body.mode, 'dev');

  const denied = await json('/v1/auth/dev-login', {
    method: 'POST',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify({ email: 'joao@santarita.example', password: 'errada' }),
  });
  assert.equal(denied.response.status, 401);

  const login = await json('/v1/auth/dev-login', {
    method: 'POST',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify({ email: 'joao@santarita.example', password: 'campo' }),
  });
  assert.equal(login.response.status, 201, JSON.stringify(login.body));
  assert.ok(login.body.accessToken);
  assert.equal(login.body.principal.actorId, '33333333-3333-4333-8333-333333333333');
  assert.ok(login.body.principal.roles.includes('OPER'));
  assert.equal(login.body.principal.propertyName, 'Fazenda Santa Rita');

  const me = await json('/v1/auth/me', {
    headers: { authorization: `Bearer ${login.body.accessToken}` },
  });
  assert.equal(me.response.status, 200);
  assert.equal(me.body.data.email, 'joao@santarita.example');
});
