import {
  randomBytes,
  scryptSync,
  timingSafeEqual,
} from 'node:crypto';

const KEY_LENGTH = 64;
const SCRYPT_OPTIONS = { N: 16384, r: 8, p: 1, maxmem: 32 * 1024 * 1024 };

export function hashPassword(password: string): string {
  const salt = randomBytes(16);
  const key = scryptSync(password, salt, KEY_LENGTH, SCRYPT_OPTIONS);
  return [
    'scrypt',
    SCRYPT_OPTIONS.N,
    SCRYPT_OPTIONS.r,
    SCRYPT_OPTIONS.p,
    salt.toString('base64url'),
    key.toString('base64url'),
  ].join('$');
}

export function verifyPassword(password: string, encoded: string): boolean {
  const [algorithm, n, r, p, saltText, keyText] = encoded.split('$');
  if (algorithm !== 'scrypt' || !n || !r || !p || !saltText || !keyText) {
    return false;
  }

  try {
    const salt = Buffer.from(saltText, 'base64url');
    const expected = Buffer.from(keyText, 'base64url');
    const actual = scryptSync(password, salt, expected.length, {
      N: Number(n),
      r: Number(r),
      p: Number(p),
      maxmem: 32 * 1024 * 1024,
    });
    return actual.length === expected.length && timingSafeEqual(actual, expected);
  } catch {
    return false;
  }
}
