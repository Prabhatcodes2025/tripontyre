import { useEffect, useMemo, useState, type FormEvent } from 'react';
import { Link, Navigate, useNavigate, useParams } from 'react-router-dom';
import {
  ArrowLeft,
  ArrowRight,
  CalendarDays,
  Check,
  FileText,
  LogOut,
  Search,
  ShieldCheck,
  UserRound,
} from 'lucide-react';
import { photos } from '../data';
import { appConfig, money } from '../lib/config';
import { openPaymentCheckout } from '../lib/payments';
import {
  ConfigurationError,
  createBooking,
  createPaymentOrder,
  getRole,
  getDocumentUrl,
  getSession,
  listAdminRecords,
  listOwnBookings,
  listOwnDocuments,
  register,
  requestPasswordReset,
  signIn,
  signOut,
  updatePassword,
  updateAdminRecord,
} from '../services/platform';
import { usePublicContent } from '../services/content';
import type { AdminModule, BookingRecord, DocumentRecord, TravellerInput, UserRole } from '../types/domain';

const PageIntro = ({ eyebrow, title, copy }: { eyebrow: string; title: string; copy: string }) => (
  <section className="production-intro">
    <span>{eyebrow}</span>
    <h1>{title}</h1>
    <p>{copy}</p>
  </section>
);

const ServiceState = ({ children }: { children?: React.ReactNode }) => (
  <div className="service-state" role="status">
    <ShieldCheck />
    <div>
      <b>Secure service awaiting configuration</b>
      <p>{children || 'Add the browser-safe Supabase settings to enable this service. No booking, payment or account action has been simulated.'}</p>
    </div>
  </div>
);

const makeTraveller = (type: TravellerInput['type'] = 'adult'): TravellerInput => ({
  type,
  firstName: '',
  lastName: '',
  dateOfBirth: '',
});

