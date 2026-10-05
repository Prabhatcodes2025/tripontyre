import { corsHeaders, json, safeError } from '../_shared/http.ts';
import { serviceClient, userClient } from '../_shared/clients.ts';

Deno.serve(async request => {
  if (request.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders });
  if (request.method !== 'POST') return json({ error: 'Method not allowed' }, 405);
  const authorization = request.headers.get('Authorization') || '';
  if (!authorization.startsWith('Bearer ')) return json({ error: 'Authentication required' }, 401);
  try {
    const body = await request.json();
    const paymentMode = body.paymentMode === 'full' ? 'full' : 'advance';
    const { data: booking, error } = await userClient(authorization).from('bookings')
      .select('id,reference,total_amount,advance_amount,balance_amount,currency,payment_status')
      .eq('id', String(body.bookingId || '')).single();
    if (error || !booking) return json({ error: 'Booking not found' }, 404);
    const amount = paymentMode === 'full' ? booking.balance_amount : Math.min(booking.advance_amount, booking.balance_amount);
    if (amount <= 0) return json({ error: 'No payment is due' }, 409);

    const provider = Deno.env.get('PAYMENT_PROVIDER') || '';
    const keyId = Deno.env.get('RAZORPAY_KEY_ID') || '';
    const keySecret = Deno.env.get('RAZORPAY_KEY_SECRET') || '';
    if (provider !== 'razorpay' || !keyId || !keySecret) return json({ configured: false, message: 'Payment provider is not configured. No charge was made.' });

    const admin = serviceClient();
    const { data: existing } = await admin.from('payments').select('provider_order_id,amount,currency,status')
      .eq('booking_id', booking.id).eq('payment_kind', paymentMode).in('status', ['pending','processing']).maybeSingle();
    if (existing) return json({ configured: true, provider, order: { id: existing.provider_order_id, amount: existing.amount, currency: existing.currency } });

    const providerResponse = await fetch('https://api.razorpay.com/v1/orders', {
      method: 'POST', headers: { 'Content-Type': 'application/json', Authorization: `Basic ${btoa(`${keyId}:${keySecret}`)}` },
      body: JSON.stringify({ amount, currency: booking.currency, receipt: booking.reference, notes: { booking_id: booking.id, payment_mode: paymentMode } }),
    });
    if (!providerResponse.ok) throw new Error(`Provider rejected order: ${providerResponse.status}`);
    const order = await providerResponse.json();
    const { error: insertError } = await admin.from('payments').insert({
      booking_id: booking.id, provider, provider_order_id: order.id, amount, currency: booking.currency,
      payment_kind: paymentMode, status: 'pending', idempotency_key: crypto.randomUUID(), provider_payload: order,
    });
    if (insertError) throw insertError;
    return json({ configured: true, provider, order: { id: order.id, amount: order.amount, currency: order.currency, keyId } }, 201);
  } catch (error) { return safeError(error); }
});
