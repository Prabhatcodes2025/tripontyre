import { createClient } from '@supabase/supabase-js';
const url = import.meta.env.VITE_SUPABASE_URL;
const key = import.meta.env.VITE_SUPABASE_ANON_KEY;
export const supabase = url && key ? createClient(url, key) : null;

export async function submitEnquiry(values: Record<string,string>) {
  if (!supabase) return { configured: false, submitted: false };
  const { data, error } = await supabase.functions.invoke('submit-lead', {
    body: {
      name: values.name,
      phone: values.phone,
      email: values.email || null,
      destination: values.destination || null,
      travelMonth: values.month || null,
      travellers: Number(values.travellers) || null,
      message: values.message || null,
      source: 'website',
    },
  });
  if (error) throw error;
  return { configured: true, submitted: Boolean(data?.submitted) };
}
