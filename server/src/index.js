import 'dotenv/config';
import express from 'express';
import cors from 'cors';
import Stripe from 'stripe';
import jwt from 'jsonwebtoken';
import bcrypt from 'bcryptjs';
import pg from 'pg';
import crypto from 'crypto';

const { Pool } = pg;

const databaseUrl = process.env.DATABASE_URL ?? '';
if (!databaseUrl) {
  console.error('⚠️  Define DATABASE_URL en tu archivo .env');
  process.exit(1);
}

const jwtSecret = process.env.JWT_SECRET ?? '';
if (!jwtSecret) {
  console.error('⚠️  Define JWT_SECRET en tu archivo .env');
  process.exit(1);
}

const pool = new Pool({
  connectionString: databaseUrl,
  ssl: process.env.PG_SSL === 'true' ? { rejectUnauthorized: false } : false,
});

const stripeSecretKey = process.env.STRIPE_SECRET_KEY ?? '';
const stripe = stripeSecretKey
  ? new Stripe(stripeSecretKey, {
      apiVersion: '2023-10-16',
    })
  : null;

const app = express();
app.use(cors());
app.use(express.json());

const tokenExpirySeconds = 7 * 24 * 60 * 60;
const emailVerificationExpiryHours = Number(process.env.EMAIL_VERIFICATION_TOKEN_HOURS ?? '24');
const emailVerificationRequired = (process.env.EMAIL_VERIFICATION_REQUIRED ?? 'true') === 'true';
const resendApiKey = process.env.RESEND_API_KEY ?? '';
const emailFrom = process.env.EMAIL_FROM ?? '';
const appPublicBaseUrl = process.env.APP_PUBLIC_BASE_URL ?? '';
const appAuthCallbackUrl = process.env.APP_AUTH_CALLBACK_URL ?? 'myapp://auth-callback';
const adminPanelSecret = process.env.ADMIN_PANEL_SECRET ?? '';

function normalizeConfiguredBaseUrl(rawValue) {
  const trimmed = String(rawValue ?? '').trim();
  if (!trimmed) {
    return '';
  }

  // Soporta valores pegados por error como "APP_PUBLIC_BASE_URL=https://...".
  const sanitized = trimmed.replace(/^APP_PUBLIC_BASE_URL\s*=\s*/i, '').replace(/^['"]|['"]$/g, '').trim();
  return sanitized.replace(/\/$/, '');
}

function isEmailDeliveryConfigured() {
  return Boolean(resendApiKey && emailFrom);
}

function hasValidAdminSecret(req) {
  const incoming = (req.headers['x-admin-secret'] || '').trim();
  return adminPanelSecret && incoming === adminPanelSecret;
}

async function getAuthenticatedAdmin(req, res) {
  if (hasValidAdminSecret(req)) {
    return {
      email: (process.env.ADMIN_EMAIL || '').trim().toLowerCase(),
      role: 'super_admin',
      viaSecret: true,
    };
  }

  const token = parseBearerToken(req);
  if (!token) {
    res.status(401).json({ error: 'Token faltante' });
    return null;
  }

  let userId;
  try {
    const payload = jwt.verify(token, jwtSecret);
    userId = Number(payload?.sub);
    if (!Number.isFinite(userId)) {
      res.status(401).json({ error: 'Token inválido' });
      return null;
    }
  } catch {
    res.status(401).json({ error: 'Token inválido o expirado' });
    return null;
  }

  const adminResult = await pool.query(
    `
      SELECT a.email, a.role, a.name
      FROM users u
      INNER JOIN admins a ON LOWER(a.email) = LOWER(u.email)
      WHERE u.id = $1
      LIMIT 1
    `,
    [userId],
  );

  if (adminResult.rowCount === 0) {
    res.status(403).json({ error: 'Tu usuario no tiene permisos de administrador' });
    return null;
  }

  return {
    ...adminResult.rows[0],
    viaSecret: false,
  };
}

function getBaseUrl(req) {
  const configuredBaseUrl = normalizeConfiguredBaseUrl(appPublicBaseUrl);
  if (configuredBaseUrl) {
    return configuredBaseUrl;
  }
  return `${req.protocol}://${req.get('host')}`;
}

function buildAuthCallbackUrl({ verified, reason }) {
  const normalized = String(appAuthCallbackUrl || '').trim() || 'myapp://auth-callback';

  try {
    const url = new URL(normalized);
    url.searchParams.set('type', 'signup');
    url.searchParams.set('verified', verified ? '1' : '0');
    if (reason) {
      url.searchParams.set('reason', reason);
    }
    return url.toString();
  } catch {
    const separator = normalized.includes('?') ? '&' : '?';
    const params = new URLSearchParams({
      type: 'signup',
      verified: verified ? '1' : '0',
      ...(reason ? { reason } : {}),
    });
    return `${normalized}${separator}${params.toString()}`;
  }
}

function sendVerificationRedirectPage(res, { verified, reason, message }) {
  const callbackUrl = buildAuthCallbackUrl({ verified, reason });
  const statusTitle = verified ? 'Correo verificado' : 'No se pudo verificar el correo';
  const safeMessage = message || (verified
    ? 'Tu correo fue verificado. Abre la app para iniciar sesion.'
    : 'El enlace es invalido o ya expiro. Solicita uno nuevo desde la app.');

  res
    .status(verified ? 200 : 400)
    .type('html')
    .send(`<!doctype html>
<html lang="es">
  <head>
    <meta charset="UTF-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1.0" />
    <title>${statusTitle}</title>
    <meta http-equiv="refresh" content="0;url=${callbackUrl}" />
  </head>
  <body style="font-family: Arial, sans-serif; background: #0f172a; color: #f8fafc; margin: 0;">
    <main style="max-width: 560px; margin: 48px auto; padding: 24px; background: #111827; border-radius: 12px;">
      <h1 style="margin-top: 0;">${statusTitle}</h1>
      <p>${safeMessage}</p>
      <p>Si la app no se abre automaticamente, pulsa este boton:</p>
      <p><a href="${callbackUrl}" style="display: inline-block; background: #22c55e; color: #0b1220; padding: 10px 16px; border-radius: 8px; text-decoration: none; font-weight: 700;">Volver a la app</a></p>
    </main>
  </body>
</html>`);
}

function hashToken(rawToken) {
  return crypto.createHash('sha256').update(rawToken).digest('hex');
}

function generateRawToken() {
  return crypto.randomBytes(32).toString('hex');
}

async function sendVerificationEmail({ to, verificationUrl }) {
  const response = await fetch('https://api.resend.com/emails', {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${resendApiKey}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      from: emailFrom,
      to: [to],
      subject: 'Verifica tu correo en RentalBike',
      html: `
        <div style="font-family: Arial, sans-serif; color: #111827; max-width: 560px;">
          <h2 style="margin-bottom: 8px;">Confirma tu correo</h2>
          <p style="margin-top: 0;">Para activar tu cuenta, pulsa el botón:</p>
          <p style="margin: 18px 0;">
            <a href="${verificationUrl}" style="display:inline-block;background:#1C6FFF;color:#ffffff;text-decoration:none;padding:12px 18px;border-radius:8px;font-weight:700;">Pulsa aqui para verificar</a>
          </p>
          <p>Si el botón no funciona, copia y abre este enlace:</p>
          <p><a href="${verificationUrl}">${verificationUrl}</a></p>
          <p>Este enlace expira en ${emailVerificationExpiryHours} hora(s).</p>
        </div>
      `,
      text: `Confirma tu correo en RentalBike. Pulsa aqui para verificar: ${verificationUrl}\nEste enlace expira en ${emailVerificationExpiryHours} hora(s).`,
    }),
  });

  if (!response.ok) {
    const payload = await response.text();
    throw new Error(`Resend error (${response.status}): ${payload}`);
  }
}

