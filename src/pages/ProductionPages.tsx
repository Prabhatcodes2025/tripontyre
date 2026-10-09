import { useEffect, useMemo, useState, type FormEvent } from 'react';
import { Link, Navigate, useNavigate, useParams, useSearchParams } from 'react-router-dom';
import {
  ArrowLeft,
  ArrowRight,
  CalendarDays,
  Check,
  FileText,
  Gauge,
  Globe2,
  LogOut,
  Menu,
  Plus,
  RefreshCw,
  Search,
  Settings,
  ShieldCheck,
  UserRound,
  UsersRound,
  X,
} from 'lucide-react';
import { photos } from '../data';
import { appConfig, money } from '../lib/config';
import { openPaymentCheckout } from '../lib/payments';
import {
  ConfigurationError,
  createAdminRecord,
  deleteAdminRecord,
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
  updateOwnProfile,
} from '../services/platform';
import { getSiteMediaPublicUrl, removeSiteMedia, siteMediaPathFromUrl, uploadSiteMedia, validateMediaFile } from '../services/media';
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
  const [authState,setAuthState]=useState<'checking'|'signed_in'|'signed_out'>('checking');

  useEffect(()=>{void getSession().then(session=>setAuthState(session?'signed_in':'signed_out')).catch(()=>setAuthState('signed_out'))},[]);

  if (!trip) return <Navigate to="/packages" replace />;
  if(authState==='checking')return <div className="route-loading">Checking your secure account…</div>;
  if(authState==='signed_out')return <Navigate to={`/login?returnTo=${encodeURIComponent(`/book/${slug}`)}`} replace/>;

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
  const [query]=useSearchParams();
  const [busy, setBusy] = useState(false);
  const [message, setMessage] = useState('');
  const [error, setError] = useState('');

  async function submit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    const values = Object.fromEntries(new FormData(event.currentTarget).entries());
    setBusy(true); setMessage(''); setError('');
    try {
      if (mode === 'login') { const result=await signIn(String(values.email), String(values.password)); const role=await getRole(result.user.id); const requested=query.get('returnTo'); const safeReturn=requested?.startsWith('/')&&!requested.startsWith('//')?requested:null; navigate(['admin','super_admin'].includes(role)?'/admin':safeReturn||'/account'); }
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
  const [profileMessage,setProfileMessage]=useState('');
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
  async function saveProfile(event:FormEvent<HTMLFormElement>){event.preventDefault();setError('');setProfileMessage('');const values=Object.fromEntries(new FormData(event.currentTarget).entries());try{const profile=await updateOwnProfile(String(values.fullName||''),String(values.phone||''));setAccount(current=>({...current,profile}));setProfileMessage('Profile saved.')}catch(caught){setError(caught instanceof Error?caught.message:'Profile could not be saved.')}}
  const tabs=['Overview','My Trips','Upcoming Trips','Booking History','Payments','Invoices','Vouchers','Documents','Profile','Support'];
  return <section className="account-dashboard"><aside><div className="account-mark"><BrandLogo/></div><nav>{tabs.map(tab=><button className={active===tab?'active':''} onClick={()=>setActive(tab)} key={tab}>{tab}</button>)}</nav><button className="account-logout" onClick={async()=>{await signOut();navigate('/login')}}><LogOut size={16}/> Logout</button></aside><main><header><div><span>SECURE CUSTOMER PORTAL</span><h1>Hello, {name}.</h1><p>Your journeys, payments and travel documents — protected and kept together.</p></div></header>{error&&<p className="form-alert">{error}</p>}{active==='Overview'&&<><div className="portal-metrics"><div><b>{upcoming.length}</b><span>Upcoming trips</span></div><div><b>{bookings.length}</b><span>Total bookings</span></div><div><b>{bookings.filter(item=>Number(item.balance_amount)>0).length}</b><span>Balances due</span></div></div><section className="account-section"><div className="account-heading"><div><span>NEXT JOURNEYS</span><h2>Trips in view</h2></div><button onClick={()=>setActive('My Trips')}>View all</button></div>{renderBookings(upcoming.slice(0,3))}</section></>}{active==='My Trips'&&renderBookings(bookings)}{active==='Upcoming Trips'&&renderBookings(upcoming)}{active==='Booking History'&&renderBookings(history)}{active==='Payments'&&(account.payments.length?<div className="account-records">{account.payments.map(item=><article key={String(item.id)}><span className="record-amount">{money(Number(item.amount),String(item.currency))}</span><div><b>{String(item.payment_kind).replaceAll('_',' ')}</b><span>{String(item.status)} · {new Date(String(item.created_at)).toLocaleDateString('en-IN')}</span></div></article>)}</div>:<p className="empty-copy">No payments recorded.</p>)}{active==='Invoices'&&renderFiles(account.invoices)}{active==='Vouchers'&&renderFiles(account.vouchers)}{active==='Documents'&&renderFiles(account.documents)}{active==='Profile'&&<form className="profile-panel profile-form" onSubmit={saveProfile}><UserRound/><div><label>Full name<input name="fullName" required minLength={2} defaultValue={String(account.profile?.full_name||'')}/></label><label>Phone<input name="phone" type="tel" defaultValue={String(account.profile?.phone||'')}/></label><button className="button teal">Save profile</button>{profileMessage&&<p className="form-success" role="status">{profileMessage}</p>}</div></form>}{active==='Support'&&<section className="portal-empty"><span>WE ARE HERE TO HELP</span><h2>Talk to your travel team.</h2><p>Questions about a booking, payment or document? Our team can help with the next step.</p><Link className="button gold" to="/contact">Contact support</Link></section>}</main></section>;
}

