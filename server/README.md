# Backend GoBike (Stripe + Auth PostgreSQL)

Servidor Node.js que mantiene endpoints de Stripe y ahora agrega autenticacion con PostgreSQL en rutas compatibles con la app: `/auth/v1/signup`, `/auth/v1/token`, `/auth/v1/user`.

## Configuración

1. Copia el archivo `.env.example` a `.env`.
   ```bash
   cp .env.example .env
  # Edita .env para fijar DATABASE_URL, JWT_SECRET y opcionalmente STRIPE_SECRET_KEY
   ```
2. Crea la tabla de usuarios en PostgreSQL:
  ```sql
  -- Puedes ejecutar server/sql/init.sql
  CREATE TABLE IF NOT EXISTS users (
    id BIGSERIAL PRIMARY KEY,
    email VARCHAR(255) NOT NULL UNIQUE,
    password_hash TEXT NOT NULL,
    name VARCHAR(120) NOT NULL DEFAULT '',
    phone VARCHAR(40) NOT NULL DEFAULT '',
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
  );
  ```
3. Instala las dependencias:
   ```bash
   npm install
   ```
4. Arranca el servidor en modo desarrollo:
   ```bash
   npm run dev
   ```
   Por defecto escucha en `http://localhost:4242`.

## Endpoints de autenticacion (PostgreSQL)

- `POST /auth/v1/signup`
- `POST /auth/v1/token?grant_type=password`
- `GET /auth/v1/user`
- `GET /auth/v1/verify-email?token=...`
- `POST /auth/v1/resend-verification`

La app Flutter (`lib/services/user_service.dart`) usa estas rutas sin cambiar la logica de login/registro.

## Verificacion por correo (obligatoria)

Debes configurar verificacion de correo con Resend en `.env`:

```env
EMAIL_VERIFICATION_REQUIRED=true
RESEND_API_KEY=re_xxx
EMAIL_FROM=GoBike <onboarding@resend.dev>
APP_PUBLIC_BASE_URL=http://localhost:4242
EMAIL_VERIFICATION_TOKEN_HOURS=24
```

La API no arrancará si falta `RESEND_API_KEY` o `EMAIL_FROM`, porque la verificación por correo es obligatoria.

## Endpoint

`POST /create-payment-intent`

Cuerpo JSON:
```json
{
  "amount": 25300,
  "currency": "eur",
  "description": "Alquiler Fatbike"
}
```

Respuesta JSON:
```json
{
  "paymentIntentClientSecret": "pi_..._secret_...",
  "ephemeralKey": "ek_test_...",
  "customer": "cus_..."
}
```

`POST /create-subscription`

Cuerpo JSON:
```json
{
  "priceId": "price_1234",
  "description": "Suscripción mensual Plan mensual"
}
```

Respuesta JSON:
```json
{
  "paymentIntentClientSecret": "pi_..._secret_...",
  "ephemeralKey": "ek_test_...",
  "customer": "cus_...",
  "subscriptionId": "sub_...",
  "status": "incomplete"
}
```

## Uso desde Flutter

Lanza tu app aplicando las variables con `--dart-define`:
```bash
flutter run \
  --dart-define=STRIPE_PUBLISHABLE_KEY=pk_test_xxx \
  --dart-define=STRIPE_BACKEND_URL=http://localhost:4242 \
  --dart-define=STRIPE_PRICE_V8_OUXI_WEEKLY=price_xxx \
  --dart-define=STRIPE_PRICE_V8_OUXI_MONTHLY=price_xxx \
  --dart-define=STRIPE_PRICE_V8_PRO_WEEKLY=price_xxx \
  --dart-define=STRIPE_PRICE_V8_PRO_MONTHLY=price_xxx \
  --dart-define=STRIPE_PRICE_ECO_RIDER_WEEKLY=price_xxx \
  --dart-define=STRIPE_PRICE_ECO_RIDER_MONTHLY=price_xxx
```

`lib/services/stripe_service.dart` leerá estos valores y abrirá el PaymentSheet.

## Inicio rápido en Windows (backend + ngrok)

Desde `server/` ejecuta:

```powershell
.\start_stripe_tunnel.ps1
```

El script levanta el backend Stripe en `4242`, inicia ngrok y muestra la URL pública para usar en `--dart-define=STRIPE_BACKEND_URL`.

## Despliegue gestionado (independiente 24/7)

Este repositorio ya incluye `render.yaml` en la raiz para desplegar backend + PostgreSQL gestionado en Render, sin depender de tu ordenador.

Pasos:

1. Sube el repositorio a GitHub.
2. En Render: `New` -> `Blueprint` y conecta el repositorio.
3. Render creara:
  - Base de datos `gobike-postgres`.
  - Servicio web `gobike-backend`.
4. En variables del servicio completa:
  - `STRIPE_SECRET_KEY`
  - `RESEND_API_KEY`
  - `EMAIL_FROM`
  - `APP_PUBLIC_BASE_URL` (tu URL publica de Render)
5. Ejecuta el SQL inicial en la DB gestionada:
  - Usa el contenido de `server/sql/init.sql`.

Cuando termine el deploy, el backend quedara encendido 24/7 en la nube.