async function createEmailVerificationToken(userId) {
  const rawToken = generateRawToken();
  const tokenHash = hashToken(rawToken);
  const expiresAt = new Date(Date.now() + emailVerificationExpiryHours * 60 * 60 * 1000);

  await pool.query('UPDATE email_verification_tokens SET used_at = NOW() WHERE user_id = $1 AND used_at IS NULL', [userId]);
  await pool.query(
    `
      INSERT INTO email_verification_tokens (user_id, token_hash, expires_at)
      VALUES ($1, $2, $3)
    `,
    [userId, tokenHash, expiresAt],
  );

  return rawToken;
}

async function issueVerificationEmail({ req, userId, email }) {
  if (!isEmailDeliveryConfigured()) {
    return false;
  }

  const rawToken = await createEmailVerificationToken(userId);
  const verificationUrl = `${getBaseUrl(req)}/auth/v1/verify-email?token=${rawToken}`;
  await sendVerificationEmail({ to: email, verificationUrl });
  return true;
}

function requireStripe(res) {
  if (stripe) {
    return true;
  }
  res.status(503).json({ error: 'Stripe no está configurado en el backend (falta STRIPE_SECRET_KEY)' });
  return false;
}

function signAccessToken(userId) {
  return jwt.sign({ sub: userId }, jwtSecret, { expiresIn: tokenExpirySeconds });
}

function parseBearerToken(req) {
  const auth = req.headers.authorization ?? '';
  if (!auth.startsWith('Bearer ')) {
    return null;
  }
  return auth.slice('Bearer '.length).trim();
}

function getAuthenticatedUserId(req, res) {
  const token = parseBearerToken(req);
  if (!token) {
    res.status(401).json({ error: 'Token faltante' });
    return null;
  }

  try {
    const payload = jwt.verify(token, jwtSecret);
    const userId = Number(payload?.sub);
    if (!Number.isFinite(userId)) {
      res.status(401).json({ error: 'Token inválido' });
      return null;
    }
    return userId;
  } catch (error) {
    res.status(401).json({ error: 'Token inválido o expirado' });
    return null;
  }
}

async function upsertLoginReadyUserAccount(client, { email, name, password }) {
  const passwordHash = await bcrypt.hash(password, 12);
  const existingUser = await client.query(
    'SELECT id FROM users WHERE email = $1',
    [email],
  );

  if (existingUser.rowCount === 0) {
    const created = await client.query(
      `
        INSERT INTO users (
          email,
          password_hash,
          name,
          phone,
          email_verified,
          email_verified_at
        )
        VALUES ($1, $2, $3, $4, TRUE, NOW())
        RETURNING id, email, name, email_verified
      `,
      [email, passwordHash, name, ''],
    );

    return {
      created: true,
      user: created.rows[0],
    };
  }

  const updated = await client.query(
    `
      UPDATE users
      SET
        password_hash = $2,
        name = $3,
        email_verified = TRUE,
        email_verified_at = COALESCE(email_verified_at, NOW()),
        updated_at = NOW()
      WHERE email = $1
      RETURNING id, email, name, email_verified
    `,
    [email, passwordHash, name],
  );

  return {
    created: false,
    user: updated.rows[0],
  };
}

async function listWorkforceEntries(tableName) {
  const result = await pool.query(`
    SELECT
      w.email,
      w.name,
      w.created_at,
      u.id AS user_id,
      u.email_verified
    FROM ${tableName} w
    LEFT JOIN users u ON LOWER(u.email) = LOWER(w.email)
    ORDER BY w.created_at DESC
  `);

  return result.rows.map((row) => ({
    email: row.email,
    name: row.name,
    createdAt: row.created_at,
    hasLoginAccess: Boolean(row.user_id) && Boolean(row.email_verified),
  }));
}