export function BookingPage() {
  const { packages } = usePublicContent();
  const { slug = '' } = useParams();
  const trip = packages.find(item => item.slug === slug);
  const [step, setStep] = useState(1);
  const [travelDate, setTravelDate] = useState('');
  const [travellers, setTravellers] = useState<TravellerInput[]>([makeTraveller()]);
  const [paymentMode, setPaymentMode] = useState<'advance' | 'full'>('advance');
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState('');
  const [booking, setBooking] = useState<BookingRecord | null>(null);
  const [paymentMessage, setPaymentMessage] = useState('');

  if (!trip) return <Navigate to="/packages" replace />;

  const updateTraveller = (index: number, field: keyof TravellerInput, value: string) => {
    setTravellers(current => current.map((item, itemIndex) => itemIndex === index ? { ...item, [field]: value } : item));
  };

  const addTraveller = (type: TravellerInput['type']) => {
    if (travellers.length < 12) setTravellers(current => [...current, makeTraveller(type)]);
  };

  const removeTraveller = (index: number) => {
    if (travellers.length > 1) setTravellers(current => current.filter((_, itemIndex) => itemIndex !== index));
  };

  const next = () => {
    setError('');
    if (step === 1 && !travelDate) return setError('Choose a travel date to continue.');
    if (step === 2 && travellers.some(item => !item.firstName.trim() || !item.lastName.trim())) return setError('Add the name of every traveller.');
    setStep(value => Math.min(4, value + 1));
  };

  async function submit() {
    setBusy(true);
    setError('');
    try {
      const created = await createBooking({
        packageSlug: trip!.slug,
        travelDate,
        travellers,
        paymentMode,
        idempotencyKey: crypto.randomUUID(),
      });
      setBooking(created);
      const payment = await createPaymentOrder(created.id, paymentMode);
      if (payment.configured) {
        const result = await openPaymentCheckout(payment.provider, payment.order, created.reference);
        setPaymentMessage(result === 'submitted' ? 'Payment was submitted and is awaiting secure webhook verification. Check My Trips for the confirmed status.' : 'Payment was not completed. Your booking remains pending and can be paid later.');
      } else setPaymentMessage(payment.message || 'Payment provider is not configured. Your booking remains pending; no charge was made.');
    } catch (caught) {
      setError(caught instanceof ConfigurationError ? 'Booking is not yet enabled because Supabase is not configured. No booking or payment was created.' : caught instanceof Error ? caught.message : 'Booking could not be created.');
    } finally {
      setBusy(false);
    }
  }

  return <>
    <PageIntro eyebrow="SECURE ONLINE BOOKING" title={trip.title} copy={`${trip.place} · ${trip.duration}. Your amount and availability are always recalculated on the server before a booking is created.`}/>
    <section className="booking-shell">
      <ol className="booking-steps" aria-label="Booking progress">
        {['Travel date', 'Travellers', 'Price summary', 'Payment'].map((label, index) => <li key={label} className={step >= index + 1 ? 'active' : ''}><span>{index + 1}</span>{label}</li>)}
      </ol>
      {!appConfig.supabaseConfigured && <ServiceState />}
      {booking ? <div className="booking-confirmation">
        <Check />
        <span>BOOKING CREATED</span>
        <h2>{booking.reference}</h2>
        <p>{paymentMessage}</p>
        <dl><div><dt>Total</dt><dd>{money(booking.total_amount, booking.currency)}</dd></div><div><dt>Payment</dt><dd>{booking.payment_status}</dd></div><div><dt>Balance</dt><dd>{money(booking.balance_amount, booking.currency)}</dd></div></dl>
        <Link className="button teal" to="/account">Open my trips <ArrowRight size={16}/></Link>
      </div> : <div className="booking-card">
        {step === 1 && <fieldset><legend>Select a travel date</legend><label>Preferred departure date<input type="date" value={travelDate} min={new Date(Date.now() + 86400000).toISOString().slice(0, 10)} onChange={event => setTravelDate(event.target.value)} required /></label><p className="field-note">Live package availability is checked again by the secure booking endpoint.</p></fieldset>}
        {step === 2 && <fieldset><legend>Traveller details</legend>{travellers.map((traveller, index) => <div className="traveller-row" key={index}><label>Traveller type<select value={traveller.type} onChange={event => updateTraveller(index, 'type', event.target.value)}><option value="adult">Adult</option><option value="child">Child</option><option value="infant">Infant</option></select></label><label>First name<input value={traveller.firstName} onChange={event => updateTraveller(index, 'firstName', event.target.value)} autoComplete="given-name" /></label><label>Last name<input value={traveller.lastName} onChange={event => updateTraveller(index, 'lastName', event.target.value)} autoComplete="family-name" /></label><label>Date of birth<input type="date" value={traveller.dateOfBirth} onChange={event => updateTraveller(index, 'dateOfBirth', event.target.value)} /></label><button type="button" className="text-button" disabled={travellers.length === 1} onClick={() => removeTraveller(index)}>Remove</button></div>)}<div className="traveller-actions"><button type="button" onClick={() => addTraveller('adult')}>+ Adult</button><button type="button" onClick={() => addTraveller('child')}>+ Child</button><button type="button" onClick={() => addTraveller('infant')}>+ Infant</button></div></fieldset>}
        {step === 3 && <fieldset><legend>Review your request</legend><div className="booking-summary"><img src={trip.image} alt=""/><div><span>{trip.place}</span><h2>{trip.title}</h2><p>{travelDate} · {travellers.length} traveller{travellers.length === 1 ? '' : 's'}</p></div></div><div className="server-price"><ShieldCheck/><div><b>Server-verified pricing</b><p>Tax, advance, availability and the final amount are calculated from the published package record on the server. No amount from this screen is trusted.</p></div></div><label>Payment preference<select value={paymentMode} onChange={event => setPaymentMode(event.target.value as 'advance' | 'full')}><option value="advance">Configured advance amount</option><option value="full">Full payment</option></select></label></fieldset>}
        {step === 4 && <fieldset><legend>Secure payment hand-off</legend><p>Creating the booking will reserve the request and ask the configured payment adapter for an order. If the provider is unavailable, the booking remains pending and the site will never report a false payment success.</p><button type="button" className="button gold" onClick={submit} disabled={busy}>{busy ? 'Creating secure booking…' : 'Create booking & continue'}</button></fieldset>}
        {error && <p className="form-alert" role="alert">{error}</p>}
        <div className="booking-navigation">{step > 1 && <button type="button" onClick={() => setStep(value => value - 1)}><ArrowLeft size={15}/> Back</button>}{step < 4 && <button type="button" className="button teal" onClick={next}>Continue <ArrowRight size={15}/></button>}</div>
      </div>}
    </section>
  </>;
}

