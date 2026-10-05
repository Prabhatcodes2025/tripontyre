type PaymentOrder = { id: string; amount: number; currency: string; keyId: string };

declare global {
  interface Window {
    Razorpay?: new (options: Record<string, unknown>) => { open: () => void };
  }
}

function loadRazorpay() {
  return new Promise<void>((resolve, reject) => {
    if (window.Razorpay) return resolve();
    const existing = document.querySelector<HTMLScriptElement>('script[data-payment-provider="razorpay"]');
    if (existing) { existing.addEventListener('load', () => resolve(), { once: true }); existing.addEventListener('error', () => reject(new Error('Payment interface could not be loaded.')), { once: true }); return; }
    const script = document.createElement('script');
    script.src = 'https://checkout.razorpay.com/v1/checkout.js';
    script.async = true;
    script.dataset.paymentProvider = 'razorpay';
    script.onload = () => resolve();
    script.onerror = () => reject(new Error('Payment interface could not be loaded.'));
    document.head.append(script);
  });
}

export async function openPaymentCheckout(provider: string | undefined, order: unknown, bookingReference: string) {
  if (provider !== 'razorpay') throw new Error('The configured payment provider is not supported by this build.');
  const safeOrder = order as PaymentOrder;
  if (!safeOrder?.id || !safeOrder?.amount || !safeOrder?.keyId) throw new Error('The payment order is incomplete.');
  await loadRazorpay();
  return new Promise<'submitted' | 'dismissed'>((resolve) => {
    const Razorpay = window.Razorpay;
    if (!Razorpay) throw new Error('Payment interface is unavailable.');
    const checkout = new Razorpay({
      key: safeOrder.keyId,
      order_id: safeOrder.id,
      amount: safeOrder.amount,
      currency: safeOrder.currency,
      name: 'My Tripon Travel',
      description: `Booking ${bookingReference}`,
      handler: () => resolve('submitted'),
      modal: { ondismiss: () => resolve('dismissed') },
      theme: { color: '#dba83d' },
    });
    checkout.open();
  });
}
