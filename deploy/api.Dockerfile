# syntax=docker/dockerfile:1.7
#
# Imagem da API TraceAgro (NestJS + Fastify).
#
# O contexto de build é a RAIZ do repositório, não api/: além do código da API,
# a imagem precisa de blockchain/dashboard, que main.ts serve em /blockchain/.
#
#   docker build -f deploy/api.Dockerfile -t traceagro/api:local .

# ------------------------------------------------------------------ build
FROM node:22-bookworm-slim AS build
WORKDIR /app
COPY api/package.json api/package-lock.json ./
RUN npm ci
COPY api/tsconfig.json ./
COPY api/src ./src
RUN npm run build

# --------------------------------------------------- dependências de runtime
FROM node:22-bookworm-slim AS deps
WORKDIR /app
COPY api/package.json api/package-lock.json ./
RUN npm ci --omit=dev

# ---------------------------------------------------------------- runtime
FROM node:22-bookworm-slim AS runtime
ENV NODE_ENV=production
WORKDIR /app

COPY --from=deps  /app/node_modules ./node_modules
COPY --from=build /app/dist         ./dist
COPY api/package.json ./package.json

# main.ts resolve o painel em resolve(__dirname, '..', '..', 'blockchain',
# 'dashboard'). Com dist em /app/dist isso aponta para /blockchain/dashboard —
# por isso o caminho absoluto aqui, e não um diretório dentro de /app.
COPY blockchain/dashboard /blockchain/dashboard

USER node
EXPOSE 4009

# Não existe rota /health; GET /v1/auth/config é público (é a primeira chamada
# do app) e exercita o processo inteiro sem exigir token.
HEALTHCHECK --interval=15s --timeout=5s --start-period=20s --retries=5 \
  CMD node -e "fetch('http://127.0.0.1:'+(process.env.PORT||4009)+'/v1/auth/config').then(r=>process.exit(r.ok?0:1)).catch(()=>process.exit(1))"

# npm start usa --env-file-if-exists=.env; no container a configuração vem do
# ambiente do Compose, então chamamos o node direto (um processo a menos).
CMD ["node", "dist/main.js"]