export function AuthPage({ mode }: { mode: 'login' | 'register' | 'forgot' | 'reset' }) {
  const navigate = useNavigate();
  const [busy, setBusy] = useState(false);
  const [message, setMessage] = useState('');
  const [error, setError] = useState('');

  async function submit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    const values = Object.fromEntries(new FormData(event.currentTarget).entries());
    setBusy(true); setMessage(''); setError('');
    try {
      if (mode === 'login') { await signIn(String(values.email), String(values.password)); navigate('/account'); }
      if (mode === 'register') { await register(String(values.email), String(values.password), String(values.fullName)); setMessage('Account created. Check your email if confirmation is required, then sign in.'); }
      if (mode === 'forgot') { await requestPasswordReset(String(values.email)); setMessage('If the address is registered, a secure reset link has been sent.'); }
      if (mode === 'reset') { await updatePassword(String(values.password)); setMessage('Password updated. You can now continue to your account.'); }
    } catch (caught) {
      setError(caught instanceof ConfigurationError ? 'Account services are awaiting Supabase configuration.' : caught instanceof Error ? caught.message : 'The request could not be completed.');
    } finally { setBusy(false); }
  }

  const title = mode === 'login' ? 'Welcome back.' : mode === 'register' ? 'Create your account.' : mode === 'reset' ? 'Choose a new password.' : 'Reset your password.';
  return <section className="auth-layout"><div className="auth-image" style={{ backgroundImage: `linear-gradient(#102f3944,#102f39aa),url(${photos.kashmir})` }}><span>MY TRIPON TRAVEL</span><h1>Your journeys,<br/><em>kept together.</em></h1></div><div className="auth-panel"><span>SECURE CUSTOMER PORTAL</span><h2>{title}</h2>{!appConfig.supabaseConfigured && <ServiceState />}<form onSubmit={submit}>{mode === 'register' && <label>Full name<input name="fullName" autoComplete="name" required minLength={2}/></label>}{mode !== 'reset' && <label>Email address<input type="email" name="email" autoComplete="email" required/></label>}{mode !== 'forgot' && <label>{mode === 'reset' ? 'New password' : 'Password'}<input type="password" name="password" autoComplete={mode === 'login' ? 'current-password' : 'new-password'} minLength={8} required/></label>}<button className="button gold" disabled={busy}>{busy ? 'Please wait…' : mode === 'login' ? 'Sign in' : mode === 'register' ? 'Create account' : mode === 'reset' ? 'Update password' : 'Send reset link'}</button></form>{message && <p className="form-success" role="status">{message}</p>}{error && <p className="form-alert" role="alert">{error}</p>}<nav>{mode !== 'login' && <Link to="/login">Sign in</Link>}{mode !== 'register' && <Link to="/register">Create account</Link>}{mode !== 'forgot' && mode !== 'reset' && <Link to="/forgot-password">Forgot password?</Link>}{mode === 'reset' && <Link to="/account">Continue to my account</Link>}</nav></div></section>;
}

export function CustomerPortal() {
  const [loading, setLoading] = useState(true);
  const [authenticated, setAuthenticated] = useState(false);
  const [bookings, setBookings] = useState<BookingRecord[]>([]);
  const [documents, setDocuments] = useState<DocumentRecord[]>([]);
  const [error, setError] = useState('');
  const navigate = useNavigate();

  useEffect(() => { void (async () => { try { const session = await getSession(); setAuthenticated(Boolean(session)); if (session) { const [ownBookings, ownDocuments] = await Promise.all([listOwnBookings(), listOwnDocuments()]); setBookings(ownBookings); setDocuments(ownDocuments); } } catch (caught) { setError(caught instanceof Error ? caught.message : 'Unable to load your trips.'); } finally { setLoading(false); } })(); }, []);
  if (loading) return <div className="route-loading">Loading your trips…</div>;
  if (!appConfig.supabaseConfigured) return <><PageIntro eyebrow="CUSTOMER PORTAL" title="Your travel desk." copy="Bookings, payments and documents are protected by account-level access."/><section className="portal-shell"><ServiceState /></section></>;
  if (!authenticated) return <Navigate to="/login" replace />;
  return <><PageIntro eyebrow="CUSTOMER PORTAL" title="Your travel desk." copy="See upcoming journeys, balances, documents and booking history in one secure place."/><section className="portal-shell"><div className="portal-toolbar"><div><UserRound/><span>MY ACCOUNT</span></div><button onClick={async () => { await signOut(); navigate('/login'); }}><LogOut size={16}/> Sign out</button></div>{error && <p className="form-alert">{error}</p>}<div className="portal-metrics"><div><b>{bookings.filter(item => item.booking_status === 'confirmed').length}</b><span>Upcoming trips</span></div><div><b>{bookings.length}</b><span>Booking history</span></div><div><b>{bookings.filter(item => item.balance_amount > 0).length}</b><span>Outstanding balances</span></div></div><div className="portal-grid"><section><h2>My bookings</h2>{bookings.length ? bookings.map(item => <article className="booking-row" key={item.id}><CalendarDays/><div><span>{item.reference}</span><h3>{item.tour_packages?.title || 'Custom journey'}</h3><p>{new Date(item.travel_date).toLocaleDateString('en-IN', { dateStyle: 'long' })}</p></div><div><b>{item.booking_status}</b><span>{money(item.balance_amount, item.currency)} balance</span></div></article>) : <p className="empty-copy">No bookings yet. When you book a journey, it will appear here.</p>}</section><aside><h2>Documents</h2><p>Invoices, vouchers and travel documents appear here only when issued for your booking.</p>{documents.length ? documents.map(document => <button className="document-placeholder" key={document.id} onClick={async () => { try { window.location.assign(await getDocumentUrl(document.id)); } catch (caught) { setError(caught instanceof Error ? caught.message : 'Document access failed.'); } }}><FileText/><span>{document.title}</span></button>) : <div className="document-placeholder"><FileText/><span>No documents issued</span></div>}<h2>Need help?</h2><Link className="line-link" to="/contact">Contact the travel team <ArrowRight size={15}/></Link></aside></div></section></>;
}

