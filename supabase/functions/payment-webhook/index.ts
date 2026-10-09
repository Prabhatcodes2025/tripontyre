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
    const success = payload.event === 'payment.captured';
    const failed = payload.event === 'payment.failed';
    const {error:applyError}=await admin.rpc('apply_payment_webhook_event',{
      p_event_id:event.id,p_order_id:orderId,p_payment_id:String(paymentEntity.id||''),
      p_amount:Number(paymentEntity.amount),p_currency:String(paymentEntity.currency||''),
      p_state:success?'success':failed?'failed':'ignored',p_failure_code:failed?String(paymentEntity.error_code||''):null,p_payload:payload,
    });
    if(applyError)throw applyError;
    return json({ received: true });
  } catch (error) { return safeError(error); }
});
