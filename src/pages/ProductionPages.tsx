import { useEffect, useMemo, useState, type FormEvent } from 'react';
import { Link, Navigate, useNavigate, useParams } from 'react-router-dom';
import {
  ArrowLeft,
  ArrowRight,
  CalendarDays,
  Check,
  FileText,
  LogOut,
  Menu,
  Plus,
  Search,
  ShieldCheck,
  UserRound,
} from 'lucide-react';
import { photos } from '../data';
import { appConfig, money } from '../lib/config';
import { openPaymentCheckout } from '../lib/payments';
import {
  ConfigurationError,
  createAdminRecord,
  completeAuthCallback,
  createBooking,
  createPaymentOrder,
  getRole,
  getAdminOverview,
  getCustomerOverview,
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
import type { BookingRecord, TravellerInput, UserRole } from '../types/domain';
import BrandLogo from '../components/BrandLogo';

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

export function AuthCallback({ resetPassword = false }: { resetPassword?: boolean }) {
  const [error, setError] = useState('');
  useEffect(() => {
    void completeAuthCallback()
      .then(async session => {
        if (resetPassword) return window.location.replace('/reset-password');
        const role = await getRole(session!.user.id);
        window.location.replace(['admin', 'super_admin'].includes(role) ? '/admin' : '/account');
      })
      .catch(caught => setError(caught instanceof Error ? caught.message : 'Authentication could not be completed.'));
  }, [resetPassword]);
  return <section className="auth-callback"><BrandLogo/><h1>{error ? 'This link could not be completed.' : 'Confirming your account…'}</h1>{error&&<><p className="form-alert">{error}</p><Link to="/login">Return to sign in</Link></>}</section>;
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
      if (mode === 'login') { const result=await signIn(String(values.email), String(values.password)); const role=await getRole(result.user.id); navigate(['admin','super_admin'].includes(role)?'/admin':'/account'); }
      if (mode === 'register') { const result=await register(String(values.email), String(values.password), String(values.fullName)); if(result.session) navigate('/account'); else setMessage('Account created. Check your email to confirm it and continue to your customer dashboard.'); }
      if (mode === 'forgot') { await requestPasswordReset(String(values.email)); setMessage('If the address is registered, a secure reset link has been sent.'); }
      if (mode === 'reset') { await updatePassword(String(values.password)); setMessage('Password updated. You can now continue to your account.'); }
    } catch (caught) {
      setError(caught instanceof ConfigurationError ? 'Account services are awaiting Supabase configuration.' : caught instanceof Error ? caught.message : 'The request could not be completed.');
    } finally { setBusy(false); }
  }

  const title = mode === 'login' ? 'Welcome back.' : mode === 'register' ? 'Create your account.' : mode === 'reset' ? 'Choose a new password.' : 'Reset your password.';
  return <section className="auth-layout"><div className="auth-image" style={{ backgroundImage: `linear-gradient(#102f3944,#102f39aa),url(${photos.kashmir})` }}><BrandLogo/><h1>Your journeys,<br/><em>kept together.</em></h1></div><div className="auth-panel"><BrandLogo/><span>SECURE CUSTOMER PORTAL</span><h2>{title}</h2>{!appConfig.supabaseConfigured && <ServiceState />}<form onSubmit={submit}>{mode === 'register' && <label>Full name<input name="fullName" autoComplete="name" required minLength={2}/></label>}{mode !== 'reset' && <label>Email address<input type="email" name="email" autoComplete="email" required/></label>}{mode !== 'forgot' && <label>{mode === 'reset' ? 'New password' : 'Password'}<input type="password" name="password" autoComplete={mode === 'login' ? 'current-password' : 'new-password'} minLength={8} required/></label>}<button className="button gold" disabled={busy}>{busy ? 'Please wait…' : mode === 'login' ? 'Sign in' : mode === 'register' ? 'Create account' : mode === 'reset' ? 'Update password' : 'Send reset link'}</button></form>{message && <p className="form-success" role="status">{message}</p>}{error && <p className="form-alert" role="alert">{error}</p>}<nav>{mode !== 'login' && <Link to="/login">Sign in</Link>}{mode !== 'register' && <Link to="/register">Create account</Link>}{mode !== 'forgot' && mode !== 'reset' && <Link to="/forgot-password">Forgot password?</Link>}{mode === 'reset' && <Link to="/account">Continue to my account</Link>}</nav></div></section>;
}