const adminModules: AdminModule[] = [
  { label: 'Dashboard', description: 'Operational overview and service configuration.' },
  { label: 'Tours & Packages', table: 'tour_packages', description: 'Package content, pricing, availability and publication.' },
  { label: 'Destinations', table: 'destinations', description: 'Destination landing pages and travel regions.' },
  { label: 'Treks', table: 'tour_packages', description: 'Trek products filtered by package category.' },
  { label: 'Expeditions', table: 'tour_packages', description: 'Expedition products filtered by package category.' },
  { label: 'Weekend Getaways', table: 'tour_packages', description: 'Short-break inventory and publication.' },
  { label: 'Villas', table: 'tour_packages', description: 'Villa stays and availability.' },
  { label: 'Travel Services', table: 'travel_services', description: 'Bookable and enquiry-led ancillary services.' },
  { label: 'Bookings', table: 'bookings', description: 'Booking status, travel dates and payment state.', statusField: 'booking_status', statuses: ['pending_payment','confirmed','cancelled','completed'] },
  { label: 'Customers', table: 'profiles', description: 'Customer accounts. Access remains governed by RLS.' },
  { label: 'Leads', table: 'leads', description: 'Enquiries, source, notes and follow-up state.', statusField: 'status', statuses: ['new','contacted','follow_up','qualified','converted','closed_lost'] },
  { label: 'Custom Trip Enquiries', table: 'leads', description: 'Custom itinerary requests and traveller details.' },
  { label: 'Quotations', table: 'quotations', description: 'Versioned quotations and printable customer views.' },
  { label: 'Invoices', table: 'invoices', description: 'Booking invoices and payment status.' },
  { label: 'Vouchers', table: 'vouchers', description: 'Hotel and transport vouchers.' },
  { label: 'Documents', table: 'documents', description: 'Private booking files and signed access.' },
  { label: 'Payments', table: 'payments', description: 'Provider transactions and reconciliation.' },
  { label: 'Blogs', table: 'blogs', description: 'Travel journal publishing.' },
  { label: 'Events', table: 'events', description: 'Travel events and registration links.' },
  { label: 'Gallery', table: 'gallery_items', description: 'Photo and video metadata.' },
  { label: 'Testimonials', table: 'testimonials', description: 'Verified traveller stories.' },
  { label: 'Reviews', table: 'reviews', description: 'Moderated customer reviews.' },
  { label: 'FAQs', table: 'faqs', description: 'Frequently asked questions and ordering.' },
  { label: 'Newsletter Subscribers', table: 'newsletter_subscribers', description: 'Consent-aware subscriber records.' },
  { label: 'Homepage Sections', table: 'site_sections', description: 'Homepage ordering, visibility and content.' },
  { label: 'Menus', table: 'navigation_items', description: 'Navigation labels, URLs and ordering.' },
  { label: 'Footer', table: 'site_settings', description: 'Contact and footer configuration.' },
  { label: 'SEO', table: 'seo_entries', description: 'Route metadata, canonical URLs and social cards.' },
  { label: 'Site Settings', table: 'site_settings', description: 'Provider-safe public configuration.' },
  { label: 'Reports', table: 'report_exports', description: 'Generated operational reports.' },
  { label: 'Audit Logs', table: 'audit_logs', description: 'Immutable privileged-action history.' },
];

