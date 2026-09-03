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
  assert.equal(config.body.required, true);

  const anonymous = await json('/v1/anchors');
  assert.equal(anonymous.response.status, 401);

  const denied = await json('/v1/auth/dev-login', {
    method: 'POST',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify({ email: 'joao@santarita.example', password: 'errada' }),
  });
  assert.equal(denied.response.status, 401);

  const login = await json('/v1/auth/dev-login', {
    method: 'POST',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify({ email: 'joao@santarita.example', password: 'campo-joao' }),
  });
  assert.equal(login.response.status, 201, JSON.stringify(login.body));
  assert.ok(login.body.accessToken);
  assert.equal(login.body.principal.actorId, '33333333-3333-4333-8333-333333333333');
  assert.ok(login.body.principal.roles.includes('OPER'));
  assert.ok(login.body.principal.roles.includes('ADMO'));
  assert.ok(login.body.principal.permissions.includes('users.manage'));
  assert.equal(login.body.principal.propertyName, 'Fazenda Santa Rita');

  const me = await json('/v1/auth/me', {
    headers: { authorization: `Bearer ${login.body.accessToken}` },
  });
  assert.equal(me.response.status, 200);
  assert.equal(me.body.data.email, 'joao@santarita.example');
});

test('RBAC protege e aplica a gestão de usuários da organização', async () => {
  const adminLogin = await json('/v1/auth/dev-login', {
    method: 'POST',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify({ email: 'joao@santarita.example', password: 'campo-joao' }),
  });
  const adminToken = adminLogin.body.accessToken;

  const vetLogin = await json('/v1/auth/dev-login', {
    method: 'POST',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify({ email: 'carla@vet.example', password: 'campo-carla' }),
  });
  const denied = await json('/v1/admin/users', {
    headers: { authorization: `Bearer ${vetLogin.body.accessToken}` },
  });
  assert.equal(denied.response.status, 403);
  assert.equal(denied.body.code, 'ERR-AUTH-403');

  const escalation = await json('/v1/admin/users', {
    method: 'POST',
    headers: {
      'content-type': 'application/json',
      authorization: `Bearer ${adminToken}`,
    },
    body: JSON.stringify({
      name: 'Escalada bloqueada',
      email: `escalation-${Date.now()}@traceagro.test`,
      password: 'bloqueada',
      roles: ['ADMP'],
    }),
  });
  assert.equal(escalation.response.status, 403);
  assert.equal(escalation.body.code, 'ERR-AUTH-ROLE-SCOPE');

  const suffix = `${Date.now()}-${Math.floor(Math.random() * 100000)}`;
  const created = await json('/v1/admin/users', {
    method: 'POST',
    headers: {
      'content-type': 'application/json',
      authorization: `Bearer ${adminToken}`,
    },
    body: JSON.stringify({
      name: 'Pessoa E2E',
      email: `e2e-${suffix}@traceagro.test`,
      password: 'senha-e2e',
      roles: ['OPER'],
    }),
  });
  assert.equal(created.response.status, 201, JSON.stringify(created.body));
  assert.deepEqual(created.body.data.roles, ['OPER']);

  const differentPasswordDenied = await json('/v1/auth/dev-login', {
    method: 'POST',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify({
      email: `e2e-${suffix}@traceagro.test`,
      password: 'campo-joao',
    }),
  });
  assert.equal(differentPasswordDenied.response.status, 401);

  const createdLogin = await json('/v1/auth/dev-login', {
    method: 'POST',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify({
      email: `e2e-${suffix}@traceagro.test`,
      password: 'senha-e2e',
    }),
  });
  assert.equal(createdLogin.response.status, 201, JSON.stringify(createdLogin.body));

  const suspended = await json(`/v1/admin/users/${created.body.data.id}`, {
    method: 'PATCH',
    headers: {
      'content-type': 'application/json',
      authorization: `Bearer ${adminToken}`,
    },
    body: JSON.stringify({ status: 'SUSPENDED', roles: ['PROD'] }),
  });
  assert.equal(suspended.response.status, 200, JSON.stringify(suspended.body));
  assert.equal(suspended.body.data.status, 'SUSPENDED');
  assert.deepEqual(suspended.body.data.roles, ['PROD']);
});