export function CustomerPortal() {
  const [loading, setLoading] = useState(true);
  const [authenticated, setAuthenticated] = useState(false);
  const [active, setActive] = useState('Overview');
  const [account, setAccount] = useState<{profile:Record<string,unknown>|null;bookings:Record<string,unknown>[];payments:Record<string,unknown>[];invoices:Record<string,unknown>[];vouchers:Record<string,unknown>[];documents:Record<string,unknown>[]}>({profile:null,bookings:[],payments:[],invoices:[],vouchers:[],documents:[]});
  const [error, setError] = useState('');
  const navigate = useNavigate();

  useEffect(() => { void (async () => { try { const session = await getSession(); setAuthenticated(Boolean(session)); if (session) setAccount(await getCustomerOverview(session.user.id) as typeof account); } catch (caught) { setError(caught instanceof Error ? caught.message : 'Unable to load your travel account.'); } finally { setLoading(false); } })(); }, []);
  if (loading) return <div className="route-loading">Loading your trips…</div>;
  if (!appConfig.supabaseConfigured) return <><PageIntro eyebrow="CUSTOMER PORTAL" title="Your travel desk." copy="Bookings, payments and documents are protected by account-level access."/><section className="portal-shell"><ServiceState /></section></>;
  if (!authenticated) return <Navigate to="/login" replace />;
  const bookings=account.bookings; const now=new Date();
  const upcoming=bookings.filter(item=>new Date(String(item.travel_date))>=now&&!['cancelled','completed'].includes(String(item.booking_status)));
  const history=bookings.filter(item=>!upcoming.includes(item));
  const name=String(account.profile?.full_name||'Traveller').trim().split(' ')[0];
  const renderBookings=(items:Record<string,unknown>[])=>items.length?<div className="trip-list">{items.map(item=>{const pkg=Array.isArray(item.tour_packages)?item.tour_packages[0]:item.tour_packages as Record<string,unknown>|undefined;return <article className="booking-row trip-row" key={String(item.id)}><CalendarDays/><div><span>{String(item.reference)}</span><h3>{String(pkg?.title||'Custom journey')}</h3><p>{new Date(String(item.travel_date)).toLocaleDateString('en-IN',{dateStyle:'long'})} · {Number(item.adult_count||0)+Number(item.child_count||0)+Number(item.infant_count||0)} traveller(s)</p></div><div><b>{String(item.booking_status).replaceAll('_',' ')}</b><span>{String(item.payment_status)} · {money(Number(item.balance_amount),String(item.currency))} balance</span></div></article>})}</div>:<div className="portal-empty"><span>YOUR NEXT JOURNEY STARTS HERE.</span><h2>Your next journey starts here.</h2><p>When you reserve a trip, every date, payment and document will stay together in this secure travel desk.</p><Link className="button gold" to="/packages">Explore trips <ArrowRight size={16}/></Link></div>;
  const renderFiles=(items:Record<string,unknown>[])=>items.length?<div className="account-records">{items.map(item=><article key={String(item.id)}><FileText/><div><b>{String(item.title||item.invoice_number||item.voucher_number)}</b><span>{String(item.status||item.document_type||'issued')}</span></div>{Boolean(item.title)&&<button onClick={async()=>{try{window.location.assign(await getDocumentUrl(String(item.id)))}catch(caught){setError(caught instanceof Error?caught.message:'Document access failed.')}}}>Open securely</button>}</article>)}</div>:<p className="empty-copy">Nothing has been issued here yet.</p>;
  const tabs=['Overview','My Trips','Upcoming Trips','Booking History','Payments','Invoices','Vouchers','Documents','Profile','Support'];
  return <section className="account-dashboard"><aside><div className="account-mark"><UserRound/><span>MY TRIPON<br/><b>TRAVEL DESK</b></span></div><nav>{tabs.map(tab=><button className={active===tab?'active':''} onClick={()=>setActive(tab)} key={tab}>{tab}</button>)}</nav><button className="account-logout" onClick={async()=>{await signOut();navigate('/login')}}><LogOut size={16}/> Logout</button></aside><main><header><div><span>SECURE CUSTOMER PORTAL</span><h1>Hello, {name}.</h1><p>Your journeys, payments and travel documents — protected and kept together.</p></div></header>{error&&<p className="form-alert">{error}</p>}{active==='Overview'&&<><div className="portal-metrics"><div><b>{upcoming.length}</b><span>Upcoming trips</span></div><div><b>{bookings.length}</b><span>Total bookings</span></div><div><b>{bookings.filter(item=>Number(item.balance_amount)>0).length}</b><span>Balances due</span></div></div><section className="account-section"><div className="account-heading"><div><span>NEXT JOURNEYS</span><h2>Trips in view</h2></div><button onClick={()=>setActive('My Trips')}>View all</button></div>{renderBookings(upcoming.slice(0,3))}</section></>}{active==='My Trips'&&renderBookings(bookings)}{active==='Upcoming Trips'&&renderBookings(upcoming)}{active==='Booking History'&&renderBookings(history)}{active==='Payments'&&(account.payments.length?<div className="account-records">{account.payments.map(item=><article key={String(item.id)}><span className="record-amount">{money(Number(item.amount),String(item.currency))}</span><div><b>{String(item.payment_kind).replaceAll('_',' ')}</b><span>{String(item.status)} · {new Date(String(item.created_at)).toLocaleDateString('en-IN')}</span></div></article>)}</div>:<p className="empty-copy">No payments recorded.</p>)}{active==='Invoices'&&renderFiles(account.invoices)}{active==='Vouchers'&&renderFiles(account.vouchers)}{active==='Documents'&&renderFiles(account.documents)}{active==='Profile'&&<section className="profile-panel"><UserRound/><div><span>FULL NAME</span><h2>{String(account.profile?.full_name||'Not added')}</h2><span>PHONE</span><p>{String(account.profile?.phone||'Not added')}</p></div></section>}{active==='Support'&&<section className="portal-empty"><span>WE ARE HERE TO HELP</span><h2>Talk to your travel team.</h2><p>Questions about a booking, payment or document? Our team can help with the next step.</p><Link className="button gold" to="/contact">Contact support</Link></section>}</main></section>;
}