export function AdminPage() {
  const [loading, setLoading] = useState(true);
  const [role, setRole] = useState<UserRole | null>(null);
  const [active, setActive] = useState(adminModules[0]);
  const [records, setRecords] = useState<Record<string, unknown>[]>([]);
  const [search, setSearch] = useState('');
  const [error, setError] = useState('');

  useEffect(() => { void (async () => { try { const session = await getSession(); if (session) setRole(await getRole(session.user.id)); } catch (caught) { setError(caught instanceof Error ? caught.message : 'Admin access could not be verified.'); } finally { setLoading(false); } })(); }, []);
  useEffect(() => { if (!active.table || !['admin','super_admin'].includes(role || '')) { setRecords([]); return; } void (async () => { try { setError(''); setRecords(await listAdminRecords(active.table!)); } catch (caught) { setError(caught instanceof Error ? caught.message : 'Records could not be loaded.'); } })(); }, [active, role]);
  const shown = useMemo(() => { const term = search.toLowerCase().trim(); return term ? records.filter(record => JSON.stringify(record).toLowerCase().includes(term)) : records; }, [records, search]);

  if (loading) return <div className="route-loading">Verifying admin access…</div>;
  if (!appConfig.supabaseConfigured) return <><PageIntro eyebrow="OPERATIONS" title="My Tripon Admin" copy="Protected management for content, bookings, customers and finance."/><section className="portal-shell"><ServiceState>Configure Supabase, apply the production migration and assign an admin role in the protected profiles table. The admin interface will not bypass authorization.</ServiceState></section></>;
  if (!['admin','super_admin'].includes(role || '')) return <section className="access-denied"><ShieldCheck/><h1>Admin access required</h1><p>This route verifies the role stored in the protected profile record, not editable user metadata.</p><Link to="/login">Sign in with an authorized account</Link></section>;

  async function updateStatus(id: string, value: string) { if (!active.table || !active.statusField) return; try { const updated = await updateAdminRecord(active.table, id, { [active.statusField]: value }); setRecords(current => current.map(item => item.id === id ? updated : item)); } catch (caught) { setError(caught instanceof Error ? caught.message : 'Status update failed.'); } }

  return <section className="admin-shell"><aside><div className="admin-brand"><ShieldCheck/><span>MY TRIPON<br/><b>OPERATIONS</b></span></div><nav>{adminModules.map(module => <button className={active.label === module.label ? 'active' : ''} key={module.label} onClick={() => { setActive(module); setSearch(''); }}>{module.label}</button>)}</nav></aside><main><header><div><span>ADMIN / {active.label.toUpperCase()}</span><h1>{active.label}</h1><p>{active.description}</p></div></header>{error && <p className="form-alert">{error}</p>}{active.label === 'Dashboard' ? <div className="admin-overview"><div><b>{adminModules.length - 1}</b><span>Managed modules</span></div><div><b>RLS</b><span>Backend authorization</span></div><div><b>{appConfig.paymentProvider}</b><span>Payment adapter</span></div><section><h2>Launch checklist</h2><ul><li>Apply the production migration</li><li>Create an authorized admin profile</li><li>Deploy Edge Functions with server secrets</li><li>Configure payment and communication providers</li></ul></section></div> : <><div className="admin-tools"><label><Search/><input value={search} onChange={event => setSearch(event.target.value)} placeholder={`Search ${active.label.toLowerCase()}`}/></label><span>{shown.length} record{shown.length === 1 ? '' : 's'}</span></div><div className="admin-table-wrap"><table><thead><tr><th>Record</th><th>Details</th><th>Status</th><th>Updated</th></tr></thead><tbody>{shown.map(record => { const id = String(record.id || ''); const title = String(record.title || record.name || record.reference || record.email || id); const status = String(record[active.statusField || 'status'] || record.published || '—'); return <tr key={id}><td><b>{title}</b><small>{id}</small></td><td>{String(record.slug || record.destination || record.email || record.phone || '—')}</td><td>{active.statusField && active.statuses ? <select aria-label={`Status for ${title}`} value={status} onChange={event => void updateStatus(id, event.target.value)}>{active.statuses.map(value => <option value={value} key={value}>{value.replaceAll('_',' ')}</option>)}</select> : status}</td><td>{record.updated_at ? new Date(String(record.updated_at)).toLocaleDateString('en-IN') : '—'}</td></tr>; })}{!shown.length && <tr><td colSpan={4}>No records in this module.</td></tr>}</tbody></table></div></>}</main></section>;
}

