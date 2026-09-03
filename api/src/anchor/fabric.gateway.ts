import { Injectable, Logger, OnModuleDestroy } from '@nestjs/common';
import * as grpc from '@grpc/grpc-js';
import {
  connect,
  hash,
  signers,
  type Gateway,
} from '@hyperledger/fabric-gateway';
import { createHash, createPrivateKey, randomBytes } from 'node:crypto';
import { readFile } from 'node:fs/promises';

export type AnchorRequest = {
  chaincodeFn: string;
  channel: string;
  eventId: string;
  payloadHash: string;
};

export type AnchorResult = {
  txId: string;
  blockNumber: number;
  endorsingOrgs: string[];
};

type FabricConfig = {
  endpoint: string;
  tlsServerName: string;
  mspId: string;
  channel: string;
  chaincode: string;
  clientCertPath: string;
  clientKeyPath: string;
  tlsRootCertPath: string;
  endorsingOrgs: string[];
  timeoutMs: number;
};

type FabricConnection = {
  gateway: Gateway;
  client: grpc.Client;
  config: FabricConfig;
};

type AnchorReceipt = {
  eventId?: unknown;
  payloadHash?: unknown;
};

/**
 * Porta de saída para a rede Fabric (Doc 10 §3).
 *
 * Em modo real usa certificado X.509, chave privada e TLS para submeter somente
 * o registro-âncora do Doc 11 §2 — nunca o payload completo.
 */
@Injectable()
export class FabricGateway implements OnModuleDestroy {
  private readonly log = new Logger(FabricGateway.name);
  private connection?: Promise<FabricConnection>;

  readonly simulated = process.env.FABRIC_MODE !== 'real';

  async submit(req: AnchorRequest): Promise<AnchorResult> {
    if (this.simulated) return this.submitSimulated(req);

    const { gateway, config } = await this.realConnection();
    if (req.channel !== config.channel) {
      throw new Error(
        `canal da âncora (${req.channel}) diverge de FABRIC_CHANNEL (${config.channel})`,
      );
    }

    const contract = gateway
      .getNetwork(config.channel)
      .getContract(config.chaincode);
    const submitted = await contract.submitAsync(req.chaincodeFn, {
      arguments: [req.eventId, req.payloadHash],
    });
    const status = await submitted.getStatus();
    if (!status.successful) {
      throw new Error(
        `commit Fabric inválido: tx=${status.transactionId} code=${status.code}`,
      );
    }

    const receipt = readReceipt(submitted.getResult());
    if (
      receipt.eventId !== req.eventId ||
      receipt.payloadHash !== req.payloadHash
    ) {
      throw new Error('recibo Fabric não corresponde à âncora enviada');
    }

    const blockNumber = Number(status.blockNumber);
    if (!Number.isSafeInteger(blockNumber)) {
      throw new Error(`bloco Fabric excede inteiro seguro: ${status.blockNumber}`);
    }

    this.log.debug(
      `âncora Fabric ${req.chaincodeFn} tx=${status.transactionId.slice(0, 12)}…`,
    );
    return {
      txId: status.transactionId,
      blockNumber,
      // O Gateway satisfaz a política no peer. Esta lista documenta a política
      // configurada; auditoria profunda consulta o bloco/assinaturas do canal.
      endorsingOrgs: config.endorsingOrgs,
    };
  }

  async onModuleDestroy(): Promise<void> {
    if (!this.connection) return;
    try {
      const { gateway, client } = await this.connection;
      gateway.close();
      client.close();
    } catch (error) {
      this.log.warn(`fechar Gateway Fabric: ${(error as Error).message}`);
    }
  }

  private async realConnection(): Promise<FabricConnection> {
    if (!this.connection) {
      this.connection = this.openRealConnection().catch((error: unknown) => {
        this.connection = undefined;
        throw error;
      });
    }
    return this.connection;
  }