async function ensureSchema() {
  await pool.query(`
    CREATE TABLE IF NOT EXISTS users (
      id BIGSERIAL PRIMARY KEY,
      email VARCHAR(255) NOT NULL UNIQUE,
      password_hash TEXT NOT NULL,
      name VARCHAR(120) NOT NULL DEFAULT '',
      phone VARCHAR(40) NOT NULL DEFAULT '',
      email_verified BOOLEAN NOT NULL DEFAULT FALSE,
      email_verified_at TIMESTAMPTZ,
      created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
      updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
    );
  `);
  await pool.query('ALTER TABLE users ADD COLUMN IF NOT EXISTS email_verified BOOLEAN NOT NULL DEFAULT FALSE;');
  await pool.query('ALTER TABLE users ADD COLUMN IF NOT EXISTS email_verified_at TIMESTAMPTZ;');
  await pool.query('ALTER TABLE users ADD COLUMN IF NOT EXISTS stripe_customer_id VARCHAR(120);');
  await pool.query(`
    CREATE TABLE IF NOT EXISTS email_verification_tokens (
      id BIGSERIAL PRIMARY KEY,
      user_id BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
      token_hash TEXT NOT NULL,
      expires_at TIMESTAMPTZ NOT NULL,
      used_at TIMESTAMPTZ,
      created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
    );
  `);
  await pool.query('CREATE INDEX IF NOT EXISTS idx_email_verification_user_id ON email_verification_tokens (user_id);');
  await pool.query('CREATE UNIQUE INDEX IF NOT EXISTS idx_email_verification_token_hash ON email_verification_tokens (token_hash);');
  await pool.query('CREATE INDEX IF NOT EXISTS idx_users_email ON users (email);');
  await pool.query('CREATE INDEX IF NOT EXISTS idx_users_stripe_customer_id ON users (stripe_customer_id);');
  await pool.query(`
    CREATE TABLE IF NOT EXISTS payment_methods (
      id BIGSERIAL PRIMARY KEY,
      user_id BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
      payment_method_id VARCHAR(120) NOT NULL,
      brand VARCHAR(40) NOT NULL DEFAULT 'Tarjeta',
      last4 VARCHAR(4) NOT NULL,
      expiry VARCHAR(5) NOT NULL,
      created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
      updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
      UNIQUE (user_id, payment_method_id)
    );
  `);
  await pool.query('CREATE INDEX IF NOT EXISTS idx_payment_methods_user_id ON payment_methods (user_id);');

  await pool.query(`
    CREATE TABLE IF NOT EXISTS admins (
      id BIGSERIAL PRIMARY KEY,
      email VARCHAR(255) NOT NULL UNIQUE,
      name VARCHAR(120) NOT NULL DEFAULT '',
      role VARCHAR(40) NOT NULL DEFAULT 'admin',
      created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
    );
  `);
  await pool.query('CREATE INDEX IF NOT EXISTS idx_admins_email ON admins (email);');

  await pool.query(`
    CREATE TABLE IF NOT EXISTS employee_users (
      id BIGSERIAL PRIMARY KEY,
      email VARCHAR(255) NOT NULL UNIQUE,
      name VARCHAR(120) NOT NULL DEFAULT '',
      created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
    );
  `);
  await pool.query('CREATE INDEX IF NOT EXISTS idx_employee_users_email ON employee_users (email);');

  await pool.query(`
    CREATE TABLE IF NOT EXISTS store_users (
      id BIGSERIAL PRIMARY KEY,
      email VARCHAR(255) NOT NULL UNIQUE,
      name VARCHAR(120) NOT NULL DEFAULT '',
      created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
    );
  `);
  await pool.query('CREATE INDEX IF NOT EXISTS idx_store_users_email ON store_users (email);');

  const defaultAdmin = (process.env.ADMIN_EMAIL || '').trim().toLowerCase();
  if (defaultAdmin) {
    await pool.query(
      'INSERT INTO admins (email, name, role) VALUES ($1, $2, $3) ON CONFLICT (email) DO NOTHING',
      [defaultAdmin, defaultAdmin, 'super_admin'],
    );
  }
}

function formatStripeExpiry(month, year) {
  const mm = String(month).padStart(2, '0');
  const yy = String(year).slice(-2);
  return `${mm}/${yy}`;
}

async function getOrCreateStripeCustomerForUser(userId) {
  const userResult = await pool.query(
    'SELECT id, email, name, stripe_customer_id FROM users WHERE id = $1',
    [userId],
  );
  if (userResult.rowCount === 0) {
    throw Object.assign(new Error('Usuario no encontrado'), { statusCode: 404 });
  }

  const user = userResult.rows[0];
  const customerId = String(user.stripe_customer_id ?? '').trim();
  if (customerId) {
    const customer = await stripe.customers.retrieve(customerId);
    if (!customer.deleted) {
      return customer;
    }
  }

  const created = await stripe.customers.create({
    email: user.email,
    name: user.name || undefined,
    metadata: {
      app_user_id: String(user.id),
    },
  });

  await pool.query(
    'UPDATE users SET stripe_customer_id = $1, updated_at = NOW() WHERE id = $2',
    [created.id, user.id],
  );

  return created;
}

function toPublicUser(row) {
  return {
    id: row.id,
    email: row.email,
    email_verified: Boolean(row.email_verified),
    user_metadata: {
      name: row.name ?? '',
      phone: row.phone ?? '',
    },
  };
}

app.get('/health', (req, res) => {
  res.json({ status: 'ok' });
});

app.post('/auth/v1/signup', async (req, res) => {
  try {
    if (emailVerificationRequired && !isEmailDeliveryConfigured()) {
      return res.status(503).json({
        error: 'Servicio de verificacion de correo no configurado. Define RESEND_API_KEY y EMAIL_FROM en el backend.',
      });
    }

    const { email, password, data } = req.body ?? {};
    const name = data?.name ?? '';
    const phone = data?.phone ?? '';

    if (typeof email !== 'string' || !email.includes('@')) {
      return res.status(400).json({ error: 'email inválido' });
    }
    if (typeof password !== 'string' || password.length < 6) {
      return res.status(400).json({ error: 'password inválido (mínimo 6 caracteres)' });
    }

    const normalizedEmail = email.toLowerCase().trim();
    const existing = await pool.query(
      'SELECT id, email_verified FROM users WHERE email = $1',
      [normalizedEmail],
    );
    if (existing.rowCount > 0) {
      const existingUser = existing.rows[0];
      if (emailVerificationRequired && !existingUser.email_verified) {
        // Permite reiniciar registro si la cuenta anterior nunca fue verificada.
        await pool.query('DELETE FROM users WHERE id = $1', [existingUser.id]);
      } else {
        return res.status(409).json({ error: 'El email ya está registrado' });
      }
    }

    const passwordHash = await bcrypt.hash(password, 12);
    const inserted = await pool.query(
      `
      INSERT INTO users (email, password_hash, name, phone, email_verified)
      VALUES ($1, $2, $3, $4, $5)
      RETURNING id, email, name, phone, email_verified
      `,
      [normalizedEmail, passwordHash, String(name), String(phone), !emailVerificationRequired],
    );

    const user = inserted.rows[0];
    let verificationEmailSent = false;
    if (emailVerificationRequired) {
      try {
        verificationEmailSent = await issueVerificationEmail({
          req,
          userId: user.id,
          email: user.email,
        });
      } catch (emailError) {
        // Evita usuarios bloqueados sin correo de verificacion enviado.
        await pool.query('DELETE FROM users WHERE id = $1', [user.id]);
        const message = emailError?.message ?? 'No se pudo enviar el correo de verificacion';
        return res.status(502).json({
          error: `No se pudo enviar el correo de verificacion: ${message}`,
        });
      }
    }

    res.status(201).json({
      user: toPublicUser(user),
      email_verification_sent: verificationEmailSent,
    });
  } catch (error) {
    console.error('Signup error', error);
    const message = error?.message ?? 'Error interno';
    res.status(500).json({ error: `Error interno: ${message}` });
  }
});