type AdminField={key:string;label:string;type?:'text'|'textarea'|'number'|'boolean'|'date'|'datetime-local'|'select'|'image';options?:string[];required?:boolean;folder?:string;multiple?:boolean;storeAs?:'path'|'url'};
type AdminModuleView={label:string;table?:string;description:string;statusField?:string;statuses?:string[];filter?:Record<string,string>;fields?:AdminField[];allowCreate?:boolean;allowDelete?:boolean;idField?:string};
type AdminModuleGroup={label:string;icon:typeof Gauge;modules:string[]};
const commonPublish:AdminField={key:'published',label:'Published',type:'boolean'};
const adminModules: AdminModuleView[] = [
  { label: 'Dashboard', description: 'Operational overview and service configuration.' },
  { label: 'Packages', table: 'tour_packages', description: 'Package content, pricing, availability and publication.',allowCreate:true,fields:[{key:'title',label:'Package name',required:true},{key:'slug',label:'Slug',required:true},{key:'destination_id',label:'Destination ID'},{key:'category',label:'Category',type:'select',options:['domestic','international','strangers_meetup','maharashtra','trek','expedition','weekend','villa','custom']},{key:'is_upcoming',label:'Upcoming trip',type:'boolean'},{key:'duration_days',label:'Days',type:'number'},{key:'duration_nights',label:'Nights',type:'number'},{key:'summary',label:'Summary',type:'textarea'},{key:'description',label:'Description',type:'textarea'},{key:'hero_image',label:'Hero image',type:'image',folder:'packages',storeAs:'url'},{key:'highlights',label:'Highlights JSON',type:'textarea'},{key:'inclusions',label:'Inclusions JSON',type:'textarea'},{key:'exclusions',label:'Exclusions JSON',type:'textarea'},{key:'base_price',label:'Adult price (paise)',type:'number'},{key:'child_price',label:'Child price (paise)',type:'number'},{key:'infant_price',label:'Infant price (paise)',type:'number'},{key:'tax_rate',label:'Tax %',type:'number'},{key:'advance_type',label:'Advance type',type:'select',options:['percentage','fixed']},{key:'advance_value',label:'Advance value',type:'number'},{key:'featured',label:'Featured',type:'boolean'},{key:'trending',label:'Trending',type:'boolean'},commonPublish,{key:'seo_title',label:'SEO title'},{key:'seo_description',label:'SEO description',type:'textarea'}] },
  { label: 'Package Itineraries', table: 'tour_itinerary_days', description: 'Day-by-day package storytelling.',allowCreate:true,fields:[{key:'package_id',label:'Package ID',required:true},{key:'day_number',label:'Day number',type:'number',required:true},{key:'title',label:'Title',required:true},{key:'description',label:'Description',type:'textarea'},{key:'location',label:'Location'}] },
  { label: 'Package Availability', table: 'package_availability', description: 'Dated capacity, overrides and departure status.',allowCreate:true,fields:[{key:'package_id',label:'Package ID',required:true},{key:'travel_date',label:'Travel date',type:'date',required:true},{key:'capacity',label:'Capacity',type:'number',required:true},{key:'reserved',label:'Reserved',type:'number'},{key:'price_override',label:'Price override (paise)',type:'number'},{key:'status',label:'Status',type:'select',options:['open','closed','sold_out']}] },
  { label: 'Package Media', table: 'package_images', description: 'Upload one or several package gallery images from your device.',allowCreate:true,allowDelete:true,fields:[{key:'package_id',label:'Package ID',required:true},{key:'storage_path',label:'Gallery images',type:'image',folder:'package-gallery',storeAs:'path',multiple:true,required:true},{key:'alt_text',label:'Alt text',required:true},{key:'display_order',label:'Starting order',type:'number'},{key:'is_cover',label:'Cover image',type:'boolean'}] },
  { label: 'Destinations', table: 'destinations', description: 'Destination landing pages and travel regions.',allowCreate:true,fields:[{key:'name',label:'Name',required:true},{key:'slug',label:'Slug',required:true},{key:'primary_category',label:'Primary category',type:'select',options:['domestic','international','strangers_meetup']},{key:'region',label:'Region'},{key:'country',label:'Country'},{key:'state',label:'State'},{key:'summary',label:'Summary',type:'textarea'},{key:'description',label:'Description',type:'textarea'},{key:'hero_image',label:'Destination image',type:'image',folder:'destinations',storeAs:'url'},{key:'featured',label:'Featured',type:'boolean'},commonPublish,{key:'seo_title',label:'SEO title'},{key:'seo_description',label:'SEO description',type:'textarea'}] },
  { label: 'Treks', table: 'tour_packages', description: 'Trek inventory from the package catalogue.',filter:{category:'trek'} },
  { label: 'Expeditions', table: 'tour_packages', description: 'Expedition inventory from the package catalogue.',filter:{category:'expedition'} },
  { label: 'Weekend Getaways', table: 'tour_packages', description: 'Short-break inventory and publication.',filter:{category:'weekend'} },
  { label: 'Villas', table: 'tour_packages', description: 'Villa stays and availability.',filter:{category:'villa'} },
  { label: 'Travel Services', table: 'travel_services', description: 'Bookable and enquiry-led ancillary services.',allowCreate:true,fields:[{key:'name',label:'Name',required:true},{key:'slug',label:'Slug',required:true},{key:'category',label:'Category',required:true},{key:'description',label:'Description',type:'textarea'},{key:'service_mode',label:'Mode',type:'select',options:['enquiry','bookable']},{key:'base_price',label:'Base price (paise)',type:'number'},commonPublish] },
  { label: 'Bookings', table: 'bookings', description: 'Booking status, travel dates and payment state.', statusField: 'booking_status', statuses: ['draft','pending_payment','confirmed','cancelled','completed'] },
  { label: 'Customers', table: 'profiles', description: 'Customer accounts. Access remains governed by RLS.' },
  { label: 'Leads / Enquiries', table: 'leads', description: 'Enquiries, source, notes and follow-up state.', statusField: 'status', statuses: ['new','contacted','follow_up','qualified','converted','closed_lost'],fields:[{key:'status',label:'Status',type:'select',options:['new','contacted','follow_up','qualified','converted','closed_lost']},{key:'admin_notes',label:'Admin notes',type:'textarea'}] },
  { label: 'Custom Trip Enquiries', table: 'leads', description: 'Custom itinerary requests and traveller details.' },
  { label: 'Quotations', table: 'quotations', description: 'Versioned quotations and printable customer views.' },
  { label: 'Invoices', table: 'invoices', description: 'Booking invoices and document lifecycle.',statusField:'status',statuses:['draft','issued','void'] },
  { label: 'Vouchers', table: 'vouchers', description: 'Hotel and transport vouchers.',statusField:'status',statuses:['draft','issued','void'] },
  { label: 'Documents', table: 'documents', description: 'Private booking files and signed access.',statusField:'status',statuses:['draft','issued','void'] },
  { label: 'Payments', table: 'payments', description: 'Read-only provider transactions; status changes only after verified payment events.' },
  { label: 'Blogs', table: 'blogs', description: 'Travel journal publishing.',allowCreate:true,fields:[{key:'title',label:'Title',required:true},{key:'slug',label:'Slug',required:true},{key:'excerpt',label:'Excerpt',type:'textarea'},{key:'body_markdown',label:'Article',type:'textarea'},{key:'cover_image',label:'Cover image',type:'image',folder:'blogs',storeAs:'url'},commonPublish] },
  { label: 'Events', table: 'events', description: 'Travel events and registration links.',allowCreate:true,fields:[{key:'title',label:'Title',required:true},{key:'slug',label:'Slug',required:true},{key:'description',label:'Description',type:'textarea'},{key:'starts_at',label:'Starts at',type:'datetime-local'},{key:'ends_at',label:'Ends at',type:'datetime-local'},{key:'location',label:'Location'},{key:'cover_image',label:'Event image',type:'image',folder:'events',storeAs:'url'},{key:'registration_url',label:'Registration URL'},commonPublish] },
  { label: 'Gallery / Media', table: 'gallery_items', description: 'Upload and publish travel photography.',allowCreate:true,allowDelete:true,fields:[{key:'title',label:'Title'},{key:'slug',label:'Slug'},{key:'media_url',label:'Gallery image',type:'image',folder:'gallery',storeAs:'url',required:true},{key:'media_type',label:'Media type',type:'select',options:['image']},{key:'category',label:'Category'},{key:'alt_text',label:'Alt text'},{key:'display_order',label:'Order',type:'number'},commonPublish] },
  { label: 'Testimonials', table: 'testimonials', description: 'Verified traveller stories and optional traveller photography.',allowCreate:true,fields:[{key:'name',label:'Traveller name',required:true},{key:'location',label:'Location'},{key:'quote',label:'Quote',type:'textarea',required:true},{key:'media_url',label:'Traveller image',type:'image',folder:'testimonials',storeAs:'url'},{key:'media_type',label:'Media type',type:'select',options:['text']},commonPublish] },
  { label: 'Awards', table: 'awards', description: 'Verified awards and recognitions.',allowCreate:true,fields:[{key:'title',label:'Title',required:true},{key:'issuer',label:'Issuer'},{key:'description',label:'Description',type:'textarea'},{key:'awarded_on',label:'Award date',type:'date'},{key:'image_url',label:'Award image',type:'image',folder:'awards',storeAs:'url'},commonPublish] },
  { label: 'Reviews', table: 'reviews', description: 'Moderated customer reviews.',fields:[{key:'quote',label:'Review',type:'textarea'},{key:'rating',label:'Rating',type:'number'},{key:'verified',label:'Verified',type:'boolean'},commonPublish] },
  { label: 'FAQs', table: 'faqs', description: 'Frequently asked questions and ordering.',allowCreate:true,fields:[{key:'question',label:'Question',required:true},{key:'answer',label:'Answer',type:'textarea',required:true},{key:'category',label:'Category'},{key:'display_order',label:'Order',type:'number'},commonPublish] },
  { label: 'Newsletter Subscribers', table: 'newsletter_subscribers', description: 'Consent-aware subscriber records.' },
  { label: 'Homepage / CMS', table: 'site_sections', description: 'Homepage ordering, visibility and structured content.',allowCreate:true,fields:[{key:'section_key',label:'Section key',required:true},{key:'title',label:'Title'},{key:'content',label:'Content JSON',type:'textarea'},{key:'display_order',label:'Order',type:'number'},commonPublish] },
  { label: 'Hero banners', table: 'hero_slides', description: 'Homepage hero imagery, calls to action and scheduling.',allowCreate:true,allowDelete:true,fields:[{key:'title',label:'Title',required:true},{key:'subtitle',label:'Subtitle'},{key:'destination_id',label:'Destination ID'},{key:'image_url',label:'Banner image',type:'image',folder:'hero-banners',storeAs:'url',required:true},{key:'alt_text',label:'Alternative text',required:true},{key:'cta_label',label:'CTA label'},{key:'cta_url',label:'CTA URL'},{key:'display_order',label:'Order',type:'number'},commonPublish,{key:'starts_at',label:'Starts at',type:'datetime-local'},{key:'ends_at',label:'Ends at',type:'datetime-local'}] },
  { label: 'Menus', table: 'navigation_items', description: 'Navigation labels, URLs and ordering.',allowCreate:true,fields:[{key:'location',label:'Location',type:'select',options:['header','footer']},{key:'label',label:'Label',required:true},{key:'url',label:'URL',required:true},{key:'parent_id',label:'Parent ID'},{key:'display_order',label:'Order',type:'number'},commonPublish] },
  { label: 'Footer', table: 'site_settings', idField:'key', description: 'Contact and footer configuration.',allowCreate:true,fields:[{key:'key',label:'Setting key',required:true},{key:'value',label:'Value JSON',type:'textarea',required:true}] },
  { label: 'SEO', table: 'seo_entries', description: 'Route metadata, canonical URLs and social cards.',allowCreate:true,fields:[{key:'route',label:'Route',required:true},{key:'title',label:'Title',required:true},{key:'description',label:'Description',type:'textarea',required:true},{key:'canonical_url',label:'Canonical URL'},{key:'og_image',label:'Social image',type:'image',folder:'social',storeAs:'url'},{key:'robots',label:'Robots'}] },
  { label: 'Site Settings', table: 'site_settings', idField:'key', description: 'Provider-safe public configuration.',allowCreate:true,fields:[{key:'key',label:'Setting key',required:true},{key:'value',label:'Value JSON',type:'textarea',required:true}] },
  { label: 'Reports', table: 'report_exports', description: 'Generated operational reports.' },
  { label: 'Audit Logs', table: 'audit_logs', description: 'Immutable privileged-action history.' },
];

