import { createClient } from '@supabase/supabase-js';
const url = import.meta.env.VITE_SUPABASE_URL;
const key = import.meta.env.VITE_SUPABASE_ANON_KEY;
export const supabase = url && key ? createClient(url, key) : null;

export async function submitEnquiry(values: Record<string,string>) {
  if (!supabase) return { demo: true };
  const { error } = await supabase.from('enquiries').insert({
    name: values.name, phone: values.phone, email: values.email || null,
    destination: values.destination || null, travel_month: values.month || null,
    travellers: Number(values.travellers) || null, message: values.message || null,
    status: 'new'
  });
  if (error) throw error;
  return { demo: false };
}
