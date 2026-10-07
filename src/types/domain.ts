export type UserRole = 'customer' | 'staff' | 'admin' | 'super_admin';

export type BookingStatus =
  | 'draft'
  | 'pending_payment'
  | 'confirmed'
  | 'cancelled'
  | 'completed';

export type PaymentStatus = 'pending' | 'processing' | 'success' | 'failed' | 'refunded';

export type TravellerInput = {
  type: 'adult' | 'child' | 'infant';
  firstName: string;
  lastName: string;
  dateOfBirth?: string;
};

export type BookingRequest = {
  packageSlug: string;
  travelDate: string;
  travellers: TravellerInput[];
  paymentMode: 'advance' | 'full';
  idempotencyKey: string;
};

export type BookingRecord = {
  id: string;
  reference: string;
  travel_date: string;
  total_amount: number;
  tax_amount: number;
  advance_amount: number;
  balance_amount: number;
  currency: string;
  booking_status: BookingStatus;
  payment_status: PaymentStatus;
  created_at: string;
  tour_packages?: { title?: string; slug?: string } | null;
};

export type DocumentRecord = {
  id: string;
  title: string;
  document_type: string;
  mime_type: string;
  issued_at: string | null;
  status: 'draft' | 'issued' | 'void';
};

export type AdminModule = {
  label: string;
  table?: string;
  description: string;
  statusField?: string;
  statuses?: string[];
};