const legalCopy: Record<string, { title: string; sections: [string, string][] }> = {
  privacy: { title: 'Privacy Policy', sections: [['What we collect','Contact, trip and account information you provide may be used to respond to enquiries, administer bookings and deliver travel services.'],['How it is protected','Access is limited by role and customer ownership. Booking documents are private and should be delivered through signed, expiring links.'],['Your choices','You may request correction or deletion where applicable, subject to legal and accounting retention obligations.']] },
  terms: { title: 'Terms & Conditions', sections: [['Using the website','Website content is general information. A trip becomes confirmed only under the terms shown in an accepted quotation or booking confirmation.'],['Supplier terms','Airlines, hotels, transport operators and other suppliers may apply their own conditions.'],['Changes','Final commercial terms must be reviewed and approved before launch.']] },
  cancellation: { title: 'Cancellation Policy', sections: [['Cancellation requests','Requests should be made through the contact details on the booking confirmation.'],['Charges','The final schedule of cancellation charges must be supplied by My Tripon Travel and may depend on non-refundable supplier commitments.']] },
  refund: { title: 'Refund Policy', sections: [['Eligibility','Refund eligibility depends on the confirmed booking terms, supplier rules and amounts actually recovered.'],['Processing','Approved refunds are returned through the appropriate payment channel and recorded against the booking.']] },
  payment: { title: 'Payment Policy', sections: [['Secure processing','Payment amounts are created and verified on the server. Card or UPI secrets are not handled by the React application.'],['Advance and balance','The applicable advance, due dates and outstanding balance are shown in the confirmed quotation or booking.']] },
  agreement: { title: 'User Agreement', sections: [['Account responsibility','Customers are responsible for accurate traveller information and for protecting their account credentials.'],['Acceptable use','Do not attempt unauthorized access, misuse booking endpoints or upload unsafe files.']] },
};

export function LegalPage({ kind }: { kind: keyof typeof legalCopy }) { const page = legalCopy[kind]; return <><PageIntro eyebrow="LEGAL INFORMATION" title={page.title} copy="Editable launch copy for client and legal review."/><article className="legal-page"><p className="legal-notice"><b>Important:</b> This is operational placeholder content and has not been represented as lawyer-approved advice.</p>{page.sections.map(([title, copy]) => <section key={title}><h2>{title}</h2><p>{copy}</p></section>)}<h2>Contact</h2><p>Questions can be sent to <a href="mailto:infomytripontravel@gmail.com">infomytripontravel@gmail.com</a>.</p></article></>; }

export function ServicesPage() { const {services}=usePublicContent(); return <><PageIntro eyebrow="TRAVEL SERVICES" title="The details around the journey." copy="Services can be configured as enquiry-led or bookable products through the CMS."/><section className="service-editorial">{services.map((service, index) => <article key={service.title}><span>0{index + 1}</span><div><h2>{service.title}</h2><p>{service.copy}</p><Link to={`/contact?service=${encodeURIComponent(service.title)}`}>Make an enquiry <ArrowRight size={15}/></Link></div></article>)}</section></>; }

export function ContentIndex({ kind }: { kind: 'journal' | 'events' | 'faqs' }) { const publicContent=usePublicContent(); const content = kind === 'journal' ? { eyebrow:'TRAVEL JOURNAL', title:'Notes for the road.', copy:'Destination guides and seasonal ideas published from the CMS.', items:publicContent.blogs } : kind === 'events' ? { eyebrow:'EVENTS', title:'Meet us along the way.', copy:'Verified travel events appear here when published.', items:publicContent.events } : { eyebrow:'GOOD TO KNOW', title:'Questions, answered.', copy:'Practical answers before you travel.', items:publicContent.faqs }; return <><PageIntro eyebrow={content.eyebrow} title={content.title} copy={content.copy}/><section className="content-index">{content.items.map((item, index) => <article key={item.title}><span>0{index + 1}</span><div><h2>{item.title}</h2><p>{item.copy}</p></div></article>)}</section></>; }
