import { corsHeaders, json, safeError } from '../_shared/http.ts';
import { userClient } from '../_shared/clients.ts';

Deno.serve(async request => {
  if (request.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders });
  if (request.method !== 'POST') return json({ error: 'Method not allowed' }, 405);
  const authorization = request.headers.get('Authorization') || '';
  if (!authorization.startsWith('Bearer ')) return json({ error: 'Authentication required' }, 401);
  try {
    const body = await request.json();
    const idempotencyKey = String(body.idempotencyKey || '');
    if (!/^[0-9a-f-]{36}$/i.test(idempotencyKey)) return json({ error: 'Invalid request identifier' }, 422);
    const { data, error } = await userClient(authorization).rpc('create_booking_secure', {
      p_package_slug: String(body.packageSlug || ''),
      p_travel_date: String(body.travelDate || ''),
      p_travellers: Array.isArray(body.travellers) ? body.travellers : [],
      p_payment_mode: String(body.paymentMode || ''),
      p_idempotency_key: idempotencyKey,
    });
    if (error) throw error;
    return json({ booking: data }, 201);
  } catch (error) { return safeError(error); }
});
