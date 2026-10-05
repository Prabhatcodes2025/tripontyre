export const appConfig = {
  supabaseConfigured: Boolean(import.meta.env.VITE_SUPABASE_URL && import.meta.env.VITE_SUPABASE_ANON_KEY),
  siteUrl: import.meta.env.VITE_SITE_URL || 'https://mytripontravel.com',
  whatsappNumber: import.meta.env.VITE_WHATSAPP_NUMBER || '',
  googleReviewUrl: import.meta.env.VITE_GOOGLE_REVIEW_URL || '',
  paymentProvider: import.meta.env.VITE_PAYMENT_PROVIDER || 'unconfigured',
};

export const money = (amount: number, currency = 'INR') =>
  new Intl.NumberFormat('en-IN', { style: 'currency', currency, maximumFractionDigits: 0 }).format(amount / 100);
