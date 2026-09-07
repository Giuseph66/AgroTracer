# Deploy do TraceAgro em servidor com Cloudflare

Sobe a API, o Postgres e a emulação Fabric numa máquina que só tem Docker, e
publica a API pela internet por um túnel Cloudflare — sem abrir porta nenhuma no
firewall da máquina.

São dois planos, um arquivo Compose para cada:

| Arquivo | Plano | O que roda |
|---------|-------|------------|
| `compose.app.yml` | aplicação | `postgres` (PostGIS com o schema na imagem), `api` (NestJS), `cloudflared`, e a tarefa `harden-accounts` |
| `compose.fabric.yml` | emulação Fabric | tarefas de execução única que dirigem a `test-network` do fabric-samples |

Por que a emulação não declara os peers aqui: quem cria orderer, peers, CAs e
CouchDB é o `network.sh` do fabric-samples, com os compose files oficiais do
Hyperledger, chamado por `blockchain/scripts/up.sh`. Copiar aquela topologia
para dentro deste diretório criaria uma segunda verdade sobre versões, material
criptográfico e ciclo de vida do chaincode — e as duas divergiriam no primeiro
upgrade. O que `compose.fabric.yml` entrega é o **plano de controle**: um
container de ferramentas com bash, curl, jq, CLI do Docker e os binários do
Fabric, para que a máquina servidora precise mesmo só de Docker.

## Antes de começar

Na máquina servidora:

- Docker Engine com o plugin Compose v2 (`docker compose version` ≥ 2.24 — o
  `env_file` com `required: false` depende disso);
- o repositório clonado num caminho absoluto estável (ex.: `/opt/traceagro`);
- saída para a internet (o bootstrap do Fabric baixa binários e imagens; o
  cloudflared abre o túnel de dentro para fora).

Não é preciso Node, Go, `psql` nem binários do Fabric no host: tudo vem em
imagem.

No Cloudflare, antes do primeiro `up`:

1. Zero Trust → Networks → Tunnels → **Create a tunnel** (tipo *Cloudflared*).
2. Copie o **token** do túnel para `CLOUDFLARE_TUNNEL_TOKEN` no `.env`.
3. Em **Public Hostnames**, aponte `api.seudominio.com` para
   `http://api:4009` — `api` é o nome do serviço na rede do Compose, é assim
   que o cloudflared o alcança.

## Subir

```bash
cd deploy
cp .env.example .env
$EDITOR .env                 # REPO_DIR, senhas, AUTH_JWT_SECRET, token do túnel

docker compose -f compose.app.yml up -d --build
```

O primeiro boot do Postgres roda `api/db/migrations/001..010` e, depois delas,
`db/zz-app-role-password.sh`, que troca a senha do papel `traceagro_app` pela do
`.env`.

**Passo obrigatório antes de expor**: as migrações 009/010 semeiam contas de
laboratório com senha conhecida — inclusive uma com papel `ADMO`, cuja senha
(`campo123`) está escrita no repositório. Rode:

```bash
docker compose -f compose.app.yml --profile harden run --rm harden-accounts
```

Isso define a senha real de `ADMIN_BOOTSTRAP_EMAIL` e invalida o login de toda
conta que ainda carregue um dos hashes semeados. Ele identifica as contas pelo
hash exato, não por e-mail, e imprime quais desativou.

Confira e só então deixe o túnel encaminhar tráfego:

```bash
docker compose -f compose.app.yml ps
docker compose -f compose.app.yml logs -f api
curl https://api.seudominio.com/v1/auth/config
```

## Subir a emulação Fabric

```bash
docker compose -f compose.fabric.yml run --rm fabric-up      # ~5-10 min no 1º
docker compose -f compose.fabric.yml run --rm fabric-status
docker compose -f compose.fabric.yml run --rm fabric-env     # gera fabric.env
docker compose -f compose.app.yml up -d api                  # recarrega a API
```

`fabric-env` escreve `deploy/fabric.env` com `FABRIC_MODE=real` e os caminhos da
identidade `User1@org1` **como o container da API os enxerga**
(`/fabric/organizations/...`). Esse arquivo entra como `env_file` depois do
`.env`, então sobrepõe o `FABRIC_MODE=simulated` de lá. Repita `fabric-env`
sempre que o `fabric-up` recriar a rede: o nome do arquivo da chave é aleatório.

A API alcança o peer por `host.docker.internal:7051` — a porta que a
test-network publica no host — em vez de entrar na rede `fabric_test`. Assim os
dois projetos Compose sobem e descem sem depender um do outro; o certificado do
peer continua sendo validado contra `FABRIC_TLS_SERVER_NAME`.

Para derrubar a rede e apagar seus volumes:

```bash
docker compose -f compose.fabric.yml run --rm fabric-down
```

## Apontar o app para o servidor

O endereço da API é gravado no binário do Flutter em tempo de compilação
(`String.fromEnvironment`) — trocar de servidor exige recompilar:

```bash
cd app
flutter build apk --dart-define=TRACEAGRO_API=https://api.seudominio.com
```

Ou edite `config/dev.json` e use `--dart-define-from-file=../config/dev.json`.

## Segurança

O que este deploy já resolve:

- nenhuma porta publicada no host — o Postgres não é alcançável nem pela rede
  local, e a API só pelo cloudflared;
- senha do papel de banco vinda do ambiente, não do SQL versionado;
- contas de laboratório invalidadas pelo perfil `harden`;
- imagem da API rodando como usuário sem privilégio (`node`).

O que **você** ainda precisa decidir, porque o padrão do código é de laboratório:

- **Painel `/blockchain/`** — a API o serve como estático e ele fica público no
  hostname do túnel. Ele autentica pela própria API, mas é superfície a mais.
  Proteja com Cloudflare Access (Zero Trust → Access → Applications) na rota
  `api.seudominio.com/blockchain/*`, ou remova o `fastifyStatic` de `main.ts`
  para este ambiente.
- **CORS** — `main.ts` habilita CORS sem restringir origem. Com o app em
  navegador isso permite que qualquer página chame a API com token roubado.
  Restrinja a origem em produção.
- **`AUTH_MODE=dev`** valida senha individual guardada no Postgres. É o
  suficiente para piloto; o Doc 13 prevê Keycloak/OIDC — troque para `oidc` e
  preencha `OIDC_ISSUER`/`OIDC_JWKS_URL` quando ele existir.
- **`EVENT_SIGNATURE_MODE=legacy`** aceita as fixtures de desenvolvimento. Vire
  para `ecdsa` assim que o app assinar com o Keystore.
- **Rate limit e WAF** — a API não tem limitação de taxa própria. Configure
  regras no Cloudflare, sobretudo em `/v1/auth/dev-login`.
- **Socket do Docker** — `compose.fabric.yml` monta `/var/run/docker.sock` e
  roda em rede do host. Quem escreve nesse socket é equivalente a root na
  máquina. É aceitável num servidor de laboratório sob seu controle; não use
  este arquivo em máquina compartilhada com terceiros.

## Operação

**Logs e estado**

```bash
docker compose -f compose.app.yml logs -f api cloudflared
docker compose -f compose.app.yml ps
```

**Backup do banco** (o volume é `traceagro-app_pgdata`):

```bash
docker compose -f compose.app.yml exec -T postgres \
  pg_dump -U traceagro traceagro | gzip > backup-$(date +%F).sql.gz
```

**Atualizar a API**

```bash
git pull
docker compose -f compose.app.yml up -d --build api
```

**Migrações novas**: as migrações entram na imagem do Postgres por COPY, e o
`/docker-entrypoint-initdb.d` só roda com o volume vazio. Uma migração
`011_*.sql` criada depois do primeiro boot **não** é aplicada por um `up`, nem
por um rebuild — ela só valeria num banco novo. Aplique à mão no banco existente:

```bash
docker compose -f compose.app.yml exec -T postgres \
  psql -v ON_ERROR_STOP=1 -U traceagro -d traceagro < ../api/db/migrations/011_x.sql
```

e reconstrua a imagem (`up -d --build postgres`) para que um banco criado do
zero no futuro já nasça com ela.

## Limites conhecidos

- O `healthcheck` da API bate em `/v1/auth/config`, que não toca no banco: a API
  aparece `healthy` mesmo com o Postgres recusando conexão. Os erros aparecem em
  `logs api`.
- A rede Fabric aqui é a `test-network` de desenvolvimento do fabric-samples
  (Doc 14 §1), com material criptográfico gerado localmente. Não é a rede dos
  parceiros e não substitui as credenciais deles.
- Uma réplica de API só. O `AnchorWorker` já usa `SKIP LOCKED` e aguenta várias
  réplicas, mas o Compose aqui não as declara.
- `blockchain/.runtime/` é escrito pelo container de ferramentas, que roda como
  root. Faça a manutenção dessa pasta pelos serviços de `compose.fabric.yml`
  (`fabric-down`, `fabric-shell`), não à mão.
- Subir a stack de aplicação antes da Fabric faz o Docker criar
  `blockchain/.runtime/.../test-network/organizations` vazio, por causa do bind
  mount da identidade. Isso é esperado e o `bootstrap.sh` lida com ele; se você
  já tiver um `.runtime` pela metade de uma tentativa antiga, apague a pasta e
  rode `fabric-up` de novo.