type AdminField={key:string;label:string;type?:'text'|'textarea'|'number'|'boolean'|'date'|'select';options?:string[];required?:boolean};
type AdminModuleView={label:string;table?:string;description:string;statusField?:string;statuses?:string[];filter?:Record<string,string>;fields?:AdminField[];allowCreate?:boolean;idField?:string};
const commonPublish:AdminField={key:'published',label:'Published',type:'boolean'};
const adminModules: AdminModuleView[] = [
  { label: 'Dashboard', description: 'Operational overview and service configuration.' },
  { label: 'Packages', table: 'tour_packages', description: 'Package content, pricing, availability and publication.',allowCreate:true,fields:[{key:'title',label:'Package name',required:true},{key:'slug',label:'Slug',required:true},{key:'destination_id',label:'Destination ID'},{key:'category',label:'Category',type:'select',options:['domestic','maharashtra','international','trek','expedition','weekend','villa','custom']},{key:'duration_days',label:'Days',type:'number'},{key:'duration_nights',label:'Nights',type:'number'},{key:'summary',label:'Summary',type:'textarea'},{key:'description',label:'Description',type:'textarea'},{key:'hero_image',label:'Hero image URL'},{key:'highlights',label:'Highlights JSON',type:'textarea'},{key:'inclusions',label:'Inclusions JSON',type:'textarea'},{key:'exclusions',label:'Exclusions JSON',type:'textarea'},{key:'base_price',label:'Adult price (paise)',type:'number'},{key:'child_price',label:'Child price (paise)',type:'number'},{key:'infant_price',label:'Infant price (paise)',type:'number'},{key:'tax_rate',label:'Tax %',type:'number'},{key:'advance_type',label:'Advance type',type:'select',options:['percentage','fixed']},{key:'advance_value',label:'Advance value',type:'number'},{key:'featured',label:'Featured',type:'boolean'},{key:'trending',label:'Trending',type:'boolean'},commonPublish,{key:'seo_title',label:'SEO title'},{key:'seo_description',label:'SEO description',type:'textarea'}] },
  { label: 'Package Itineraries', table: 'tour_itinerary_days', description: 'Day-by-day package storytelling.',allowCreate:true,fields:[{key:'package_id',label:'Package ID',required:true},{key:'day_number',label:'Day number',type:'number',required:true},{key:'title',label:'Title',required:true},{key:'description',label:'Description',type:'textarea'},{key:'location',label:'Location'}] },
  { label: 'Package Availability', table: 'package_availability', description: 'Dated capacity, overrides and departure status.',allowCreate:true,fields:[{key:'package_id',label:'Package ID',required:true},{key:'travel_date',label:'Travel date',type:'date',required:true},{key:'capacity',label:'Capacity',type:'number',required:true},{key:'reserved',label:'Reserved',type:'number'},{key:'price_override',label:'Price override (paise)',type:'number'},{key:'status',label:'Status',type:'select',options:['open','closed','sold_out']}] },
  { label: 'Package Media', table: 'package_images', description: 'Package gallery and cover-image metadata.',allowCreate:true,fields:[{key:'package_id',label:'Package ID',required:true},{key:'storage_path',label:'Storage path',required:true},{key:'alt_text',label:'Alt text',required:true},{key:'display_order',label:'Order',type:'number'},{key:'is_cover',label:'Cover image',type:'boolean'}] },
  { label: 'Destinations', table: 'destinations', description: 'Destination landing pages and travel regions.',allowCreate:true,fields:[{key:'name',label:'Name',required:true},{key:'slug',label:'Slug',required:true},{key:'region',label:'Region'},{key:'country',label:'Country'},{key:'state',label:'State'},{key:'summary',label:'Summary',type:'textarea'},{key:'description',label:'Description',type:'textarea'},{key:'hero_image',label:'Hero image URL'},{key:'featured',label:'Featured',type:'boolean'},commonPublish,{key:'seo_title',label:'SEO title'},{key:'seo_description',label:'SEO description',type:'textarea'}] },
  { label: 'Treks', table: 'tour_packages', description: 'Trek inventory from the package catalogue.',filter:{category:'trek'} },
  { label: 'Expeditions', table: 'tour_packages', description: 'Expedition inventory from the package catalogue.',filter:{category:'expedition'} },
  { label: 'Weekend Getaways', table: 'tour_packages', description: 'Short-break inventory and publication.',filter:{category:'weekend'} },
  { label: 'Villas', table: 'tour_packages', description: 'Villa stays and availability.',filter:{category:'villa'} },
  { label: 'Travel Services', table: 'travel_services', description: 'Bookable and enquiry-led ancillary services.',allowCreate:true,fields:[{key:'name',label:'Name',required:true},{key:'slug',label:'Slug',required:true},{key:'category',label:'Category',required:true},{key:'description',label:'Description',type:'textarea'},{key:'service_mode',label:'Mode',type:'select',options:['enquiry','bookable']},{key:'base_price',label:'Base price (paise)',type:'number'},commonPublish] },
  { label: 'Bookings', table: 'bookings', description: 'Booking status, travel dates and payment state.', statusField: 'booking_status', statuses: ['pending_payment','confirmed','cancelled','completed'] },
  { label: 'Customers', table: 'profiles', description: 'Customer accounts. Access remains governed by RLS.' },
  { label: 'Leads / Enquiries', table: 'leads', description: 'Enquiries, source, notes and follow-up state.', statusField: 'status', statuses: ['new','contacted','follow_up','qualified','converted','closed_lost'],fields:[{key:'status',label:'Status',type:'select',options:['new','contacted','follow_up','qualified','converted','closed_lost']},{key:'admin_notes',label:'Admin notes',type:'textarea'}] },
  { label: 'Custom Trip Enquiries', table: 'leads', description: 'Custom itinerary requests and traveller details.' },
  { label: 'Quotations', table: 'quotations', description: 'Versioned quotations and printable customer views.' },
  { label: 'Invoices', table: 'invoices', description: 'Booking invoices and payment status.' },
  { label: 'Vouchers', table: 'vouchers', description: 'Hotel and transport vouchers.' },
  { label: 'Documents', table: 'documents', description: 'Private booking files and signed access.' },
  { label: 'Payments', table: 'payments', description: 'Provider transactions and reconciliation.' },
  { label: 'Blogs', table: 'blogs', description: 'Travel journal publishing.',allowCreate:true,fields:[{key:'title',label:'Title',required:true},{key:'slug',label:'Slug',required:true},{key:'excerpt',label:'Excerpt',type:'textarea'},{key:'body_markdown',label:'Article',type:'textarea'},{key:'cover_image',label:'Cover image URL'},commonPublish] },
  { label: 'Events', table: 'events', description: 'Travel events and registration links.',allowCreate:true,fields:[{key:'title',label:'Title',required:true},{key:'slug',label:'Slug',required:true},{key:'description',label:'Description',type:'textarea'},{key:'starts_at',label:'Starts at'},{key:'ends_at',label:'Ends at'},{key:'location',label:'Location'},{key:'cover_image',label:'Cover image URL'},{key:'registration_url',label:'Registration URL'},commonPublish] },
  { label: 'Gallery / Media', table: 'gallery_items', description: 'Photo and video metadata.',allowCreate:true,fields:[{key:'title',label:'Title'},{key:'slug',label:'Slug'},{key:'media_url',label:'Media URL',required:true},{key:'media_type',label:'Media type',type:'select',options:['image','video']},{key:'poster_url',label:'Poster URL'},{key:'category',label:'Category'},{key:'alt_text',label:'Alt text'},{key:'display_order',label:'Order',type:'number'},commonPublish] },
  { label: 'Testimonials', table: 'testimonials', description: 'Verified traveller stories.',allowCreate:true,fields:[{key:'name',label:'Traveller name',required:true},{key:'location',label:'Location'},{key:'quote',label:'Quote',type:'textarea',required:true},{key:'media_url',label:'Media URL'},{key:'media_type',label:'Media type',type:'select',options:['text','video']},{key:'poster_url',label:'Poster URL'},commonPublish] },
  { label: 'Awards', table: 'awards', description: 'Verified awards and recognitions.',allowCreate:true,fields:[{key:'title',label:'Title',required:true},{key:'issuer',label:'Issuer'},{key:'description',label:'Description',type:'textarea'},{key:'awarded_on',label:'Award date',type:'date'},{key:'image_url',label:'Image URL'},commonPublish] },
  { label: 'Reviews', table: 'reviews', description: 'Moderated customer reviews.',fields:[{key:'quote',label:'Review',type:'textarea'},{key:'rating',label:'Rating',type:'number'},{key:'verified',label:'Verified',type:'boolean'},commonPublish] },
  { label: 'FAQs', table: 'faqs', description: 'Frequently asked questions and ordering.',allowCreate:true,fields:[{key:'question',label:'Question',required:true},{key:'answer',label:'Answer',type:'textarea',required:true},{key:'category',label:'Category'},{key:'display_order',label:'Order',type:'number'},commonPublish] },
  { label: 'Newsletter Subscribers', table: 'newsletter_subscribers', description: 'Consent-aware subscriber records.' },
  { label: 'Homepage / CMS', table: 'site_sections', description: 'Homepage ordering, visibility and structured content.',allowCreate:true,fields:[{key:'section_key',label:'Section key',required:true},{key:'title',label:'Title'},{key:'content',label:'Content JSON',type:'textarea'},{key:'display_order',label:'Order',type:'number'},commonPublish] },
  { label: 'Menus', table: 'navigation_items', description: 'Navigation labels, URLs and ordering.',allowCreate:true,fields:[{key:'location',label:'Location',type:'select',options:['header','footer']},{key:'label',label:'Label',required:true},{key:'url',label:'URL',required:true},{key:'parent_id',label:'Parent ID'},{key:'display_order',label:'Order',type:'number'},commonPublish] },
  { label: 'Footer', table: 'site_settings', idField:'key', description: 'Contact and footer configuration.',allowCreate:true,fields:[{key:'key',label:'Setting key',required:true},{key:'value',label:'Value JSON',type:'textarea',required:true}] },
  { label: 'SEO', table: 'seo_entries', description: 'Route metadata, canonical URLs and social cards.',allowCreate:true,fields:[{key:'route',label:'Route',required:true},{key:'title',label:'Title',required:true},{key:'description',label:'Description',type:'textarea',required:true},{key:'canonical_url',label:'Canonical URL'},{key:'og_image',label:'Social image'},{key:'robots',label:'Robots'}] },
  { label: 'Site Settings', table: 'site_settings', idField:'key', description: 'Provider-safe public configuration.',allowCreate:true,fields:[{key:'key',label:'Setting key',required:true},{key:'value',label:'Value JSON',type:'textarea',required:true}] },
  { label: 'Reports', table: 'report_exports', description: 'Generated operational reports.' },
  { label: 'Audit Logs', table: 'audit_logs', description: 'Immutable privileged-action history.' },
];

