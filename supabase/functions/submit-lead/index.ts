import { corsHeaders, json, safeError } from '../_shared/http.ts';
import { serviceClient } from '../_shared/clients.ts';

const clean = (value: unknown, max = 500) => String(value || '').trim().slice(0, max);
const digest = async (value: string) => Array.from(new Uint8Array(await crypto.subtle.digest('SHA-256', new TextEncoder().encode(value)))).map(x => x.toString(16).padStart(2,'0')).join('');

Deno.serve(async request => {
  if (request.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders });
  if (request.method !== 'POST') return json({ error: 'Method not allowed' }, 405);
  try {
    const body = await request.json();
    const name = clean(body.name, 120), phone = clean(body.phone, 30), email = clean(body.email, 254);
    const travellers = body.travellers == null || body.travellers === '' ? null : Number(body.travellers);
    if (name.length < 2 || phone.length < 8 || (email && !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email))) return json({ error: 'Please check the enquiry details.' }, 422);
    if (travellers !== null && (!Number.isInteger(travellers) || travellers < 1 || travellers > 100)) return json({ error: 'Please check the traveller count.' }, 422);
    const admin = serviceClient();
    const ip = (request.headers.get('x-forwarded-for') || 'unknown').split(',')[0].trim();
    const keyHash = await digest(`${Deno.env.get('RATE_LIMIT_SALT') || 'configure-me'}:${ip}`);
    const since = new Date(Date.now() - 15 * 60 * 1000).toISOString();
    const { count } = await admin.from('request_rate_limits').select('id', { count: 'exact', head: true }).eq('action','submit-lead').eq('key_hash',keyHash).gte('created_at',since);
    if ((count || 0) >= 5) return json({ error: 'Please wait before sending another enquiry.' }, 429);
    await admin.from('request_rate_limits').insert({ key_hash: keyHash, action: 'submit-lead' });
    const { error } = await admin.from('leads').insert({
      name, phone, email: email || null, destination: clean(body.destination, 120) || null,
      travel_month: clean(body.travelMonth, 40) || null, adult_count: travellers,
      message: clean(body.message, 2000) || null, source: clean(body.source, 50) || 'website', status: 'new',
    });
    if (error) throw error;
    return json({ submitted: true }, 201);
  } catch (error) { return safeError(error); }
});