app.post('/auth/v1/token', async (req, res) => {
  try {
    const grantType = req.query.grant_type;
    if (grantType !== 'password') {
      return res.status(400).json({ error: 'grant_type inválido' });
    }

    const { email, password } = req.body ?? {};
    if (typeof email !== 'string' || typeof password !== 'string') {
      return res.status(400).json({ error: 'email y password son obligatorios' });
    }

    const result = await pool.query(
      'SELECT id, email, password_hash, name, phone, email_verified FROM users WHERE email = $1',
      [email.toLowerCase().trim()],
    );
    if (result.rowCount === 0) {
      return res.status(401).json({ error: 'Credenciales inválidas' });
    }

    const user = result.rows[0];
    const ok = await bcrypt.compare(password, user.password_hash);
    if (!ok) {
      return res.status(401).json({ error: 'Credenciales inválidas' });
    }
    if (emailVerificationRequired && !user.email_verified) {
      return res.status(403).json({ error: 'Debes verificar tu correo antes de iniciar sesión' });
    }

    const accessToken = signAccessToken(user.id);

    res.json({
      access_token: accessToken,
      token_type: 'bearer',
      expires_in: tokenExpirySeconds,
      user: toPublicUser(user),
    });
  } catch (error) {
    console.error('Login error', error);
    res.status(500).json({ error: 'Error interno' });
  }
});

app.get('/auth/v1/user', async (req, res) => {
  try {
    const token = parseBearerToken(req);
    if (!token) {
      return res.status(401).json({ error: 'Token faltante' });
    }

    const payload = jwt.verify(token, jwtSecret);
    const userId = Number(payload?.sub);
    if (!Number.isFinite(userId)) {
      return res.status(401).json({ error: 'Token inválido' });
    }

    const result = await pool.query(
      'SELECT id, email, name, phone, email_verified FROM users WHERE id = $1',
      [userId],
    );
    if (result.rowCount === 0) {
      return res.status(404).json({ error: 'Usuario no encontrado' });
    }

    res.json(toPublicUser(result.rows[0]));
  } catch (error) {
    console.error('Profile error', error);
    res.status(401).json({ error: 'Token inválido o expirado' });
  }
});

app.get('/payment-methods', async (req, res) => {
  const userId = getAuthenticatedUserId(req, res);
  if (userId == null) {
    return;
  }

  try {
    const result = await pool.query(
      `
        SELECT
          brand,
          last4,
          expiry,
          payment_method_id,
          (EXTRACT(EPOCH FROM created_at) * 1000)::BIGINT AS created_at_millis
        FROM payment_methods
        WHERE user_id = $1
        ORDER BY created_at DESC
      `,
      [userId],
    );

    res.json({
      cards: result.rows.map((row) => ({
        brand: row.brand,
        last4: row.last4,
        expiry: row.expiry,
        paymentMethodId: row.payment_method_id,
        createdAtMillis: Number(row.created_at_millis),
      })),
    });
  } catch (error) {
    console.error('Get payment methods error', error);
    res.status(500).json({ error: 'Error interno' });
  }
});

app.post('/payment-methods', async (req, res) => {
  const userId = getAuthenticatedUserId(req, res);
  if (userId == null) {
    return;
  }

  try {
    const brand = String(req.body?.brand ?? 'Tarjeta').trim() || 'Tarjeta';
    const last4 = String(req.body?.last4 ?? '').trim();
    const expiry = String(req.body?.expiry ?? '').trim();
    const paymentMethodId = String(req.body?.paymentMethodId ?? '').trim();

    if (!/^\d{4}$/.test(last4)) {
      return res.status(400).json({ error: 'last4 inválido' });
    }
    if (!/^(0[1-9]|1[0-2])\/\d{2}$/.test(expiry)) {
      return res.status(400).json({ error: 'expiry inválido (MM/AA)' });
    }
    if (!paymentMethodId) {
      return res.status(400).json({ error: 'paymentMethodId es obligatorio' });
    }

    const saved = await pool.query(
      `
        INSERT INTO payment_methods (user_id, payment_method_id, brand, last4, expiry, updated_at)
        VALUES ($1, $2, $3, $4, $5, NOW())
        ON CONFLICT (user_id, payment_method_id)
        DO UPDATE SET
          brand = EXCLUDED.brand,
          last4 = EXCLUDED.last4,
          expiry = EXCLUDED.expiry,
          updated_at = NOW()
        RETURNING
          brand,
          last4,
          expiry,
          payment_method_id,
          (EXTRACT(EPOCH FROM created_at) * 1000)::BIGINT AS created_at_millis
      `,
      [userId, paymentMethodId, brand, last4, expiry],
    );

    const row = saved.rows[0];
    res.status(201).json({
      card: {
        brand: row.brand,
        last4: row.last4,
        expiry: row.expiry,
        paymentMethodId: row.payment_method_id,
        createdAtMillis: Number(row.created_at_millis),
      },
    });
  } catch (error) {
    console.error('Save payment method error', error);
    res.status(500).json({ error: 'Error interno' });
  }
});

