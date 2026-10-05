import type { Session } from '@supabase/supabase-js';
import { supabase } from '../lib/supabase';
import type { BookingRecord, BookingRequest, UserRole } from '../types/domain';

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
    options: { data: { full_name: fullName } },
  });
  if (error) throw error;
  return data;
}

export async function requestPasswordReset(email: string) {
  const { error } = await client().auth.resetPasswordForEmail(email, {
    redirectTo: `${window.location.origin}/account`,
  });
  if (error) throw error;
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

export async function listAdminRecords(table: string) {
  const { data, error } = await client().from(table).select('*').limit(100);
  if (error) throw error;
  return data || [];
}

export async function updateAdminRecord(table: string, id: string, values: Record<string, unknown>) {
  const { data, error } = await client().from(table).update(values).eq('id', id).select().single();
  if (error) throw error;
  return data;
}