  private async openRealConnection(): Promise<FabricConnection> {
    const config = fabricConfigFromEnv();
    const [credentials, privateKeyPem, tlsRootCert] = await Promise.all([
      readFile(config.clientCertPath),
      readFile(config.clientKeyPath),
      readFile(config.tlsRootCertPath),
    ]);
    const client = new grpc.Client(
      config.endpoint,
      grpc.credentials.createSsl(tlsRootCert),
      {'grpc.ssl_target_name_override': config.tlsServerName},
    );
    const gateway = connect({
      client,
      identity: {mspId: config.mspId, credentials},
      signer: signers.newPrivateKeySigner(createPrivateKey(privateKeyPem)),
      hash: hash.sha256,
      endorseOptions: () => ({deadline: Date.now() + config.timeoutMs}),
      submitOptions: () => ({deadline: Date.now() + config.timeoutMs}),
      commitStatusOptions: () => ({deadline: Date.now() + config.timeoutMs}),
    });

    this.log.log(
      `Gateway Fabric conectado: ${config.endpoint} channel=${config.channel}`,
    );
    return {gateway, client, config};
  }

  private async submitSimulated(req: AnchorRequest): Promise<AnchorResult> {

    await delay(120 + Math.floor(Math.random() * 200));

    // Modo explícito de laboratório sem rede Fabric.
    const txId = createHash('sha256')
      .update(`${req.eventId}:${req.payloadHash}`)
      .digest('hex');

    this.log.debug(`âncora simulada ${req.chaincodeFn} tx=${txId.slice(0, 12)}…`);

    return {
      txId,
      blockNumber: Number(BigInt('0x' + randomBytes(3).toString('hex')) % 100000n),
      endorsingOrgs: ['OrgFundacaoMSP', 'OrgProdutoresMSP'],
    };
  }
}

function fabricConfigFromEnv(): FabricConfig {
  const timeoutMs = Number(process.env.FABRIC_TIMEOUT_MS ?? '15000');
  if (!Number.isInteger(timeoutMs) || timeoutMs <= 0) {
    throw new Error('FABRIC_TIMEOUT_MS deve ser inteiro positivo');
  }
  const endorsingOrgs = requireEnv('FABRIC_ENDORSING_ORGS')
    .split(',')
    .map((org) => org.trim())
    .filter(Boolean);
  if (endorsingOrgs.length === 0) {
    throw new Error('FABRIC_ENDORSING_ORGS sem organizações');
  }

  return {
    endpoint: requireEnv('FABRIC_ENDPOINT'),
    tlsServerName: requireEnv('FABRIC_TLS_SERVER_NAME'),
    mspId: requireEnv('FABRIC_MSP_ID'),
    channel: requireEnv('FABRIC_CHANNEL'),
    chaincode: requireEnv('FABRIC_CHAINCODE'),
    clientCertPath: requireEnv('FABRIC_CLIENT_CERT_PATH'),
    clientKeyPath: requireEnv('FABRIC_CLIENT_KEY_PATH'),
    tlsRootCertPath: requireEnv('FABRIC_TLS_ROOT_CERT_PATH'),
    endorsingOrgs,
    timeoutMs,
  };
}

function requireEnv(name: string): string {
  const value = process.env[name]?.trim();
  if (!value) throw new Error(`${name} obrigatório em FABRIC_MODE=real`);
  return value;
}

function readReceipt(bytes: Uint8Array): Required<AnchorReceipt> {
  let decoded: AnchorReceipt;
  try {
    decoded = JSON.parse(new TextDecoder().decode(bytes)) as AnchorReceipt;
  } catch {
    throw new Error('recibo Fabric inválido');
  }
  if (typeof decoded.eventId !== 'string' || typeof decoded.payloadHash !== 'string') {
    throw new Error('recibo Fabric sem eventId ou payloadHash');
  }
  return {eventId: decoded.eventId, payloadHash: decoded.payloadHash};
}

function delay(ms: number) {
  return new Promise((r) => setTimeout(r, ms));
}