app.post('/payment-methods/setup-intent', async (req, res) => {
  const userId = getAuthenticatedUserId(req, res);
  if (userId == null) {
    return;
  }

  try {
    if (!requireStripe(res)) {
      return;
    }

    const customer = await getOrCreateStripeCustomerForUser(userId);

    const ephemeralKey = await stripe.ephemeralKeys.create(
      { customer: customer.id },
      { apiVersion: '2023-10-16' },
    );

    const setupIntent = await stripe.setupIntents.create({
      customer: customer.id,
      payment_method_types: ['card'],
      usage: 'off_session',
      metadata: {
        app_user_id: String(userId),
      },
    });

    return res.status(200).json({
      setupIntentClientSecret: setupIntent.client_secret,
      customer: customer.id,
      ephemeralKey: ephemeralKey.secret,
    });
  } catch (error) {
    console.error('Create payment method setup-intent error', error);
    const status = error.statusCode ?? 500;
    const message = error.message ?? 'Error interno';
    return res.status(status).json({ error: message });
  }
});

app.post('/payment-methods/sync-stripe', async (req, res) => {
  const userId = getAuthenticatedUserId(req, res);
  if (userId == null) {
    return;
  }

  try {
    if (!requireStripe(res)) {
      return;
    }

    const customer = await getOrCreateStripeCustomerForUser(userId);

    const methods = await stripe.paymentMethods.list({
      customer: customer.id,
      type: 'card',
      limit: 100,
    });

    for (const method of methods.data) {
      const card = method.card;
      if (!card || !card.last4 || !card.exp_month || !card.exp_year) {
        continue;
      }

      const brand = (card.brand || 'card').toUpperCase();
      const expiry = formatStripeExpiry(card.exp_month, card.exp_year);

      await pool.query(
        `
          INSERT INTO payment_methods (user_id, payment_method_id, brand, last4, expiry, updated_at)
          VALUES ($1, $2, $3, $4, $5, NOW())
          ON CONFLICT (user_id, payment_method_id)
          DO UPDATE SET
            brand = EXCLUDED.brand,
            last4 = EXCLUDED.last4,
            expiry = EXCLUDED.expiry,
            updated_at = NOW()
        `,
        [userId, method.id, brand, card.last4, expiry],
      );
    }

    if (methods.data.length > 0) {
      const keepIds = methods.data.map((m) => m.id);
      await pool.query(
        'DELETE FROM payment_methods WHERE user_id = $1 AND payment_method_id <> ALL($2::text[])',
        [userId, keepIds],
      );
    } else {
      await pool.query('DELETE FROM payment_methods WHERE user_id = $1', [userId]);
    }

    const result = await pool.query(
      `
        SELECT
          brand,
          last4,
          expiry,
          payment_method_id,
          (EXTRACT(EPOCH FROM created_at) * 1000)::BIGINT AS created_at_millis
        FROM payment_methods
        WHERE user_id = $1
        ORDER BY created_at DESC
      `,
      [userId],
    );

    return res.status(200).json({
      cards: result.rows.map((row) => ({
        brand: row.brand,
        last4: row.last4,
        expiry: row.expiry,
        paymentMethodId: row.payment_method_id,
        createdAtMillis: Number(row.created_at_millis),
      })),
    });
  } catch (error) {
    console.error('Sync stripe payment methods error', error);
    const status = error.statusCode ?? 500;
    const message = error.message ?? 'Error interno';
    return res.status(status).json({ error: message });
  }
});

app.delete('/payment-methods/:paymentMethodId', async (req, res) => {
  const userId = getAuthenticatedUserId(req, res);
  if (userId == null) {
    return;
  }

  try {
    const paymentMethodId = String(req.params.paymentMethodId ?? '').trim();
    if (!paymentMethodId) {
      return res.status(400).json({ error: 'paymentMethodId inválido' });
    }

    await pool.query(
      'DELETE FROM payment_methods WHERE user_id = $1 AND payment_method_id = $2',
      [userId, paymentMethodId],
    );

    res.status(204).send();
  } catch (error) {
    console.error('Delete payment method error', error);
    res.status(500).json({ error: 'Error interno' });
  }
});

app.get('/auth/v1/verify-email', async (req, res) => {
  try {
    const rawToken = String(req.query.token ?? '');
    if (!rawToken) {
      return sendVerificationRedirectPage(res, {
        verified: false,
        reason: 'missing_token',
        message: 'Falta el token de verificacion. Solicita un nuevo correo desde la app.',
      });
    }

    const tokenHash = hashToken(rawToken);
    const tokenResult = await pool.query(
      `
        SELECT id, user_id, expires_at, used_at
        FROM email_verification_tokens
        WHERE token_hash = $1
      `,
      [tokenHash],
    );
    if (tokenResult.rowCount === 0) {
      return sendVerificationRedirectPage(res, {
        verified: false,
        reason: 'invalid_token',
        message: 'El enlace de verificacion no es valido. Solicita uno nuevo desde la app.',
      });
    }

    const tokenRow = tokenResult.rows[0];
    const expired = new Date(tokenRow.expires_at).getTime() < Date.now();
    if (tokenRow.used_at || expired) {
      return sendVerificationRedirectPage(res, {
        verified: false,
        reason: tokenRow.used_at ? 'already_used' : 'expired',
        message: 'El enlace ya fue usado o expiro. Solicita un nuevo correo desde la app.',
      });
    }

    await pool.query('UPDATE users SET email_verified = TRUE, email_verified_at = NOW(), updated_at = NOW() WHERE id = $1', [tokenRow.user_id]);
    await pool.query('UPDATE email_verification_tokens SET used_at = NOW() WHERE id = $1', [tokenRow.id]);

    return sendVerificationRedirectPage(res, {
      verified: true,
      reason: 'ok',
      message: 'Correo verificado correctamente. Te redirigimos a la app para iniciar sesion.',
    });
  } catch (error) {
    console.error('Verify email error', error);
    return sendVerificationRedirectPage(res, {
      verified: false,
      reason: 'server_error',
      message: 'Error interno verificando el correo. Intenta de nuevo en unos minutos.',
    });
  }
});

