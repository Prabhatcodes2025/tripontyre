import type { Session } from '@supabase/supabase-js';
import { supabase } from '../lib/supabase';
import { authRedirectUrl } from '../lib/config';
import type { BookingRecord, BookingRequest, DocumentRecord, UserRole } from '../types/domain';

export class ConfigurationError extends Error {
  constructor(message = 'This service is not configured yet.') {
    super(message);
    this.name = 'ConfigurationError';
  }
}

function client() {
  if (!supabase) throw new ConfigurationError();
  return supabase;
}

export async function getSession(): Promise<Session | null> {
  if (!supabase) return null;
  const { data, error } = await supabase.auth.getSession();
  if (error) throw error;
  return data.session;
}

export async function signIn(email: string, password: string) {
  const { data, error } = await client().auth.signInWithPassword({ email, password });
  if (error) throw error;
  return data;
}

export async function register(email: string, password: string, fullName: string) {
  const { data, error } = await client().auth.signUp({
    email,
    password,
    options: {
      emailRedirectTo: authRedirectUrl('/auth/callback'),
      data: { full_name: fullName },
    },
  });
  if (error) throw error;
  return data;
}

export async function requestPasswordReset(email: string) {
  const { error } = await client().auth.resetPasswordForEmail(email, {
    redirectTo: authRedirectUrl('/auth/callback/reset-password'),
  });
  if (error) throw error;
}

export async function completeAuthCallback() {
  const api = client();
  const url = new URL(window.location.href);
  const authError = url.searchParams.get('error_description') || url.searchParams.get('error');
  if (authError) throw new Error(authError);
  const code = url.searchParams.get('code');
  if (code) {
    const { data, error } = await api.auth.exchangeCodeForSession(code);
    if (error) throw error;
    return data.session;
  }
  const { data, error } = await api.auth.getSession();
  if (error) throw error;
  if (!data.session) throw new Error('The confirmation link is invalid or has expired.');
  return data.session;
}

export async function updatePassword(password: string) {
  const { error } = await client().auth.updateUser({ password });
  if (error) throw error;
}

export async function updateOwnProfile(fullName: string, phone: string) {
  const session = await getSession();
  if (!session) throw new Error('Please sign in again.');
  const { data, error } = await client().from('profiles')
    .update({ full_name: fullName.trim(), phone: phone.trim() || null, updated_at: new Date().toISOString() })
    .eq('id', session.user.id)
    .select('id,full_name,phone,avatar_path')
    .single();
  if (error) throw error;
  return data;
}

export async function signOut() {
  const { error } = await client().auth.signOut();
  if (error) throw error;
}

export async function getRole(userId: string): Promise<UserRole> {
  const { data, error } = await client().from('profiles').select('role').eq('id', userId).single();
  if (error) throw error;
  return (data.role || 'customer') as UserRole;
}

export async function createBooking(request: BookingRequest) {
  const { data, error } = await client().functions.invoke('create-booking', { body: request });
  if (error) throw error;
  if (!data?.booking) throw new Error('The booking service returned an invalid response.');
  return data.booking as BookingRecord;
}

export async function createPaymentOrder(bookingId: string, paymentMode: 'advance' | 'full') {
  const { data, error } = await client().functions.invoke('create-payment-order', {
    body: { bookingId, paymentMode },
  });
  if (error) throw error;
  return data as { configured: boolean; provider?: string; order?: unknown; message?: string };
}

export async function listOwnBookings(): Promise<BookingRecord[]> {
  const { data, error } = await client()
    .from('bookings')
    .select('id,reference,travel_date,total_amount,tax_amount,advance_amount,balance_amount,currency,booking_status,payment_status,created_at,tour_packages(title,slug)')
    .order('created_at', { ascending: false });
  if (error) throw error;
  return (data || []) as unknown as BookingRecord[];
}

