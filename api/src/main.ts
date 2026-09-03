import 'reflect-metadata';
import { NestFactory } from '@nestjs/core';
import {
  FastifyAdapter,
  NestFastifyApplication,
} from '@nestjs/platform-fastify';
import { ValidationPipe, VersioningType } from '@nestjs/common';
import fastifyStatic from '@fastify/static';
import { resolve } from 'node:path';

import { AppModule } from './app.module';

async function bootstrap() {
  const app = await NestFactory.create<NestFastifyApplication>(
    AppModule,
    new FastifyAdapter(),
  );

  // Validação forte de payloads (Doc 9 §2): campos desconhecidos rejeitam.
  app.useGlobalPipes(
    new ValidationPipe({
      whitelist: true,
      forbidNonWhitelisted: true,
      transform: true,
    }),
  );

  app.enableVersioning({ type: VersioningType.URI, defaultVersion: '1' });
  // Métodos declarados explicitamente: o preflight do navegador recusava PUT
  // com a configuração padrão, e a edição de contorno de piquete falhava sem
  // chegar ao servidor.
  app.enableCors({
    methods: ['GET', 'HEAD', 'POST', 'PUT', 'PATCH', 'DELETE', 'OPTIONS'],
    allowedHeaders: ['content-type', 'authorization', 'idempotency-key'],
  });

  // Painel apenas de desenvolvimento: os dados continuam protegidos pelas
  // rotas autenticadas da API; a página não contém segredos.
  await app.register(fastifyStatic, {
    root: resolve(__dirname, '..', '..', 'blockchain', 'dashboard'),
    prefix: '/blockchain/',
  });

  // 4009 é a porta de desenvolvimento combinada do projeto: o mesmo número
  // está no default do app (`app/lib/core/services.dart`) e em
  // `config/dev.json`. Mudar aqui sem mudar lá faz o app procurar a API no
  // lugar errado — foi o que aconteceu quando havia três valores diferentes
  // espalhados. Sobrescreva com a variável PORT quando precisar de outra.
  const port = Number(process.env.PORT ?? 4009);
  await app.listen(port, '0.0.0.0');
  // eslint-disable-next-line no-console
  console.log(`TraceAgro API on :${port} (v1)`);
}

bootstrap();