app.post('/auth/v1/resend-verification', async (req, res) => {
  try {
    const email = String(req.body?.email ?? '').toLowerCase().trim();
    if (!email || !email.includes('@')) {
      return res.status(400).json({ error: 'email inválido' });
    }
    if (!emailVerificationRequired) {
      return res.status(200).json({ message: 'La verificación de correo no está activada' });
    }
    if (!isEmailDeliveryConfigured()) {
      return res.status(503).json({ error: 'Servicio de correo no configurado' });
    }

    const userResult = await pool.query(
      'SELECT id, email, email_verified FROM users WHERE email = $1',
      [email],
    );

    if (userResult.rowCount === 0) {
      return res.status(200).json({ message: 'Si el correo existe, se enviará un nuevo enlace' });
    }

    const user = userResult.rows[0];
    if (user.email_verified) {
      return res.status(200).json({ message: 'Tu correo ya está verificado' });
    }

    await issueVerificationEmail({ req, userId: user.id, email: user.email });
    return res.status(200).json({ message: 'Correo de verificación reenviado' });
  } catch (error) {
    console.error('Resend verification error', error);
    return res.status(500).json({ error: 'Error interno' });
  }
});

app.post('/create-payment-intent', async (req, res) => {
  try {
    if (!requireStripe(res)) {
      return;
    }
    const {
      amount,
      currency,
      description,
      customerId,
    } = req.body ?? {};

    if (typeof amount !== 'number' || amount <= 0) {
      return res.status(400).json({ error: 'amount debe ser un número en céntimos mayor que 0' });
    }
    if (typeof currency !== 'string' || currency.length !== 3) {
      return res.status(400).json({ error: 'currency debe ser un código ISO de 3 letras (por ejemplo, eur)' });
    }

    const customer = customerId
      ? await stripe.customers.retrieve(customerId)
      : await stripe.customers.create();

    if (customer.deleted) {
      return res.status(400).json({ error: 'El customer indicado está eliminado' });
    }

    const ephemeralKey = await stripe.ephemeralKeys.create(
      { customer: customer.id },
      { apiVersion: '2023-10-16' },
    );

    const paymentIntent = await stripe.paymentIntents.create({
      amount,
      currency,
      customer: customer.id,
      description,
      automatic_payment_methods: {
        enabled: true,
      },
    });

    res.json({
      paymentIntentClientSecret: paymentIntent.client_secret,
      ephemeralKey: ephemeralKey.secret,
      customer: customer.id,
    });
  } catch (error) {
    console.error('Stripe error', error);
    const status = error.statusCode ?? 500;
    const message = error.message ?? 'Error interno';
    res.status(status).json({ error: message });
  }
});

app.post('/create-setup-intent', async (req, res) => {
  try {
    if (!requireStripe(res)) {
      return;
    }
    const { customerId } = req.body ?? {};

    const customer = customerId
      ? await stripe.customers.retrieve(customerId)
      : await stripe.customers.create();

    if (customer.deleted) {
      return res.status(400).json({ error: 'El customer indicado está eliminado' });
    }

    const setupIntent = await stripe.setupIntents.create({
      customer: customer.id,
      payment_method_types: ['card'],
      usage: 'off_session',
    });

    res.json({
      setupIntentClientSecret: setupIntent.client_secret,
      customer: customer.id,
    });
  } catch (error) {
    console.error('Stripe setup intent error', error);
    const status = error.statusCode ?? 500;
    const message = error.message ?? 'Error interno';
    res.status(status).json({ error: message });
  }
});

app.post('/create-subscription', async (req, res) => {
  try {
    if (!requireStripe(res)) {
      return;
    }
    const {
      priceId,
      customerId,
      description,
    } = req.body ?? {};

    if (typeof priceId !== 'string' || !priceId.startsWith('price_')) {
      return res.status(400).json({ error: 'priceId inválido. Debe comenzar por price_' });
    }

    const customer = customerId
      ? await stripe.customers.retrieve(customerId)
      : await stripe.customers.create();

    if (customer.deleted) {
      return res.status(400).json({ error: 'El customer indicado está eliminado' });
    }

    const ephemeralKey = await stripe.ephemeralKeys.create(
      { customer: customer.id },
      { apiVersion: '2023-10-16' },
    );

    const subscription = await stripe.subscriptions.create({
      customer: customer.id,
      items: [{ price: priceId }],
      payment_behavior: 'default_incomplete',
      payment_settings: {
        save_default_payment_method: 'on_subscription',
      },
      metadata: description
        ? { description }
        : undefined,
      expand: ['latest_invoice.payment_intent'],
    });

    const paymentIntent = subscription.latest_invoice?.payment_intent;
    const clientSecret = paymentIntent?.client_secret;

    if (!clientSecret) {
      return res.status(500).json({ error: 'No se pudo obtener client secret de la suscripción' });
    }

    res.json({
      paymentIntentClientSecret: clientSecret,
      ephemeralKey: ephemeralKey.secret,
      customer: customer.id,
      subscriptionId: subscription.id,
      status: subscription.status,
      currentPeriodEnd: subscription.current_period_end,
      interval: subscription.items.data[0]?.price?.recurring?.interval ?? null,
      unitAmount: subscription.items.data[0]?.price?.unit_amount ?? null,
      currency: subscription.items.data[0]?.price?.currency ?? null,
    });
  } catch (error) {
    console.error('Stripe subscription error', error);
    const status = error.statusCode ?? 500;
    const message = error.message ?? 'Error interno';
    res.status(status).json({ error: message });
  }
});

app.get('/subscription/:subscriptionId', async (req, res) => {
  try {
    if (!requireStripe(res)) {
      return;
    }
    const { subscriptionId } = req.params;
    if (!subscriptionId?.startsWith('sub_')) {
      return res.status(400).json({ error: 'subscriptionId inválido. Debe comenzar por sub_' });
    }

    const subscription = await stripe.subscriptions.retrieve(subscriptionId, {
      expand: ['items.data.price'],
    });

    res.json({
      id: subscription.id,
      status: subscription.status,
      customer: subscription.customer,
      currentPeriodStart: subscription.current_period_start,
      currentPeriodEnd: subscription.current_period_end,
      cancelAtPeriodEnd: subscription.cancel_at_period_end,
      canceledAt: subscription.canceled_at,
      priceId: subscription.items.data[0]?.price?.id ?? null,
      interval: subscription.items.data[0]?.price?.recurring?.interval ?? null,
      unitAmount: subscription.items.data[0]?.price?.unit_amount ?? null,
      currency: subscription.items.data[0]?.price?.currency ?? null,
    });
  } catch (error) {
    console.error('Stripe get subscription error', error);
    const status = error.statusCode ?? 500;
    const message = error.message ?? 'Error interno';
    res.status(status).json({ error: message });
  }
});

