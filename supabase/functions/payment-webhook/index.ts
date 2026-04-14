/**
 * Supabase Edge Function: payment-webhook
 * Recibe notificaciones de MercadoPago y actualiza el plan del juego en Supabase.
 *
 * Variables de entorno requeridas:
 *   MP_ACCESS_TOKEN          → Tu access token de MercadoPago
 *   SUPABASE_URL             → URL de tu proyecto Supabase (auto-disponible en Edge Functions)
 *   SUPABASE_SERVICE_ROLE_KEY → Service role key (para escribir en la DB)
 */

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

const PLAN_LIMITS: Record<string, number> = {
  starter:    50,
  pro:        100,
  enterprise: 999,
};

Deno.serve(async (req: Request) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  const MP_ACCESS_TOKEN        = Deno.env.get('MP_ACCESS_TOKEN');
  const SUPABASE_URL           = Deno.env.get('SUPABASE_URL')!;
  const SUPABASE_SERVICE_KEY   = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;

  const sb = createClient(SUPABASE_URL, SUPABASE_SERVICE_KEY);

  let body: any;
  try {
    body = await req.json();
  } catch {
    return new Response(JSON.stringify({ ok: false, error: 'Invalid JSON' }), {
      status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  }

  console.log('MercadoPago webhook body:', JSON.stringify(body));

  // MercadoPago envía type="payment" cuando hay una actualización de pago
  if (body.type === 'payment' && body.data?.id) {
    const paymentId = body.data.id;

    // Consultar detalles del pago en MercadoPago
    const payRes = await fetch(`https://api.mercadopago.com/v1/payments/${paymentId}`, {
      headers: { Authorization: `Bearer ${MP_ACCESS_TOKEN}` },
    });
    const payment: any = await payRes.json();

    console.log('Payment status:', payment.status, 'external_reference:', payment.external_reference);

    if (payment.status === 'approved') {
      // external_reference tiene el formato "game_id|plan"
      const [gameId, plan] = (payment.external_reference || '').split('|');
      if (!gameId || !plan || !PLAN_LIMITS[plan]) {
        console.error('external_reference inválido:', payment.external_reference);
        return new Response(JSON.stringify({ ok: false, error: 'external_reference inválido' }), {
          status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        });
      }

      const maxMembers = PLAN_LIMITS[plan];

      const { error } = await sb
        .from('games')
        .update({
          plan,
          payment_status: 'paid',
          payment_id: String(paymentId),
          max_members: maxMembers,
        })
        .eq('id', gameId);

      if (error) {
        console.error('Error actualizando game:', error.message);
        return new Response(JSON.stringify({ ok: false, error: error.message }), {
          status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        });
      }

      console.log(`✅ Juego ${gameId} actualizado a plan ${plan} (max ${maxMembers} miembros)`);
    }
  }

  return new Response(JSON.stringify({ ok: true }), {
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  });
});
