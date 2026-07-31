import { createHash } from 'node:crypto';

/**
 * Serialização canônica JCS (RFC 8785), simplificada para os tipos usados nos
 * payloads: objetos com chaves ordenadas por code unit, sem espaços, strings
 * em JSON escape padrão, números normalizados.
 *
 * A mesma rotina existe em Dart no app (`lib/core/sync/canonical.dart`).
 * Vetores de teste compartilhados garantem que os dois produzam o mesmo hash —
 * se divergirem, todo evento do app é rejeitado por hash, então isso é
 * verificado em teste, não por inspeção.
 */
export function canonicalJson(value: unknown): string {
  if (value === null) return 'null';

  if (Array.isArray(value)) {
    return `[${value.map(canonicalJson).join(',')}]`;
  }

  if (typeof value === 'object') {
    const entries = Object.entries(value as Record<string, unknown>)
      .filter(([, v]) => v !== undefined)
      .sort(([a], [b]) => (a < b ? -1 : a > b ? 1 : 0))
      .map(([k, v]) => `${JSON.stringify(k)}:${canonicalJson(v)}`);
    return `{${entries.join(',')}}`;
  }

  if (typeof value === 'number') {
    if (!Number.isFinite(value)) {
      throw new Error('canonicalJson: número não finito não é serializável');
    }
    // JSON.stringify já emite a forma mais curta que faz round-trip (ES2020+),
    // que é o que o JCS exige para números.
    return JSON.stringify(value);
  }

  return JSON.stringify(value);
}

export function payloadHash(payload: unknown): string {
  return createHash('sha256').update(canonicalJson(payload), 'utf8').digest('hex');
}