app.post('/cancel-subscription', async (req, res) => {
  try {
    if (!requireStripe(res)) {
      return;
    }
    const { subscriptionId } = req.body ?? {};
    if (typeof subscriptionId !== 'string' || !subscriptionId.startsWith('sub_')) {
      return res.status(400).json({ error: 'subscriptionId inválido. Debe comenzar por sub_' });
    }

    const updated = await stripe.subscriptions.update(subscriptionId, {
      cancel_at_period_end: true,
    });

    res.json({
      id: updated.id,
      status: updated.status,
      cancelAtPeriodEnd: updated.cancel_at_period_end,
      currentPeriodEnd: updated.current_period_end,
    });
  } catch (error) {
    console.error('Stripe cancel subscription error', error);
    const status = error.statusCode ?? 500;
    const message = error.message ?? 'Error interno';
    res.status(status).json({ error: message });
  }
});

// --- Admin management persistente en BD. Protegido por sesión admin o X-Admin-Secret ---
app.get('/admin/me', async (req, res) => {
  try {
    const admin = await getAuthenticatedAdmin(req, res);
    if (!admin) {
      return;
    }

    return res.json({
      admin: {
        email: admin.email,
        role: admin.role,
        viaSecret: admin.viaSecret,
      },
    });
  } catch (error) {
    console.error('Admin me error', error);
    return res.status(500).json({ error: 'Error interno' });
  }
});

app.get('/admin/users', async (req, res) => {
  try {
    const admin = await getAuthenticatedAdmin(req, res);
    if (!admin) {
      return;
    }

    const result = await pool.query(`
      SELECT
        a.email,
        a.name,
        a.role,
        a.created_at,
        u.id AS user_id,
        u.email_verified
      FROM admins a
      LEFT JOIN users u ON LOWER(u.email) = LOWER(a.email)
      ORDER BY a.created_at DESC
    `);
    const list = result.rows.map((r) => ({
      email: r.email,
      name: r.name,
      role: r.role,
      createdAt: r.created_at,
      hasLoginAccess: Boolean(r.user_id) && Boolean(r.email_verified),
    }));
    return res.json({ admins: list });
  } catch (error) {
    console.error('List admins error', error);
    return res.status(500).json({ error: 'Error interno' });
  }
});

app.post('/admin/users', async (req, res) => {
  try {
    const admin = await getAuthenticatedAdmin(req, res);
    if (!admin) {
      return;
    }

    const email = String(req.body?.email ?? '').trim().toLowerCase();
    const name = String(req.body?.name ?? '').trim();
    const password = String(req.body?.password ?? '');
    const role = 'admin';
    if (!email || !email.includes('@')) {
      return res.status(400).json({ error: 'Email inválido' });
    }
    if (!name) {
      return res.status(400).json({ error: 'Nombre obligatorio' });
    }
    if (password.length < 6) {
      return res.status(400).json({ error: 'La contraseña debe tener al menos 6 caracteres' });
    }

    const client = await pool.connect();
    try {
      await client.query('BEGIN');

      const adminResult = await client.query(
        `
          INSERT INTO admins (email, name, role)
          VALUES ($1, $2, $3)
          ON CONFLICT (email)
          DO UPDATE SET name = EXCLUDED.name
          RETURNING email, name, role, created_at
        `,
        [email, name, role],
      );

      const account = await upsertLoginReadyUserAccount(client, {
        email,
        name,
        password,
      });

      await client.query('COMMIT');

      return res.status(201).json({
        email: adminResult.rows[0].email,
        name: adminResult.rows[0].name,
        role: adminResult.rows[0].role,
        createdAt: adminResult.rows[0].created_at,
        hasLoginAccess: true,
        accountCreated: account.created,
      });
    } catch (error) {
      await client.query('ROLLBACK');
      throw error;
    } finally {
      client.release();
    }
  } catch (error) {
    console.error('Create admin error', error);
    return res.status(500).json({ error: 'Error interno' });
  }
});

app.get('/admin/workforce/employees', async (req, res) => {
  try {
    const admin = await getAuthenticatedAdmin(req, res);
    if (!admin) {
      return;
    }

    const employees = await listWorkforceEntries('employee_users');
    return res.json({ employees });
  } catch (error) {
    console.error('List employee users error', error);
    return res.status(500).json({ error: 'Error interno' });
  }
});

app.post('/admin/workforce/employees', async (req, res) => {
  try {
    const admin = await getAuthenticatedAdmin(req, res);
    if (!admin) {
      return;
    }

    const email = String(req.body?.email ?? '').trim().toLowerCase();
    const name = String(req.body?.name ?? '').trim();
    const password = String(req.body?.password ?? '');
    if (!email || !email.includes('@')) {
      return res.status(400).json({ error: 'Email inválido' });
    }
    if (!name) {
      return res.status(400).json({ error: 'Nombre obligatorio' });
    }
    if (password.length < 6) {
      return res.status(400).json({ error: 'La contraseña debe tener al menos 6 caracteres' });
    }

    const client = await pool.connect();
    try {
      await client.query('BEGIN');
      const workforceResult = await client.query(
        `
          INSERT INTO employee_users (email, name)
          VALUES ($1, $2)
          ON CONFLICT (email)
          DO UPDATE SET name = EXCLUDED.name
          RETURNING email, name, created_at
        `,
        [email, name],
      );

      await upsertLoginReadyUserAccount(client, { email, name, password });
      await client.query('COMMIT');

      return res.status(201).json({
        email: workforceResult.rows[0].email,
        name: workforceResult.rows[0].name,
        createdAt: workforceResult.rows[0].created_at,
        hasLoginAccess: true,
      });
    } catch (error) {
      await client.query('ROLLBACK');
      throw error;
    } finally {
      client.release();
    }
  } catch (error) {
    console.error('Create employee user error', error);
    return res.status(500).json({ error: 'Error interno' });
  }
});