export function AdminPage() {
  const [loading, setLoading] = useState(true);
  const [role, setRole] = useState<UserRole | null>(null);
  const [active, setActive] = useState(adminModules[0]);
  const [records, setRecords] = useState<Record<string, unknown>[]>([]);
  const [overview,setOverview]=useState<Awaited<ReturnType<typeof getAdminOverview>>|null>(null);
  const [search, setSearch] = useState('');
  const [error, setError] = useState('');
  const [editing,setEditing]=useState<Record<string,unknown>|null>(null);
  const [navOpen,setNavOpen]=useState(false);

  useEffect(() => { void (async () => { try { const session = await getSession(); if (session) setRole(await getRole(session.user.id)); } catch (caught) { setError(caught instanceof Error ? caught.message : 'Admin access could not be verified.'); } finally { setLoading(false); } })(); }, []);
  useEffect(() => { if (!active.table || !['admin','super_admin'].includes(role || '')) { setRecords([]); return; } void (async () => { try { setError(''); setRecords(await listAdminRecords(active.table!)); } catch (caught) { setError(caught instanceof Error ? caught.message : 'Records could not be loaded.'); } })(); }, [active, role]);
  useEffect(()=>{if(active.label==='Dashboard'&&['admin','super_admin'].includes(role||''))void getAdminOverview().then(setOverview).catch(caught=>setError(caught instanceof Error?caught.message:'Dashboard could not be loaded.'))},[active,role]);
  const shown = useMemo(() => { const term = search.toLowerCase().trim(); return records.filter(record=>(!active.filter||Object.entries(active.filter).every(([key,value])=>String(record[key])===value))&&(!term||JSON.stringify(record).toLowerCase().includes(term))); }, [records, search,active]);

  if (loading) return <div className="route-loading">Verifying admin access…</div>;
  if (!appConfig.supabaseConfigured) return <><PageIntro eyebrow="OPERATIONS" title="My Tripon Admin" copy="Protected management for content, bookings, customers and finance."/><section className="portal-shell"><ServiceState>Configure Supabase, apply the production migration and assign an admin role in the protected profiles table. The admin interface will not bypass authorization.</ServiceState></section></>;
  if (!['admin','super_admin'].includes(role || '')) return <section className="access-denied"><ShieldCheck/><h1>Admin access required</h1><p>This route verifies the role stored in the protected profile record, not editable user metadata.</p><Link to="/login">Sign in with an authorized account</Link></section>;

  async function updateStatus(id: string, value: string) { if (!active.table || !active.statusField) return; const idField=active.idField||'id'; try { const updated = await updateAdminRecord(active.table, id, { [active.statusField]: value },idField); setRecords(current => current.map(item => item[idField] === id ? updated : item)); } catch (caught) { setError(caught instanceof Error ? caught.message : 'Status update failed.'); } }
  async function saveEditor(event:FormEvent<HTMLFormElement>){event.preventDefault();if(!active.table||!active.fields)return;const raw=Object.fromEntries(new FormData(event.currentTarget).entries());const values:Record<string,unknown>={};const idField=active.idField||'id';for(const field of active.fields){const value=raw[field.key];if(field.type==='boolean')values[field.key]=value==='on';else if(field.type==='number')values[field.key]=value===''?null:Number(value);else if(['highlights','inclusions','exclusions','content','schema_json','value'].includes(field.key)){try{values[field.key]=JSON.parse(String(value||(['content','schema_json','value'].includes(field.key)?'{}':'[]')))}catch{return setError(`${field.label} must be valid JSON.`)}}else values[field.key]=String(value||'')||null}const editingId=editing?.[idField];try{const saved=editingId?await updateAdminRecord(active.table,String(editingId),values,idField):await createAdminRecord(active.table,values);setRecords(current=>editingId?current.map(item=>item[idField]===editingId?saved:item):[saved,...current]);setEditing(null);setError('')}catch(caught){setError(caught instanceof Error?caught.message:'Record could not be saved.')}}
  const dashboard=<div className="admin-dashboard">{overview?<><div className="admin-overview"><div><b>{overview.counts.bookings}</b><span>Total bookings</span></div><div><b>{overview.counts.leads}</b><span>Total leads</span></div><div><b>{overview.counts.pendingPayments}</b><span>Pending payments</span></div></div><div className="admin-dashboard-grid"><section><div className="account-heading"><div><span>RECENT ACTIVITY</span><h2>Bookings</h2></div></div>{overview.bookings.length?overview.bookings.map(item=><article className="admin-feed" key={String(item.id)}><div><b>{String(item.reference)}</b><span>{String(item.booking_status).replaceAll('_',' ')}</span></div><small>{new Date(String(item.travel_date)).toLocaleDateString('en-IN')} · {money(Number(item.balance_amount),String(item.currency))} due</small></article>):<p className="empty-copy">No bookings yet.</p>}</section><section><div className="account-heading"><div><span>SALES PIPELINE</span><h2>Recent leads</h2></div></div>{overview.leads.length?overview.leads.map(item=><article className="admin-feed" key={String(item.id)}><div><b>{String(item.name)}</b><span>{String(item.status).replaceAll('_',' ')}</span></div><small>{String(item.destination||'Destination not selected')}</small></article>):<p className="empty-copy">No leads yet.</p>}</section><section><div className="account-heading"><div><span>OPERATIONS</span><h2>Upcoming departures</h2></div></div>{overview.departures.length?overview.departures.map(item=><article className="admin-feed" key={String(item.id)}><div><b>{new Date(String(item.travel_date)).toLocaleDateString('en-IN')}</b><span>{String(item.status)}</span></div><small>{Number(item.reserved)}/{Number(item.capacity)} places reserved</small></article>):<p className="empty-copy">No dated departures configured.</p>}</section><section className="admin-alerts"><span>OPERATIONAL STATUS</span><h2>Provider readiness</h2><p>Supabase authorization is active. Payment and communication adapters remain gracefully unavailable until their server-only credentials are configured.</p><b>{appConfig.paymentProvider}</b></section></div></>:<div className="route-loading">Loading live operations…</div>}</div>;
  const idField=active.idField||'id';
  return <section className="admin-shell"><aside><div className="admin-brand"><ShieldCheck/><span>MY TRIPON<br/><b>OPERATIONS</b></span><button onClick={()=>setNavOpen(value=>!value)} aria-label="Toggle admin navigation"><Menu/></button></div><nav className={navOpen?'open':''}>{adminModules.map(module=><button className={active.label===module.label?'active':''} key={module.label} onClick={()=>{setActive(module);setSearch('');setEditing(null);setNavOpen(false)}}>{module.label}</button>)}</nav></aside><main><header className="admin-header"><div><span>ADMIN / {active.label.toUpperCase()}</span><h1>{active.label}</h1><p>{active.description}</p></div>{active.allowCreate&&<button className="button gold" onClick={()=>setEditing({})}><Plus size={16}/> New record</button>}</header>{error&&<p className="form-alert">{error}</p>}{active.label==='Dashboard'?dashboard:<>{active.fields&&editing&&<form className="admin-editor" onSubmit={saveEditor}><header><h2>{editing[idField]?'Edit record':'Create record'}</h2><button type="button" onClick={()=>setEditing(null)}>Close</button></header><div>{active.fields.map(field=>{const isJson=['highlights','inclusions','exclusions','content','schema_json','value'].includes(field.key);const initial=isJson?JSON.stringify(editing[field.key]??(['content','schema_json','value'].includes(field.key)?{}:[]),null,2):String(editing[field.key]??'');return <label key={field.key} className={field.type==='textarea'?'wide':''}>{field.label}{field.type==='textarea'?<textarea name={field.key} defaultValue={initial} required={field.required}/>:field.type==='select'?<select name={field.key} defaultValue={String(editing[field.key]??field.options?.[0]??'')}>{field.options?.map(option=><option key={option} value={option}>{option.replaceAll('_',' ')}</option>)}</select>:field.type==='boolean'?<input name={field.key} type="checkbox" defaultChecked={Boolean(editing[field.key])}/>:<input name={field.key} type={field.type==='number'?'number':field.type==='date'?'date':'text'} defaultValue={initial} required={field.required}/>}</label>})}</div><button className="button teal">Save securely</button></form>}<div className="admin-tools"><label><Search/><input value={search} onChange={event=>setSearch(event.target.value)} placeholder={`Search ${active.label.toLowerCase()}`}/></label><span>{shown.length} record{shown.length===1?'':'s'}</span></div><div className="admin-table-wrap"><table><thead><tr><th>Record</th><th>Details</th><th>Status</th><th>Updated</th><th>Action</th></tr></thead><tbody>{shown.map(record=>{const id=String(record[idField]||'');const title=String(record.title||record.name||record.reference||record.question||record.email||id);const status=String(record[active.statusField||'status']??(record.published?'published':'draft'));return <tr key={id}><td><b>{title}</b><small>{id}</small></td><td>{String(record.slug||record.destination||record.email||record.phone||record.travel_date||'—')}</td><td>{active.statusField&&active.statuses?<select aria-label={`Status for ${title}`} value={status} onChange={event=>void updateStatus(id,event.target.value)}>{active.statuses.map(value=><option value={value} key={value}>{value.replaceAll('_',' ')}</option>)}</select>:status}</td><td>{record.updated_at?new Date(String(record.updated_at)).toLocaleDateString('en-IN'):'—'}</td><td><div className="admin-row-actions">{active.fields&&<button onClick={()=>setEditing(record)}>Edit</button>}{typeof record.published==='boolean'&&<button onClick={async()=>{try{const updated=await updateAdminRecord(active.table!,id,{published:!record.published},idField);setRecords(current=>current.map(item=>item[idField]===id?updated:item))}catch(caught){setError(caught instanceof Error?caught.message:'Publish update failed.')}}}>{record.published?'Unpublish':'Publish'}</button>}</div></td></tr>})}{!shown.length&&<tr><td colSpan={5}><div className="admin-empty"><b>No records yet</b><span>New operational data will appear here as it is created.</span></div></td></tr>}</tbody></table></div></>}</main></section>;
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
