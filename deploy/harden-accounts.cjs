// Tarefa de execução única, rodada com a imagem da API:
//
//   docker compose -f compose.app.yml --profile harden run --rm harden-accounts
//
// As migrações 009 e 010 semeiam contas de laboratório com senha conhecida —
// inclusive uma com papel ADMO. Enquanto a API só ouvia em localhost isso era
// dado de teste; atrás de um túnel Cloudflare é uma conta administrativa com
// senha pública. Este script:
//
//   1. define a senha real da conta administrativa (ADMIN_BOOTSTRAP_*);
//   2. invalida o login de toda conta que ainda carregue um dos hashes
//      semeados — comparação pelo hash exato, sem adivinhar por e-mail.
//
// verifyPassword() devolve false para hash em formato desconhecido (não lança),
// então 'disabled' bloqueia o login sem quebrar a rota de autenticação.

const { Pool } = require('/app/node_modules/pg');
const { hashPassword } = require('/app/dist/auth/password.js');

// Hashes literais da migração 010_user_passwords.sql.
const SEEDED_HASHES = [
  'scrypt$16384$8$1$p535Rkz_ckX4iIKflw11UA$W53vU8V7Sk7KsysXyIdSPoXynUaSGsCLC-jZIlPHobuvx7tUYAjPXGJPJ_ESg7oOqRerhZyRW5ulogs0HS0rOA',
  'scrypt$16384$8$1$rBc6BfpOCYuTx_yqJHspYw$v9gKgABlpNSB_dCPujMBuSwtJQ5Esv2JBrajlQZLf53vywv_5lLt_uD5DnANXSZz2zAbJlhLtpsAty72qh1JkA',
  'scrypt$16384$8$1$nx3KDm7tn9BTMp3NSYuwjQ$17nYPc7EG0D10t5Xlc9Ah7k-lMZ6F0qRywA_npPb4-NGyG3htbizRm3HK-2XpjINmgRshXSTZlqWiYjRhL__zw',
  'scrypt$16384$8$1$nNmCpCpMjNV_pRIchuzpGg$YLTjh01iTkHmYy84iL5yr-UciNIb-hc_3luhJs-6rlKt_OyuL2mK89fzGu2SruADGEq1yHkOhqnz26dTisRIow',
];

const email = process.env.ADMIN_BOOTSTRAP_EMAIL;
const password = process.env.ADMIN_BOOTSTRAP_PASSWORD;

if (!email || !password) {
  console.error('defina ADMIN_BOOTSTRAP_EMAIL e ADMIN_BOOTSTRAP_PASSWORD no deploy/.env');
  process.exit(1);
}
if (password.length < 12) {
  console.error('ADMIN_BOOTSTRAP_PASSWORD com menos de 12 caracteres; recuse');
  process.exit(1);
}

async function main() {
  const pool = new Pool({
    host: process.env.PGHOST,
    port: Number(process.env.PGPORT ?? 5432),
    user: process.env.PGUSER,
    password: process.env.PGPASSWORD,
    database: process.env.PGDATABASE,
  });

  const client = await pool.connect();
  try {
    await client.query('BEGIN');

    const admin = await client.query(
      `UPDATE core.app_user SET password_hash = $2
        WHERE lower(email) = lower($1)
        RETURNING id, name, email`,
      [email, hashPassword(password)],
    );
    if (admin.rowCount !== 1) {
      throw new Error(`conta ${email} não encontrada em core.app_user`);
    }

    const disabled = await client.query(
      `UPDATE core.app_user SET password_hash = 'disabled'
        WHERE password_hash = ANY($1::text[])
          AND lower(email) <> lower($2)
        RETURNING email`,
      [SEEDED_HASHES, email],
    );

    // Sem papel ativo a conta autentica e não faz nada; melhor avisar agora.
    const roles = await client.query(
      `SELECT role_code FROM core.user_role_binding
        WHERE user_id = $1 AND valid_from <= now()
          AND (valid_to IS NULL OR valid_to > now())`,
      [admin.rows[0].id],
    );

    await client.query('COMMIT');

    console.log(`senha definida: ${admin.rows[0].email} (${admin.rows[0].name})`);
    console.log(`papéis ativos: ${roles.rows.map((r) => r.role_code).join(', ') || 'NENHUM'}`);
    console.log(`logins de laboratório invalidados: ${disabled.rowCount}`);
    for (const row of disabled.rows) console.log(`  - ${row.email ?? '(sem e-mail)'}`);
  } catch (err) {
    await client.query('ROLLBACK');
    throw err;
  } finally {
    client.release();
    await pool.end();
  }
}

main().catch((err) => {
  console.error(err.message);
  process.exit(1);
});
