const defaultOrigins = ['https://mytripontravel.com', 'https://www.mytripontravel.com', 'https://tripontyre.vercel.app'];

function allowedOrigins() {
  const configured = (Deno.env.get('PUBLIC_SITE_ORIGINS') || Deno.env.get('PUBLIC_SITE_ORIGIN') || '')
    .split(',').map(value => value.trim()).filter(Boolean);
  return new Set([...defaultOrigins, ...configured]);
}

export function corsHeaders(request?: Request) {
  const requested = request?.headers.get('origin') || '';
  const origin = allowedOrigins().has(requested) ? requested : defaultOrigins[0];
  return {
    'Access-Control-Allow-Origin': origin,
    'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type, x-razorpay-signature, x-razorpay-event-id',
    'Access-Control-Allow-Methods': 'POST, OPTIONS',
    'Vary': 'Origin',
  };
}

export const json = (body: unknown, status = 200, request?: Request) => new Response(JSON.stringify(body), {
  status,
  headers: { ...corsHeaders(request), 'Content-Type': 'application/json', 'Cache-Control': 'no-store' },
});

export function safeError(error: unknown, request?: Request) {
  console.error(error);
  return json({ error: 'The request could not be completed.' }, 400, request);
}