const adminModuleGroups:AdminModuleGroup[]=[
  {label:'Overview',icon:Gauge,modules:['Dashboard']},
  {label:'Travel catalogue',icon:Globe2,modules:['Packages','Package Itineraries','Package Availability','Package Media','Destinations','Treks','Expeditions','Weekend Getaways','Villas','Travel Services']},
  {label:'Customers & sales',icon:UsersRound,modules:['Bookings','Customers','Leads / Enquiries','Custom Trip Enquiries','Quotations']},
  {label:'Finance & documents',icon:FileText,modules:['Invoices','Vouchers','Documents','Payments']},
  {label:'Content studio',icon:FileText,modules:['Blogs','Events','Gallery / Media','Testimonials','Awards','Reviews','FAQs','Newsletter Subscribers']},
  {label:'Website',icon:Settings,modules:['Homepage / CMS','Hero banners','Menus','Footer','SEO','Site Settings']},
  {label:'Governance',icon:ShieldCheck,modules:['Reports','Audit Logs']},
];

const displayValue=(value:unknown)=>{
  if(value===null||value===undefined||value==='')return '—';
  if(typeof value==='boolean')return value?'Yes':'No';
  if(typeof value==='object')return JSON.stringify(value);
  return String(value).replaceAll('_',' ');
};

