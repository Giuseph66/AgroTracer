import { Injectable, Logger } from '@nestjs/common';
import { createHash, randomBytes } from 'node:crypto';

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

/**
 * Porta de saída para a rede Fabric (Doc 10 §3).
 *
 * A implementação real usa `@hyperledger/fabric-gateway` com a identidade de
 * serviço `svc-api@OrgFundacaoMSP` e submete o registro-âncora do Doc 11 §2 —
 * nunca o payload. Este stub simula latência e sucesso para que o restante do
 * pipeline (estados, retry, projeção de prova) seja construído e testado antes
 * da rede existir; trocar a implementação não muda nada acima dele.
 */
@Injectable()
export class FabricGateway {
  private readonly log = new Logger(FabricGateway.name);

  readonly simulated = process.env.FABRIC_MODE !== 'real';

  async submit(req: AnchorRequest): Promise<AnchorResult> {
    if (!this.simulated) {
      // TODO(F4): conectar no Gateway do peer, montar proposta, coletar
      // endosso conforme a política do tipo de evento e submeter ao ordering.
      throw new Error('FABRIC_MODE=real ainda não implementado');
    }

    await delay(120 + Math.floor(Math.random() * 200));

    // TxID simulado deriva do hash — determinístico o bastante para depurar,
    // com sufixo aleatório para não parecer um TxID real de rede.
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

function delay(ms: number) {
  return new Promise((r) => setTimeout(r, ms));
}
