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

function isEmailDeliveryConfigured() {
  return Boolean(resendApiKey && emailFrom);
}

function getBaseUrl(req) {
  if (appPublicBaseUrl) {
    return appPublicBaseUrl.replace(/\/$/, '');
  }
  return `${req.protocol}://${req.get('host')}`;
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
      subject: 'Verifica tu correo en GoBike',
      html: `
        <h2>Confirma tu correo</h2>
        <p>Para activar tu cuenta, pulsa el siguiente enlace:</p>
        <p><a href="${verificationUrl}">${verificationUrl}</a></p>
        <p>Este enlace expira en ${emailVerificationExpiryHours} hora(s).</p>
      `,
      text: `Confirma tu correo en GoBike: ${verificationUrl}\nEste enlace expira en ${emailVerificationExpiryHours} hora(s).`,
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

    const existing = await pool.query('SELECT id FROM users WHERE email = $1', [email.toLowerCase().trim()]);
    if (existing.rowCount > 0) {
      return res.status(409).json({ error: 'El email ya está registrado' });
    }

    const passwordHash = await bcrypt.hash(password, 12);
    const inserted = await pool.query(
      `
      INSERT INTO users (email, password_hash, name, phone, email_verified)
      VALUES ($1, $2, $3, $4, $5)
      RETURNING id, email, name, phone, email_verified
      `,
      [email.toLowerCase().trim(), passwordHash, String(name), String(phone), !emailVerificationRequired],
    );

    const user = inserted.rows[0];
    let verificationEmailSent = false;
    if (emailVerificationRequired) {
      verificationEmailSent = await issueVerificationEmail({
        req,
        userId: user.id,
        email: user.email,
      });
    }

    res.status(201).json({
      user: toPublicUser(user),
      email_verification_sent: verificationEmailSent,
    });
  } catch (error) {
    console.error('Signup error', error);
    res.status(500).json({ error: 'Error interno' });
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
      return res.status(400).send('Token faltante');
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
      return res.status(400).send('Token inválido');
    }

    const tokenRow = tokenResult.rows[0];
    const expired = new Date(tokenRow.expires_at).getTime() < Date.now();
    if (tokenRow.used_at || expired) {
      return res.status(400).send('Token expirado o ya utilizado');
    }

    await pool.query('UPDATE users SET email_verified = TRUE, email_verified_at = NOW(), updated_at = NOW() WHERE id = $1', [tokenRow.user_id]);
    await pool.query('UPDATE email_verification_tokens SET used_at = NOW() WHERE id = $1', [tokenRow.id]);

    res.status(200).send('Correo verificado correctamente. Ya puedes iniciar sesión.');
  } catch (error) {
    console.error('Verify email error', error);
    res.status(500).send('Error interno');
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