app.delete('/admin/workforce/employees/:email', async (req, res) => {
  try {
    const admin = await getAuthenticatedAdmin(req, res);
    if (!admin) {
      return;
    }

    const email = String(req.params.email ?? '').trim().toLowerCase();
    if (!email || !email.includes('@')) {
      return res.status(400).json({ error: 'Email inválido' });
    }

    const client = await pool.connect();
    try {
      await client.query('BEGIN');
      const existing = await client.query('SELECT id FROM employee_users WHERE email = $1 LIMIT 1', [email]);
      if (existing.rowCount === 0) {
        await client.query('ROLLBACK');
        return res.status(404).json({ error: 'Empleado no encontrado' });
      }

      await client.query('DELETE FROM users WHERE email = $1', [email]);
      await client.query('DELETE FROM employee_users WHERE email = $1', [email]);
      await client.query('COMMIT');
      return res.status(204).send();
    } catch (error) {
      await client.query('ROLLBACK');
      throw error;
    } finally {
      client.release();
    }
  } catch (error) {
    console.error('Delete employee user error', error);
    return res.status(500).json({ error: 'Error interno' });
  }
});

app.get('/admin/workforce/store-users', async (req, res) => {
  try {
    const admin = await getAuthenticatedAdmin(req, res);
    if (!admin) {
      return;
    }

    const storeUsers = await listWorkforceEntries('store_users');
    return res.json({ storeUsers });
  } catch (error) {
    console.error('List store users error', error);
    return res.status(500).json({ error: 'Error interno' });
  }
});

app.post('/admin/workforce/store-users', async (req, res) => {
  try {
    const admin = await getAuthenticatedAdmin(req, res);
    if (!admin) {
      return;
    }

    const email = String(req.body?.email ?? '').trim().toLowerCase();
    const name = String(req.body?.name ?? '').trim();
    const password = String(req.body?.password ?? '');
    if (!email || !email.includes('@')) {
      return res.status(400).json({ error: 'Email inválido' });
    }
    if (!name) {
      return res.status(400).json({ error: 'Nombre obligatorio' });
    }
    if (password.length < 6) {
      return res.status(400).json({ error: 'La contraseña debe tener al menos 6 caracteres' });
    }

    const client = await pool.connect();
    try {
      await client.query('BEGIN');
      const workforceResult = await client.query(
        `
          INSERT INTO store_users (email, name)
          VALUES ($1, $2)
          ON CONFLICT (email)
          DO UPDATE SET name = EXCLUDED.name
          RETURNING email, name, created_at
        `,
        [email, name],
      );

      await upsertLoginReadyUserAccount(client, { email, name, password });
      await client.query('COMMIT');

      return res.status(201).json({
        email: workforceResult.rows[0].email,
        name: workforceResult.rows[0].name,
        createdAt: workforceResult.rows[0].created_at,
        hasLoginAccess: true,
      });
    } catch (error) {
      await client.query('ROLLBACK');
      throw error;
    } finally {
      client.release();
    }
  } catch (error) {
    console.error('Create store user error', error);
    return res.status(500).json({ error: 'Error interno' });
  }
});

app.delete('/admin/workforce/store-users/:email', async (req, res) => {
  try {
    const admin = await getAuthenticatedAdmin(req, res);
    if (!admin) {
      return;
    }

    const email = String(req.params.email ?? '').trim().toLowerCase();
    if (!email || !email.includes('@')) {
      return res.status(400).json({ error: 'Email inválido' });
    }

    const client = await pool.connect();
    try {
      await client.query('BEGIN');
      const existing = await client.query('SELECT id FROM store_users WHERE email = $1 LIMIT 1', [email]);
      if (existing.rowCount === 0) {
        await client.query('ROLLBACK');
        return res.status(404).json({ error: 'Usuario de tienda no encontrado' });
      }

      await client.query('DELETE FROM users WHERE email = $1', [email]);
      await client.query('DELETE FROM store_users WHERE email = $1', [email]);
      await client.query('COMMIT');
      return res.status(204).send();
    } catch (error) {
      await client.query('ROLLBACK');
      throw error;
    } finally {
      client.release();
    }
  } catch (error) {
    console.error('Delete store user error', error);
    return res.status(500).json({ error: 'Error interno' });
  }
});

app.delete('/admin/users/:email', async (req, res) => {
  try {
    const admin = await getAuthenticatedAdmin(req, res);
    if (!admin) {
      return;
    }

    const email = String(req.params.email ?? '').trim().toLowerCase();
    if (!email || !email.includes('@')) {
      return res.status(400).json({ error: 'Email inválido' });
    }

    const existing = await pool.query(
      'SELECT email, role FROM admins WHERE email = $1 LIMIT 1',
      [email],
    );

    if (existing.rowCount === 0) {
      return res.status(404).json({ error: 'Administrador no encontrado' });
    }

    const target = existing.rows[0];
    if (target.role !== 'admin') {
      return res.status(403).json({ error: 'Solo se pueden eliminar administradores normales' });
    }

    const client = await pool.connect();
    try {
      await client.query('BEGIN');
      await client.query('DELETE FROM users WHERE email = $1', [email]);
      await client.query('DELETE FROM admins WHERE email = $1', [email]);
      await client.query('COMMIT');
      return res.status(204).send();
    } catch (error) {
      await client.query('ROLLBACK');
      throw error;
    } finally {
      client.release();
    }
  } catch (error) {
    console.error('Delete admin error', error);
    return res.status(500).json({ error: 'Error interno' });
  }
});

const port = process.env.PORT ?? 4242;
ensureSchema()
  .then(() => {
    if (emailVerificationRequired && !isEmailDeliveryConfigured()) {
      console.warn('⚠️  Verificación por correo obligatoria sin proveedor configurado (RESEND_API_KEY/EMAIL_FROM).');
      console.warn('⚠️  El backend inicia, pero /auth/v1/signup responderá 503 hasta configurar correo.');
    }

    app.listen(port, () => {
      console.log(`✅ Backend escuchando en http://localhost:${port}`);
      console.log('✅ Auth PostgreSQL activa en /auth/v1/*');
      if (!stripe) {
        console.log('⚠️  Stripe desactivado (falta STRIPE_SECRET_KEY)');
      }
    });
  })
  .catch((error) => {
    console.error('❌ No se pudo inicializar PostgreSQL', error);
    process.exit(1);
  });