const statusTone=(status:string)=>{
  if(['published','issued','confirmed','completed','success','accepted','ready','open','qualified','converted','verified'].includes(status))return 'positive';
  if(['failed','cancelled','void','closed_lost','expired','sold_out'].includes(status))return 'negative';
  if(['pending','pending_payment','processing','draft','new','queued','follow_up'].includes(status))return 'warning';
  return 'neutral';
};

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
  const [recordLoading,setRecordLoading]=useState(false);
  const [isSaving,setIsSaving]=useState(false);
  const [notice,setNotice]=useState('');
  const [uploadProgress,setUploadProgress]=useState<number|null>(null);
  const [imagePreviews,setImagePreviews]=useState<Record<string,string[]>>({});
  const [removedMedia,setRemovedMedia]=useState<string[]>([]);

  useEffect(() => { void (async () => { try { const session = await getSession(); if (session) setRole(await getRole(session.user.id)); } catch (caught) { setError(caught instanceof Error ? caught.message : 'Admin access could not be verified.'); } finally { setLoading(false); } })(); }, []);
  useEffect(() => { if (!active.table || !['admin','super_admin'].includes(role || '')) { setRecords([]); return; } let current=true;setRecordLoading(true);void (async () => { try { setError(''); const next=await listAdminRecords(active.table!);if(current)setRecords(next); } catch (caught) { if(current)setError(caught instanceof Error ? caught.message : 'Records could not be loaded.'); } finally {if(current)setRecordLoading(false);} })();return()=>{current=false}; }, [active, role]);
  useEffect(()=>{if(active.label==='Dashboard'&&['admin','super_admin'].includes(role||''))void getAdminOverview().then(setOverview).catch(caught=>setError(caught instanceof Error?caught.message:'Dashboard could not be loaded.'))},[active,role]);
  const shown = useMemo(() => { const term = search.toLowerCase().trim(); return records.filter(record=>(!active.filter||Object.entries(active.filter).every(([key,value])=>String(record[key])===value))&&(!term||JSON.stringify(record).toLowerCase().includes(term))); }, [records, search,active]);

  if (loading) return <div className="route-loading">Verifying admin access…</div>;
  if (!appConfig.supabaseConfigured) return <><PageIntro eyebrow="OPERATIONS" title="My Tripon Admin" copy="Protected management for content, bookings, customers and finance."/><section className="portal-shell"><ServiceState>Configure Supabase, apply the production migration and assign an admin role in the protected profiles table. The admin interface will not bypass authorization.</ServiceState></section></>;
  if (!['admin','super_admin'].includes(role || '')) return <section className="access-denied"><ShieldCheck/><h1>Admin access required</h1><p>This route verifies the role stored in the protected profile record, not editable user metadata.</p><Link to="/login">Sign in with an authorized account</Link></section>;

  function openEditor(record:Record<string,unknown>={}){setEditing(record);setError('');setNotice('');setUploadProgress(null);setImagePreviews({});setRemovedMedia([])}
  function closeEditor(){Object.values(imagePreviews).flat().forEach(url=>{if(url.startsWith('blob:'))URL.revokeObjectURL(url)});setEditing(null);setImagePreviews({});setRemovedMedia([]);setUploadProgress(null)}
  function previewFiles(field:AdminField,files:FileList|null){if(!files?.length)return;try{const chosen=Array.from(files);chosen.forEach(validateMediaFile);setError('');setImagePreviews(current=>{(current[field.key]||[]).forEach(url=>{if(url.startsWith('blob:'))URL.revokeObjectURL(url)});return{...current,[field.key]:chosen.map(file=>URL.createObjectURL(file))}});setRemovedMedia(current=>current.filter(key=>key!==field.key))}catch(caught){setImagePreviews(current=>({...current,[field.key]:[]}));setError(caught instanceof Error?caught.message:'The selected image is not valid.')}}
  async function reloadRecords(){if(!active.table)return;setRecordLoading(true);setError('');try{setRecords(await listAdminRecords(active.table))}catch(caught){setError(caught instanceof Error?caught.message:'Records could not be loaded.')}finally{setRecordLoading(false)}}
  async function updateStatus(id: string, value: string) { if (!active.table || !active.statusField) return; const idField=active.idField||'id'; try { setError('');const updated = await updateAdminRecord(active.table, id, { [active.statusField]: value },idField); setRecords(current => current.map(item => String(item[idField]) === id ? updated : item));setNotice('Status updated.'); } catch (caught) { setError(caught instanceof Error ? caught.message : 'Status update failed.'); } }
  async function deleteMediaRecord(record:Record<string,unknown>){
    if(!active.table||!active.allowDelete)return;
    const idField=active.idField||'id';const id=String(record[idField]||'');if(!id)return;
    const title=String(record.title||record.name||record.alt_text||'this image');
    if(!window.confirm(`Remove ${title}? This deletes the catalogue record and its managed Storage object.`))return;
    setError('');setNotice('');
    try{
      await deleteAdminRecord(active.table,id,idField);
      setRecords(current=>current.filter(item=>String(item[idField])!==id));
      const mediaField=active.fields?.find(field=>field.type==='image');const mediaValue=mediaField?String(record[mediaField.key]||''):'';
      if(mediaValue&&(siteMediaPathFromUrl(mediaValue)||!mediaValue.startsWith('http'))){
        try{await removeSiteMedia(mediaValue);setNotice('Image and catalogue record removed.')}catch{setNotice('Catalogue record removed. The Storage object could not be cleaned up; retry it from Supabase Storage.')}
      }else setNotice('Catalogue record removed.');
    }catch(caught){setError(caught instanceof Error?caught.message:'Record could not be removed.')}
  }
  async function saveEditor(event:FormEvent<HTMLFormElement>){
    event.preventDefault();if(!active.table||!active.fields||!editing||isSaving)return;
    const form=new FormData(event.currentTarget);const values:Record<string,unknown>={};const idField=active.idField||'id';
    const editingId=editing[idField];const uploaded:{path:string;value:string;field:AdminField}[]=[];
    setIsSaving(true);setError('');setNotice('');setUploadProgress(null);
    try{
      for(const field of active.fields){
        if(field.type==='image'){
          const files=form.getAll(field.key).filter((value):value is File=>value instanceof File&&value.size>0);
          if(files.length){
            files.forEach(validateMediaFile);
            for(let index=0;index<files.length;index++){
              const uploadedImage=await uploadSiteMedia(files[index],{folder:field.folder||active.table,onProgress:progress=>setUploadProgress(Math.round(((index+progress/100)/files.length)*100))});
              uploaded.push({path:uploadedImage.path,value:field.storeAs==='path'?uploadedImage.path:uploadedImage.publicUrl,field});
            }
            values[field.key]=field.multiple?uploaded.filter(item=>item.field.key===field.key).map(item=>item.value):uploaded.length?uploaded[uploaded.length-1].value:undefined;
          }else if(removedMedia.includes(field.key))values[field.key]=null;
          else if(!editingId&&field.required)throw new Error(`${field.label} is required.`);
          continue;
        }
        const value=form.get(field.key);
        if(field.type==='boolean')values[field.key]=value==='on';
        else if(field.type==='number'){if(value!==''&&value!==null)values[field.key]=Number(value);else if(editingId)values[field.key]=null}
        else if(field.type==='datetime-local'){if(value)values[field.key]=new Date(String(value)).toISOString();else if(editingId)values[field.key]=null}
        else if(['highlights','inclusions','exclusions','content','schema_json','value'].includes(field.key)){try{values[field.key]=JSON.parse(String(value||(['content','schema_json','value'].includes(field.key)?'{}':'[]')))}catch{throw new Error(`${field.label} must be valid JSON.`)}}
        else {const normalized=String(value||'');if(normalized)values[field.key]=normalized;else if(editingId)values[field.key]=null}
      }
      const multipleField=active.fields.find(field=>field.type==='image'&&field.multiple&&Array.isArray(values[field.key]));
      const oldMedia=active.fields.filter(field=>field.type==='image'&&(removedMedia.includes(field.key)||values[field.key])).map(field=>String(editing[field.key]||'')).filter(Boolean);
      if(multipleField&&!editingId){
        const paths=values[multipleField.key] as string[];const baseOrder=Number(values.display_order||0);const created:Record<string,unknown>[]=[];
        try{for(let index=0;index<paths.length;index++){const next={...values,[multipleField.key]:paths[index],display_order:baseOrder+index};created.push(await createAdminRecord(active.table,next))}}
        catch(caught){for(const record of created)await deleteAdminRecord(active.table,String(record[idField]),idField).catch(()=>undefined);throw caught}
        setRecords(current=>[...created,...current]);
      }else{
        if(multipleField)values[multipleField.key]=(values[multipleField.key] as string[])[0];
        const saved=editingId?await updateAdminRecord(active.table,String(editingId),values,idField):await createAdminRecord(active.table,values);
        setRecords(current=>editingId?current.map(item=>String(item[idField])===String(editingId)?saved:item):[saved,...current]);
      }
      for(const previous of oldMedia){if(siteMediaPathFromUrl(previous)||!previous.startsWith('http'))await removeSiteMedia(previous).catch(()=>undefined)}
      setNotice(multipleField&&!editingId?`${(values[multipleField.key] as string[]).length} images uploaded and saved.`:'Changes saved successfully.');closeEditor();
    }catch(caught){
      for(const item of uploaded)await removeSiteMedia(item.path).catch(()=>undefined);
      setError(caught instanceof Error?caught.message:'Record could not be saved.');
    }finally{setIsSaving(false);setUploadProgress(null)}
  }
  const dashboard=<div className="admin-dashboard">{overview?<><div className="admin-overview"><div><b>{overview.counts.bookings}</b><span>Total bookings</span></div><div><b>{overview.counts.leads}</b><span>Total leads</span></div><div><b>{overview.counts.pendingPayments}</b><span>Pending payments</span></div></div><div className="admin-dashboard-grid"><section><div className="account-heading"><div><span>RECENT ACTIVITY</span><h2>Bookings</h2></div></div>{overview.bookings.length?overview.bookings.map(item=><article className="admin-feed" key={String(item.id)}><div><b>{String(item.reference)}</b><span>{String(item.booking_status).replaceAll('_',' ')}</span></div><small>{new Date(String(item.travel_date)).toLocaleDateString('en-IN')} · {money(Number(item.balance_amount),String(item.currency))} due</small></article>):<p className="empty-copy">No bookings yet.</p>}</section><section><div className="account-heading"><div><span>SALES PIPELINE</span><h2>Recent leads</h2></div></div>{overview.leads.length?overview.leads.map(item=><article className="admin-feed" key={String(item.id)}><div><b>{String(item.name)}</b><span>{String(item.status).replaceAll('_',' ')}</span></div><small>{String(item.destination||'Destination not selected')}</small></article>):<p className="empty-copy">No leads yet.</p>}</section><section><div className="account-heading"><div><span>OPERATIONS</span><h2>Upcoming departures</h2></div></div>{overview.departures.length?overview.departures.map(item=><article className="admin-feed" key={String(item.id)}><div><b>{new Date(String(item.travel_date)).toLocaleDateString('en-IN')}</b><span>{String(item.status)}</span></div><small>{Number(item.reserved)}/{Number(item.capacity)} places reserved</small></article>):<p className="empty-copy">No dated departures configured.</p>}</section><section className="admin-alerts"><span>OPERATIONAL STATUS</span><h2>Provider readiness</h2><p>Supabase authorization is active. Payment and communication adapters remain gracefully unavailable until their server-only credentials are configured.</p><b>{appConfig.paymentProvider}</b></section></div></>:<div className="route-loading">Loading live operations…</div>}</div>;
  const idField=active.idField||'id';
  return <section className="admin-shell">
    <aside className={navOpen?'nav-open':''}>
      <div className="admin-brand"><BrandLogo/><button onClick={()=>setNavOpen(value=>!value)} aria-label="Toggle admin navigation" aria-expanded={navOpen}>{navOpen?<X/>:<Menu/>}</button></div>
      <div className="admin-workspace"><span>TRAVEL MANAGEMENT</span><b>Operations workspace</b></div>
      <nav className={navOpen?'open':''} aria-label="Admin navigation">{adminModuleGroups.map(group=>{const Icon=group.icon;return <section key={group.label} className="admin-nav-group"><h2><Icon size={14}/>{group.label}</h2>{group.modules.map(label=>{const module=adminModules.find(item=>item.label===label);return module?<button className={active.label===module.label?'active':''} aria-current={active.label===module.label?'page':undefined} key={module.label} onClick={()=>{setActive(module);setSearch('');closeEditor();setNotice('');setNavOpen(false)}}>{module.label}<span>›</span></button>:null})}</section>})}</nav>
      <div className="admin-user"><span className="admin-avatar">{role==='super_admin'?'SA':'AD'}</span><div><b>{role==='super_admin'?'Super administrator':'Administrator'}</b><span>Protected session</span></div></div>
      <button className="account-logout" onClick={async()=>{await signOut();window.location.assign('/login')}}><LogOut size={16}/> Sign out</button>
    </aside>
    <main>
      <div className="admin-topbar"><div><span className="admin-live-dot"/>Live workspace</div><div><Link to="/" target="_blank">View website</Link><span className="admin-role-badge"><ShieldCheck size={14}/>{role?.replaceAll('_',' ')}</span></div></div>
      <header className="admin-header"><div><span>ADMINISTRATION / {active.label.toUpperCase()}</span><h1>{active.label}</h1><p>{active.description}</p></div><div className="admin-header-actions">{active.table&&<button className="admin-icon-button" onClick={()=>void reloadRecords()} disabled={recordLoading} aria-label="Refresh records"><RefreshCw className={recordLoading?'spinning':''} size={17}/></button>}{active.allowCreate&&<button className="button gold" onClick={()=>openEditor()}><Plus size={16}/> New record</button>}</div></header>
      {error&&<p className="form-alert admin-message" role="alert">{error}<button onClick={()=>setError('')} aria-label="Dismiss error"><X size={14}/></button></p>}
      {notice&&<p className="form-success admin-message" role="status">{notice}<button onClick={()=>setNotice('')} aria-label="Dismiss message"><X size={14}/></button></p>}
      {active.label==='Dashboard'?dashboard:<>
        {active.fields&&editing&&<form className="admin-editor" onSubmit={saveEditor}>
          <header><div><span>{editing[idField]?'EDIT EXISTING RECORD':'CREATE NEW RECORD'}</span><h2>{editing[idField]?String(editing.title||editing.name||editing.reference||'Edit record'):`New ${active.label.replace(/s$/,'').toLowerCase()}`}</h2></div><button type="button" onClick={closeEditor} aria-label="Close editor"><X size={18}/></button></header>
          <div>{active.fields.map(field=>{
            const isJson=['highlights','inclusions','exclusions','content','schema_json','value'].includes(field.key);
            const initial=isJson?JSON.stringify(editing[field.key]??(['content','schema_json','value'].includes(field.key)?{}:[]),null,2):field.type==='datetime-local'&&editing[field.key]?new Date(String(editing[field.key])).toISOString().slice(0,16):String(editing[field.key]??'');
            if(field.type==='image'){
              const existing=String(editing[field.key]||'');let existingPreview='';
              if(existing&&!removedMedia.includes(field.key)){try{existingPreview=field.storeAs==='path'?getSiteMediaPublicUrl(existing):existing}catch{existingPreview=''}}
              const previews=imagePreviews[field.key]||(!removedMedia.includes(field.key)&&existingPreview?[existingPreview]:[]);
              return <div className="admin-media-field wide" key={field.key}><div className="admin-field-label"><b>{field.label}</b><span>JPG, PNG or WebP · up to 8 MB{field.multiple?' each':''}</span></div>{previews.length>0&&<div className="admin-media-previews">{previews.map((url,index)=><img key={`${url}-${index}`} src={url} alt={`${field.label} preview ${index+1}`}/>)}</div>}<div className="admin-media-actions"><label htmlFor={`media-${field.key}`}>{previews.length?'Replace image':'Choose from device'}</label><input id={`media-${field.key}`} className="visually-hidden" name={field.key} type="file" accept="image/jpeg,image/png,image/webp" multiple={field.multiple&&!editing[idField]} required={field.required&&!editing[idField]} onChange={event=>previewFiles(field,event.target.files)}/>{previews.length>0&&(!field.required||!editing[idField])&&<button type="button" onClick={()=>{const input=document.getElementById(`media-${field.key}`) as HTMLInputElement|null;if(input)input.value='';setImagePreviews(current=>({...current,[field.key]:[]}));if(existing)setRemovedMedia(current=>[...new Set([...current,field.key])])}}>Remove</button>}</div></div>
            }
            return <label key={field.key} className={field.type==='textarea'?'wide':''}><span>{field.label}</span>{field.type==='textarea'?<textarea name={field.key} defaultValue={initial} required={field.required}/>:field.type==='select'?<select name={field.key} defaultValue={String(editing[field.key]??field.options?.[0]??'')}>{field.options?.map(option=><option key={option} value={option}>{option.replaceAll('_',' ')}</option>)}</select>:field.type==='boolean'?<span className="admin-switch"><input name={field.key} type="checkbox" defaultChecked={Boolean(editing[field.key])}/><i/><em>Enabled</em></span>:<input name={field.key} type={field.type==='number'?'number':field.type==='date'?'date':field.type==='datetime-local'?'datetime-local':'text'} defaultValue={initial} required={field.required}/>}</label>
          })}</div>
          {uploadProgress!==null&&<div className="admin-upload-progress"><span><b>Uploading securely</b>{uploadProgress}%</span><i><b style={{width:`${uploadProgress}%`}}/></i></div>}
          <footer><button type="button" className="admin-secondary-button" onClick={closeEditor}>Cancel</button><button className="button teal" disabled={isSaving}>{isSaving?'Saving…':'Save changes'}</button></footer>
        </form>}
        <div className="admin-tools"><label><Search size={17}/><input value={search} onChange={event=>setSearch(event.target.value)} placeholder={`Search ${active.label.toLowerCase()}`} aria-label={`Search ${active.label}`}/>{search&&<button onClick={()=>setSearch('')} aria-label="Clear search"><X size={14}/></button>}</label><span>{shown.length} record{shown.length===1?'':'s'}</span></div>
        <div className={`admin-table-wrap ${recordLoading?'is-loading':''}`} aria-busy={recordLoading}>{recordLoading?<div className="admin-table-loading"><RefreshCw className="spinning"/>Loading live records…</div>:<table><thead><tr><th>Record</th><th>Details</th><th>Status</th><th>Updated</th><th><span className="visually-hidden">Actions</span></th></tr></thead><tbody>{shown.map(record=>{
          const id=String(record[idField]||'');const title=String(record.title||record.name||record.reference||record.question||record.email||record.document_number||record.invoice_number||record.voucher_number||id);const status=String(record[active.statusField||'status']??(record.published?'published':'draft'));const mediaField=active.fields?.find(field=>field.type==='image');const rawImage=mediaField?String(record[mediaField.key]||''):'';let image='';if(rawImage){try{image=mediaField?.storeAs==='path'?getSiteMediaPublicUrl(rawImage):rawImage}catch{image=''}}
          return <tr key={id}><td data-label="Record"><div className="admin-record-title">{image?<img src={image} alt=""/>:<span>{title.slice(0,1).toUpperCase()}</span>}<div><b>{title}</b><small>{id}</small></div></div></td><td data-label="Details">{displayValue(record.slug||record.destination||record.email||record.phone||record.travel_date)}</td><td data-label="Status">{active.statusField&&active.statuses?<select className={`admin-status-select ${statusTone(status)}`} aria-label={`Status for ${title}`} value={status} onChange={event=>void updateStatus(id,event.target.value)}>{active.statuses.map(value=><option value={value} key={value}>{value.replaceAll('_',' ')}</option>)}</select>:<span className={`admin-status ${statusTone(status)}`}>{displayValue(status)}</span>}</td><td data-label="Updated">{record.updated_at?new Date(String(record.updated_at)).toLocaleDateString('en-IN',{day:'2-digit',month:'short',year:'numeric'}):'—'}</td><td data-label="Action"><div className="admin-row-actions">{active.fields&&<button onClick={()=>openEditor(record)}>Edit</button>}{typeof record.published==='boolean'&&<button onClick={async()=>{try{setError('');const updated=await updateAdminRecord(active.table!,id,{published:!record.published},idField);setRecords(current=>current.map(item=>String(item[idField])===id?updated:item));setNotice(record.published?'Record unpublished.':'Record published.')}catch(caught){setError(caught instanceof Error?caught.message:'Publish update failed.')}}}>{record.published?'Unpublish':'Publish'}</button>}{active.allowDelete&&<button className="danger" onClick={()=>void deleteMediaRecord(record)}>Delete</button>}</div></td></tr>
        })}{!shown.length&&<tr><td colSpan={5}><div className="admin-empty"><Search/><b>{search?'No matching records':'No records yet'}</b><span>{search?'Try a different search term.':'New operational data will appear here as it is created.'}</span></div></td></tr>}</tbody></table>}</div>
      </>}
    </main>
  </section>;
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

export function ContentIndex({ kind }: { kind: 'journal' | 'events' | 'faqs' }) { const publicContent=usePublicContent(); const content = kind === 'journal' ? { eyebrow:'TRAVEL JOURNAL', title:'Notes for the road.', copy:'Destination guides and seasonal ideas published from the CMS.', items:publicContent.blogs } : kind === 'events' ? { eyebrow:'EVENTS', title:'Meet us along the way.', copy:'Verified travel events appear here when published.', items:publicContent.events } : { eyebrow:'GOOD TO KNOW', title:'Questions, answered.', copy:'Practical answers before you travel.', items:publicContent.faqs }; return <><PageIntro eyebrow={content.eyebrow} title={content.title} copy={content.copy}/><section className="content-index">{content.items.map((item, index) => <article className={item.image?'has-image':''} key={item.title}>{item.image?<img src={item.image} alt="" loading="lazy"/>:<span>0{index + 1}</span>}<div><h2>{item.title}</h2><p>{item.copy}</p></div></article>)}</section></>; }
