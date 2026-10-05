import { json, safeError } from '../_shared/http.ts';
import { serviceClient } from '../_shared/clients.ts';

const bytesToHex = (bytes: ArrayBuffer) => Array.from(new Uint8Array(bytes)).map(value => value.toString(16).padStart(2,'0')).join('');
async function validHmac(payload: string, signature: string, secret: string) {
  const key = await crypto.subtle.importKey('raw', new TextEncoder().encode(secret), { name: 'HMAC', hash: 'SHA-256' }, false, ['sign']);
  const expected = bytesToHex(await crypto.subtle.sign('HMAC', key, new TextEncoder().encode(payload)));
  if (expected.length !== signature.length) return false;
  let mismatch = 0; for (let index = 0; index < expected.length; index++) mismatch |= expected.charCodeAt(index) ^ signature.charCodeAt(index);
  return mismatch === 0;
}

Deno.serve(async request => {
  if (request.method !== 'POST') return json({ error: 'Method not allowed' }, 405);
  try {
    if ((Deno.env.get('PAYMENT_PROVIDER') || '') !== 'razorpay') return json({ error: 'Payment webhook is not configured' }, 503);
    const secret = Deno.env.get('RAZORPAY_WEBHOOK_SECRET') || '';
    if (!secret) return json({ error: 'Payment webhook is not configured' }, 503);
    const raw = await request.text();
    const signature = request.headers.get('x-razorpay-signature') || '';
    const signatureValid = await validHmac(raw, signature, secret);
    if (!signatureValid) return json({ error: 'Invalid signature' }, 401);
    const payload = JSON.parse(raw);
    const eventId = request.headers.get('x-razorpay-event-id') || payload?.payload?.payment?.entity?.id || crypto.randomUUID();
    const admin = serviceClient();
    const { data: event, error: eventError } = await admin.from('payment_webhook_events').insert({ provider:'razorpay', provider_event_id:eventId, signature_valid:true, payload }).select('id').single();
    if (eventError?.code === '23505') return json({ received: true, duplicate: true });
    if (eventError) throw eventError;
    const paymentEntity = payload?.payload?.payment?.entity;
    const orderId = paymentEntity?.order_id;
    if (!orderId) return json({ received: true, ignored: true });
    const { data: payment, error: paymentError } = await admin.from('payments').select('*').eq('provider','razorpay').eq('provider_order_id',orderId).single();
    if (paymentError || !payment || Number(paymentEntity.amount) !== payment.amount || paymentEntity.currency !== payment.currency) throw new Error('Payment amount or currency verification failed');
    const success = payload.event === 'payment.captured';
    const failed = payload.event === 'payment.failed';
    if (success || failed) {
      await admin.from('payments').update({ status: success ? 'success' : 'failed', provider_payment_id: paymentEntity.id, verified_at: success ? new Date().toISOString() : null, failure_code: failed ? paymentEntity.error_code : null, provider_payload: payload }).eq('id', payment.id);
      if (success) {
        const { data: booking } = await admin.from('bookings').select('paid_amount,total_amount').eq('id',payment.booking_id).single();
        const paid = Math.min((booking?.paid_amount || 0) + payment.amount, booking?.total_amount || payment.amount);
        await admin.from('bookings').update({ paid_amount:paid, balance_amount:Math.max(0,(booking?.total_amount || 0)-paid), payment_status:'success', booking_status:'confirmed' }).eq('id',payment.booking_id);
      }
    }
    await admin.from('payment_webhook_events').update({ processed_at:new Date().toISOString() }).eq('id',event.id);
    return json({ received: true });
  } catch (error) { return safeError(error); }
});
