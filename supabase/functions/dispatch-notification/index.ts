import { json, safeError } from '../_shared/http.ts';
import { serviceClient } from '../_shared/clients.ts';

const allowedTemplates = new Set(['booking_confirmation','payment_confirmation','payment_failed','payment_pending','lead_notification','quotation','invoice','voucher','booking_reminder']);

Deno.serve(async request => {
  if (request.method !== 'POST') return json({ error: 'Method not allowed' }, 405);
  try {
    const internalSecret = Deno.env.get('INTERNAL_FUNCTION_SECRET') || '';
    if (!internalSecret || request.headers.get('x-internal-secret') !== internalSecret) return json({ error: 'Unauthorized' }, 401);
    const body = await request.json();
    if (!allowedTemplates.has(body.templateKey) || !['email','whatsapp'].includes(body.channel)) return json({ error: 'Invalid notification request' }, 422);
    const configured = body.channel === 'email' ? Boolean(Deno.env.get('EMAIL_PROVIDER_API_KEY')) : Boolean(Deno.env.get('WHATSAPP_ACCESS_TOKEN'));
    const admin = serviceClient();
    const { data, error } = await admin.from('notifications').insert({
      user_id: body.userId || null, booking_id: body.bookingId || null, channel: body.channel,
      template_key: body.templateKey, recipient: String(body.recipient || '').slice(0,254), payload: body.payload || {},
      status: configured ? 'queued' : 'skipped_unconfigured', error_message: configured ? null : 'Provider is not configured',
    }).select().single();
    if (error) throw error;
    // Provider-specific delivery workers can consume queued records. This endpoint never reports sent before provider acknowledgement.
    return json({ notification: data, configured }, configured ? 202 : 200);
  } catch (error) { return safeError(error); }
});
