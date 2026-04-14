/**
 * Supabase Edge Function: create-payment
 * Crea una preferencia de pago en MercadoPago y devuelve el init_point (URL de pago).
 *
 * Variables de entorno requeridas (configurar en Supabase Dashboard > Settings > Edge Functions):
 *   MP_ACCESS_TOKEN  → Tu access token de MercadoPago (producción o sandbox)
 *   APP_URL          → URL de tu app, ej: https://app-juego-mundial.vercel.app
 */

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

const PLANS: Record<string, { name: string; price: number; maxMembers: number }> = {
  starter:    { name: 'Plan Starter — hasta 50 jugadores',    price: 5.00,  maxMembers: 50  },
  pro:        { name: 'Plan Pro — hasta 100 jugadores',       price: 10.00, maxMembers: 100 },
  enterprise: { name: 'Plan Enterprise — jugadores ilimitados', price: 30.00, maxMembers: 999 },
};

Deno.serve(async (req: Request) => {
  // CORS preflight
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  const MP_ACCESS_TOKEN = Deno.env.get('MP_ACCESS_TOKEN');
  if (!MP_ACCESS_TOKEN) {
    return new Response(
      JSON.stringify({ error: 'MP_ACCESS_TOKEN no configurado en Supabase Edge Functions.' }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );
  }

  let body: { game_id: string; game_name: string; plan: string; payer_email: string };
  try {
    body = await req.json();
  } catch {
    return new Response(
      JSON.stringify({ error: 'Body JSON inválido' }),
      { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );
  }

  const { game_id, game_name, plan, payer_email } = body;
  const planData = PLANS[plan];

  if (!planData) {
    return new Response(
      JSON.stringify({ error: `Plan desconocido: ${plan}. Válidos: starter, pro, enterprise` }),
      { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );
  }

  const APP_URL = Deno.env.get('APP_URL') || 'https://app-juego-mundial.vercel.app';
  const SUPABASE_URL = Deno.env.get('SUPABASE_URL') || '';

  const preference = {
    items: [
      {
        id: plan,
        title: `App Mundial 2026 — ${planData.name}`,
        description: `Juego: ${game_name}`,
        unit_price: planData.price,
        quantity: 1,
        currency_id: 'USD',          // MercadoPago convierte automáticamente a moneda local (CLP, ARS, etc.)
      },
    ],
    payer: {
      email: payer_email || 'admin@app-mundial.com',
    },
    // external_reference: usamos game_id|plan para procesarlo en el webhook
    external_reference: `${game_id}|${plan}`,
    back_urls: {
      success: `${APP_URL}/?payment=success&game=${game_id}&plan=${plan}`,
      failure: `${APP_URL}/?payment=failure&game=${game_id}&plan=${plan}`,
      pending: `${APP_URL}/?payment=pending&game=${game_id}&plan=${plan}`,
    },
    auto_return: 'approved',
    // Webhook: MercadoPago notificará a este endpoint cuando el pago cambie de estado
    notification_url: `${SUPABASE_URL}/functions/v1/payment-webhook`,
    statement_descriptor: 'APP MUNDIAL 2026',
    binary_mode: false,              // Permite pagos pendientes (ej. efectivo)
  };

  const mpRes = await fetch('https://api.mercadopago.com/checkout/preferences', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      Authorization: `Bearer ${MP_ACCESS_TOKEN}`,
    },
    body: JSON.stringify(preference),
  });

  const mpData: any = await mpRes.json();

  if (!mpData.init_point) {
    console.error('MercadoPago error:', JSON.stringify(mpData));
    return new Response(
      JSON.stringify({ error: 'Error al crear preferencia de pago en MercadoPago', detail: mpData }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );
  }

  return new Response(
    JSON.stringify({
      init_point: mpData.init_point,              // URL producción
      sandbox_init_point: mpData.sandbox_init_point, // URL sandbox (pruebas)
      preference_id: mpData.id,
    }),
    { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
  );
});
