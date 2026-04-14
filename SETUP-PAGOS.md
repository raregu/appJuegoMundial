# 💳 Configuración del Sistema de Pagos — App Mundial 2026

## Modelo Freemium

| Plan       | Jugadores | Precio   |
|------------|-----------|----------|
| Gratis     | hasta 10  | $0       |
| Starter    | hasta 50  | USD $5   |
| Pro        | hasta 100 | USD $10  |
| Enterprise | ilimitados| USD $30  |

MercadoPago convierte automáticamente el precio en USD a la moneda local del pagador
(CLP para Chile, ARS para Argentina, BRL para Brasil, etc.).

---

## Paso 1 — Crear cuenta en MercadoPago

1. Ve a https://www.mercadopago.cl/developers/es/docs
2. Crea una cuenta de vendedor en https://www.mercadopago.cl
3. En el panel de desarrolladores, ve a **"Tus integraciones"** → **"Crear aplicación"**
4. Ponle nombre: `App Mundial 2026`
5. Activa el producto: **Checkout Pro**
6. En **Credenciales de producción**, copia tu `Access Token`
   - Empieza con `APP_USR-...`
   - Para pruebas usa el `Access Token` de **credenciales de prueba** (empieza con `TEST-...`)

---

## Paso 2 — Ejecutar migración SQL en Supabase

1. Ve a tu proyecto Supabase → **SQL Editor**
2. Copia y pega el contenido de `add-payments.sql`
3. Ejecuta el script

---

## Paso 3 — Subir las Edge Functions a Supabase

### Opción A: Usando Supabase CLI (recomendado)

```bash
# Instalar CLI si no lo tienes
npm install -g supabase

# Login
supabase login

# En la carpeta del proyecto:
supabase link --project-ref eknrnhhguoxkjckckcli

# Deploy ambas funciones
supabase functions deploy create-payment
supabase functions deploy payment-webhook
```

### Opción B: Manualmente desde el Dashboard

1. Ve a Supabase Dashboard → **Edge Functions**
2. Crea función `create-payment` y pega el contenido de `supabase/functions/create-payment/index.ts`
3. Crea función `payment-webhook` y pega el contenido de `supabase/functions/payment-webhook/index.ts`

---

## Paso 4 — Configurar variables de entorno en Supabase

En Supabase Dashboard → **Settings** → **Edge Functions** → **Secrets**, agrega:

| Variable                  | Valor                                      |
|---------------------------|--------------------------------------------|
| `MP_ACCESS_TOKEN`         | Tu Access Token de MercadoPago             |
| `APP_URL`                 | `https://app-juego-mundial.vercel.app`     |
| `SUPABASE_SERVICE_ROLE_KEY` | Tu service role key (ya existe automáticamente) |

---

## Paso 5 — Probar en modo sandbox

1. Usa el `Access Token` de **credenciales de prueba** en `MP_ACCESS_TOKEN`
2. En el frontend (`index.html`), la función `startPayment()` usa `data.init_point` en producción
   y `data.sandbox_init_point` en sandbox
3. Para forzar sandbox temporalmente, cambia en `startPayment()`:
   ```js
   const url = data.sandbox_init_point || data.init_point;
   ```
4. MercadoPago tiene tarjetas de prueba en: https://www.mercadopago.cl/developers/es/docs/checkout-pro/additional-content/your-integrations/test

---

## Flujo de Pago Completo

```
Admin crea juego (plan=free, max_members=10)
    ↓
11° jugador intenta unirse → ERROR "juego lleno"
    ↓
Admin ve banner "Mejorar plan" en su panel
    ↓
Admin hace clic → selecciona plan → confirma
    ↓
Frontend llama a Supabase Edge Function create-payment
    ↓
Edge Function llama API MercadoPago → devuelve init_point URL
    ↓
Admin es redirigido a MercadoPago Checkout
    ↓
Admin paga (con tarjeta/transferencia/efectivo en CLP u otra moneda)
    ↓
MercadoPago notifica webhook → payment-webhook Edge Function
    ↓
Edge Function actualiza games: plan=starter, max_members=50, payment_status=paid
    ↓
MercadoPago redirige al admin a la app con ?payment=success&game=...&plan=...
    ↓
App detecta el retorno, recarga el juego y muestra mensaje de éxito ✅
```

---

## Notas importantes

- **Moneda local**: MercadoPago maneja la conversión automáticamente. El pagador chileno
  verá el precio en CLP, el argentino en ARS, etc.
- **Pago único**: Se cobra una sola vez por juego para toda la duración del Mundial.
- **Sin vencimiento**: El plan no expira, es permanente.
- **El webhook es crítico**: Sin él, el plan no se actualiza. Asegúrate de que la Edge
  Function `payment-webhook` esté desplegada y con la variable `MP_ACCESS_TOKEN` configurada.
