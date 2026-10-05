import { corsHeaders, json, safeError } from '../_shared/http.ts';
import { serviceClient, userClient } from '../_shared/clients.ts';

Deno.serve(async request => {
  if (request.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders });
  if (request.method !== 'POST') return json({ error: 'Method not allowed' }, 405);
  const authorization = request.headers.get('Authorization') || '';
  if (!authorization.startsWith('Bearer ')) return json({ error: 'Authentication required' }, 401);
  try {
    const { documentId } = await request.json();
    const { data: document, error } = await userClient(authorization).from('documents')
      .select('id,private_storage_path,title,mime_type').eq('id', String(documentId || '')).single();
    if (error || !document) return json({ error: 'Document not found' }, 404);
    const { data, error: signError } = await serviceClient().storage.from('booking-documents').createSignedUrl(document.private_storage_path, 60);
    if (signError) throw signError;
    return json({ url: data.signedUrl, expiresIn: 60, title: document.title, mimeType: document.mime_type });
  } catch (error) { return safeError(error); }
});