export async function listOwnDocuments(): Promise<DocumentRecord[]> {
  const { data, error } = await client().from('documents')
    .select('id,title,document_type,mime_type,issued_at,status')
    .eq('status', 'issued')
    .order('issued_at', { ascending: false });
  if (error) throw error;
  return (data || []) as DocumentRecord[];
}

export async function getDocumentUrl(documentId: string) {
  const { data, error } = await client().functions.invoke('document-access', { body: { documentId } });
  if (error) throw error;
  if (!data?.url) throw new Error('The document link could not be created.');
  return String(data.url);
}

export async function listAdminRecords(table: string) {
  const { data, error } = await client().from(table).select('*').limit(100);
  if (error) throw error;
  return data || [];
}

export async function createAdminRecord(table: string, values: Record<string, unknown>) {
  const { data, error } = await client().from(table).insert(values).select().single();
  if (error) throw error;
  return data;
}

export async function updateAdminRecord(table: string, id: string, values: Record<string, unknown>, idField = 'id') {
  const { data, error } = await client().from(table).update(values).eq(idField, id).select().single();
  if (error) throw error;
  return data;
}

export async function deleteAdminRecord(table: string, id: string, idField = 'id') {
  const { error } = await client().from(table).delete().eq(idField, id);
  if (error) throw error;
}

export async function getAdminOverview() {
  const api = client();
  const [bookings, leads, payments, departures, bookingCount, leadCount, pendingPaymentCount] = await Promise.all([
    api.from('bookings').select('id,reference,travel_date,total_amount,balance_amount,currency,booking_status,payment_status,created_at,tour_packages(title)').order('created_at',{ascending:false}).limit(6),
    api.from('leads').select('id,name,destination,status,created_at').order('created_at',{ascending:false}).limit(6),
    api.from('payments').select('id,status,amount'),
    api.from('package_availability').select('id,travel_date,capacity,reserved,status,tour_packages(title)').gte('travel_date',new Date().toISOString().slice(0,10)).order('travel_date').limit(6),
    api.from('bookings').select('id',{count:'exact',head:true}),
    api.from('leads').select('id',{count:'exact',head:true}),
    api.from('bookings').select('id',{count:'exact',head:true}).eq('payment_status','pending'),
  ]);
  const error = bookings.error || leads.error || payments.error || departures.error || bookingCount.error || leadCount.error || pendingPaymentCount.error;
  if (error) throw error;
  return {
    bookings: bookings.data || [],
    leads: leads.data || [],
    payments: payments.data || [],
    departures: departures.data || [],
    counts: { bookings:bookingCount.count || 0, leads:leadCount.count || 0, pendingPayments:pendingPaymentCount.count || 0 },
  };
}

export async function getCustomerOverview(userId: string) {
  const api = client();
  const [profile, bookings, payments, invoices, vouchers, documents] = await Promise.all([
    api.from('profiles').select('id,full_name,phone,avatar_path').eq('id',userId).single(),
    api.from('bookings').select('id,reference,travel_date,adult_count,child_count,infant_count,total_amount,paid_amount,balance_amount,currency,booking_status,payment_status,created_at,tour_packages(title,slug,hero_image)').order('created_at',{ascending:false}),
    api.from('payments').select('id,booking_id,amount,currency,payment_kind,status,verified_at,created_at').order('created_at',{ascending:false}),
    api.from('invoices').select('id,invoice_number,booking_id,status,total_amount,amount_due,currency,issued_at').order('created_at',{ascending:false}),
    api.from('vouchers').select('id,voucher_number,booking_id,voucher_type,status,issued_at').order('created_at',{ascending:false}),
    api.from('documents').select('id,title,document_type,mime_type,issued_at,status').eq('status','issued').order('issued_at',{ascending:false}),
  ]);
  const error = profile.error || bookings.error || payments.error || invoices.error || vouchers.error || documents.error;
  if (error) throw error;
  return { profile:profile.data, bookings:bookings.data || [], payments:payments.data || [], invoices:invoices.data || [], vouchers:vouchers.data || [], documents:documents.data || [] };
}
