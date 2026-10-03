import { useEffect, useState, type FormEvent, type ComponentType } from 'react';
import { Link, useNavigate } from 'react-router-dom';
import { ArrowDown, ArrowRight, ArrowUpRight, ChevronLeft, ChevronRight, Clock3, MapPin, Play } from 'lucide-react';
import { destinations, gallery, packages, photos } from './data';

type FormProps = { compact?: boolean };
const heroSlides = [
  { name:'Kashmir', region:'NORTH INDIA · THE HIMALAYAS', title:<>Find your<br/><em>kind of beautiful.</em></>, note:'Lake mornings. Mountain air. A little more time to take it all in.', image:photos.kashmir, coords:'34.0837° N  ·  74.7973° E' },
  { name:'Bali', region:'INDONESIA · ISLAND LIFE', title:<>Slow down.<br/><em>You’re somewhere special.</em></>, note:'Temple courtyards, green hills and the freedom to follow the day.', image:photos.bali, coords:'08.3405° S  ·  115.0920° E' },
  { name:'Kerala', region:'SOUTH INDIA · BACKWATERS', title:<>Journeys that<br/><em>stay with you.</em></>, note:'Tea-scented hills, old harbour lanes and a quieter kind of holiday.', image:photos.kerala, coords:'10.1632° N  ·  76.6413° E' }
];

const travelStyles = [
  { title:'For two', label:'Honeymoon & couples', image:photos.couple, text:'Unhurried days, thoughtful details, time together.' },
  { title:'For everyone', label:'Family holidays', image:photos.family, text:'A good pace for little legs and long conversations.' },
  { title:'For the curious', label:'Culture & heritage', image:photos.local, text:'Local flavours, old streets and stories behind the place.' },
  { title:'For the open road', label:'Adventure & outdoors', image:photos.mountains, text:'Fresh air, changing landscapes and room to roam.' },
  { title:'For the shoreline', label:'Beach escapes', image:photos.beach, text:'Salt air, warm light and nowhere else to be.' },
  { title:'For farther away', label:'International journeys', image:photos.europe, text:'A new country, brought together around your interests.' }
];

const journal = [
  { title:'A slower way through Kerala', category:'FIELD NOTES · SOUTH INDIA', image:photos.boat, to:'/destinations/kerala' },
  { title:'What to leave room for in Kashmir', category:'PLACES · THE HIMALAYAS', image:photos.kashmir, to:'/destinations/kashmir' },
  { title:'Bali beyond the first picture', category:'FIELD NOTES · INDONESIA', image:photos.bali, to:'/destinations/bali' }
];

export default function HomeExperience({ EnquiryForm }: { EnquiryForm: ComponentType<FormProps> }) {
  const [slide, setSlide] = useState(0);
  const [activeStyle, setActiveStyle] = useState(0);
  const [destination, setDestination] = useState('');
  const [month, setMonth] = useState('');
  const [travellers, setTravellers] = useState('2');
  const [style, setStyle] = useState('');
  const navigate = useNavigate();

  useEffect(() => {
    if (window.matchMedia('(prefers-reduced-motion: reduce)').matches) return;
    const timer = window.setInterval(() => setSlide(current => (current + 1) % heroSlides.length), 8000);
    return () => window.clearInterval(timer);
  }, []);

  function findTrip(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    const params = new URLSearchParams({ month, travellers, style });
    if (destination) navigate(`/destinations/${destination}?${params.toString()}`);
    else navigate(`/packages?${params.toString()}`);
  }

  const current = heroSlides[slide];
  const featured = destinations.find(item => item.slug === 'kashmir')!;
  const smallerDestinations = ['kerala','bali','dubai','thailand','maldives','rajasthan'].map(slug => destinations.find(item => item.slug === slug)!).filter(Boolean);
  const featuredPackages = packages.slice(0, 3);

  return <>
    <section className="cinema-hero" aria-label="Featured destinations">
      {heroSlides.map((item, index) => <img key={item.name} className={`cinema-image ${slide === index ? 'is-current' : ''}`} src={item.image} alt={`${item.name} landscape`} fetchPriority={index === 0 ? 'high' : undefined} loading={index === 0 ? 'eager' : 'lazy'}/>) }
      <div className="cinema-scrim"/>
      <div className="cinema-copy" key={current.name}>
        <span className="cinema-kicker"><i/> {current.region}</span>
        <h1>{current.title}</h1>
        <p>{current.note}</p>
        <div className="cinema-actions"><Link to="/packages" className="button gold">Explore journeys <ArrowRight size={17}/></Link><Link to="/contact" className="cinema-plan">Plan my trip <ArrowUpRight size={16}/></Link></div>
      </div>
      <div className="cinema-location"><MapPin size={15}/><span>{current.name.toUpperCase()}</span><i/>{current.coords}</div>
      <div className="cinema-controls"><span>0{slide + 1} <i/> 0{heroSlides.length}</span><button onClick={() => setSlide((slide + heroSlides.length - 1) % heroSlides.length)} aria-label="Previous destination"><ChevronLeft/></button><button onClick={() => setSlide((slide + 1) % heroSlides.length)} aria-label="Next destination"><ChevronRight/></button><div className="cinema-dots">{heroSlides.map((item,index)=><button key={item.name} aria-label={`Show ${item.name}`} aria-current={slide===index?'true':undefined} onClick={()=>setSlide(index)}/>)}</div></div>
      <a className="cinema-scroll" href="#welcome"><ArrowDown size={15}/> DISCOVER THE JOURNEY</a>
    </section>

    <form className="trip-finder" onSubmit={findTrip} aria-label="Find a holiday">
      <div className="finder-heading"><span>START WITH A PLACE</span><b>Where do you want to go?</b></div>
      <label><span>Destination</span><select value={destination} onChange={event=>setDestination(event.target.value)}><option value="">Anywhere you like</option>{destinations.map(item=><option key={item.slug} value={item.slug}>{item.name}</option>)}</select></label>
      <label><span>Travel month</span><select value={month} onChange={event=>setMonth(event.target.value)}><option value="">I’m flexible</option>{['January','February','March','April','May','June','July','August','September','October','November','December'].map(value=><option key={value}>{value}</option>)}</select></label>
      <label><span>Travellers</span><select value={travellers} onChange={event=>setTravellers(event.target.value)}>{['1','2','3','4','5','6+'].map(value=><option key={value} value={value}>{value} {value==='1'?'traveller':'travellers'}</option>)}</select></label>
      <label><span>Travel style</span><select value={style} onChange={event=>setStyle(event.target.value)}><option value="">Show me around</option>{['Family holiday','Couples','Culture & heritage','Adventure','Beach escape'].map(value=><option key={value}>{value}</option>)}</select></label>
      <button className="button teal">Find my holiday <ArrowRight size={16}/></button>
    </form>

    <section className="welcome-editorial" id="welcome">
      <div className="welcome-copy"><span className="section-overline">EXPLORE <i>•</i> EXPERIENCE <i>•</i> ENJOY</span><h2>We don’t just plan trips.<br/><em>We help shape the stories<br/>you’ll bring home.</em></h2><p>Somewhere new has a way of staying with you. We bring the route, the details and the breathing room together around the holiday you want to have.</p><Link to="/about" className="line-link">Meet My Tripon Travel <ArrowRight size={15}/></Link><span className="welcome-signature">My Tripon Travel <i>·</i> Delhi, India</span></div>
      <div className="welcome-images"><img className="welcome-main" src={photos.traveller} alt="Two travellers sharing a view on the road" loading="lazy"/><img className="welcome-inset" src={photos.kerala} alt="Quiet morning on Kerala’s backwaters" loading="lazy"/><span className="welcome-image-caption">A JOURNEY SHAPED AROUND YOU</span></div>
    </section>

    <div className="destination-ticker" aria-label="Destinations"><div className="ticker-track">{[0,1].map(loop=><span key={loop} aria-hidden={loop===1}>{['KASHMIR','KERALA','DUBAI','BALI','THAILAND','MALDIVES','RAJASTHAN','EUROPE'].map(place=><b key={place}>{place}<i>✦</i></b>)}</span>)}</div></div>

    <section className="world-section section-pad">
      <div className="world-heading"><div><span className="section-overline">PLACES TO GO, STORIES TO FIND</span><h2>The world is<br/><em>waiting.</em></h2></div><div><p>Where would you like to begin? Start with a place that’s been on your mind — we’ll help with the rest.</p><Link to="/destinations" className="line-link">All destinations <ArrowRight size={15}/></Link></div></div>
      <div className="world-mosaic"><Link to={`/destinations/${featured.slug}`} className="world-tile world-feature"><img src={featured.image} alt="Mountain scenery in Kashmir" loading="lazy"/><span className="world-index">01 / INDIA</span><div><small>THE HIMALAYAS</small><h3>Kashmir</h3><b>Explore <ArrowUpRight size={16}/></b></div></Link>
        {smallerDestinations.map((item,index)=><Link key={item.slug} to={`/destinations/${item.slug}`} className={`world-tile world-small world-${item.slug}`}><img src={item.image} alt={item.name} loading="lazy"/><div><small>{item.label}</small><h3>{item.name}</h3><b><ArrowUpRight size={15}/></b></div></Link>)}
      </div>
    </section>

    <section className="journeys-section section-pad">
      <div className="world-heading journeys-heading"><div><span className="section-overline">HANDPICKED JOURNEYS</span><h2>Thoughtfully planned.<br/><em>Beautifully experienced.</em></h2></div><div><p>Good routes give a trip its shape — and leave enough space for the moments you didn’t plan.</p><Link to="/packages" className="line-link">View all journeys <ArrowRight size={15}/></Link></div></div>
      <div className="journey-mosaic">{featuredPackages.map((item,index)=><Link to={`/packages/${item.slug}`} className={`journey-feature journey-${index+1}`} key={item.slug}><img src={item.image} alt={`${item.place} journey`} loading="lazy"/><span className="journey-number">0{index+1} / JOURNEY</span><div className="journey-detail"><div><small>{item.place.toUpperCase()} <i>·</i> {item.duration.toUpperCase()}</small><h3>{item.title}</h3><p>{item.route}</p></div><span className="journey-arrow"><ArrowUpRight/></span></div></Link>)}</div>
    </section>

    <section className="trending-strip"><div><span className="section-overline">A PLACE ON YOUR MIND?</span><b>Trending now</b></div>{[['Kashmir',photos.kashmir,'Hills'],['Bali',photos.bali,'Island life'],['Dubai',photos.dubai,'City & desert'],['Kerala',photos.kerala,'Backwaters'],['Thailand',photos.thailand,'Culture']].map(([name,image,label])=><Link to={`/destinations/${String(name).toLowerCase()}`} key={name}><img src={image} alt="" loading="lazy"/><span><small>{label}</small><b>{name}</b></span><ArrowUpRight size={14}/></Link>)}</section>

    <section className="travel-style-section section-pad" id="experiences">
      <div className="style-heading"><span className="section-overline">FIND YOUR KIND OF AWAY</span><h2>Not just places.<br/><em>Ways to travel.</em></h2><p>Start with how you want the trip to feel. We’ll help find the place and pace to match.</p></div>
      <div className="style-visual"><img key={travelStyles[activeStyle].image} src={travelStyles[activeStyle].image} alt={travelStyles[activeStyle].label} loading="lazy"/><div className="style-image-caption"><small>YOUR TRIP, YOUR PACE</small><h3>{travelStyles[activeStyle].title}</h3><p>{travelStyles[activeStyle].text}</p></div></div>
      <div className="style-list">{travelStyles.map((item,index)=><Link to="/contact" key={item.label} onMouseEnter={()=>setActiveStyle(index)} onFocus={()=>setActiveStyle(index)} className={activeStyle===index?'is-active':''}><span>0{index+1}</span><b>{item.label}</b><ArrowUpRight size={17}/></Link>)}</div>
    </section>

    <section className="itinerary-feature">
      <div className="itinerary-feature-photo"><img src={photos.kerala} alt="Traditional houseboat on Kerala’s backwaters" loading="lazy"/><span>ALLEPPEY, KERALA · SOUTH INDIA</span></div>
      <div className="itinerary-feature-copy"><span className="section-overline">ONE JOURNEY. MANY STORIES.</span><div className="itinerary-duration">06 <small>DAYS / 05 NIGHTS</small></div><h2>Backwaters<br/><em>& beyond.</em></h2><p>Tea-scented hills, spice-country roads and a softer landing by the water. Here’s one way six days in Kerala could unfold.</p><div className="itinerary-route">{[['01','Kochi','Find your feet in the old harbour quarter.'],['02','Munnar','Climb into tea country and cool mountain air.'],['04','Thekkady','A slower day among spice gardens and forest edges.'],['06','Alleppey','Finish with a quiet backwater evening.']].map(([day,place,desc])=><div key={day}><i/><span>{day}</span><b>{place}</b><small>{desc}</small></div>)}</div><Link to="/packages/kerala-backwaters" className="button cream">View the full itinerary <ArrowRight size={16}/></Link></div>
    </section>

    <section className="cinema-break" style={{backgroundImage:`linear-gradient(90deg,rgba(11,38,45,.6),rgba(11,38,45,.12)),url(${photos.mountains})`}}><div><span className="section-overline">EXPLORE · EXPERIENCE · ENJOY</span><h2>Go where you<br/><em>feel most alive.</em></h2><Link to="/contact" className="cinema-plan">Start planning <ArrowUpRight size={16}/></Link></div><span className="cinema-break-note">SOMEWHERE NEW IS CLOSER THAN YOU THINK</span></section>

    <section className="traveller-wall section-pad"><div className="world-heading"><div><span className="section-overline">TRAVEL LOOKS BETTER WHEN IT’S REAL</span><h2>Little moments.<br/><em>Long afterglow.</em></h2></div><div><p>Shared views, new rituals and familiar faces in unfamiliar places.</p><Link to="/gallery" className="line-link">See more travel stories <ArrowRight size={15}/></Link></div></div><div className="memory-wall">{gallery.slice(0,7).map((image,index)=><Link to="/gallery" className={`memory memory-${index+1}`} key={image}><img src={image} alt={['Travellers taking in the view','Houseboat on the Kerala backwaters','A couple on a trip together','Taj Mahal at sunrise','Family outdoors on holiday','Local culture and place','Coastal escape'][index]} loading="lazy"/><span>{['KASHMIR · WITH FRIENDS','KERALA · SLOW MORNINGS','A LITTLE TIME FOR TWO','AGRA · FIRST LIGHT','FAMILY DAYS','CULTURE & PLACE','BY THE WATER'][index]}</span></Link>)}</div><Link to="/gallery" className="line-link wall-link">See more travel stories <ArrowRight size={15}/></Link></section>

    <section className="video-stories"><div className="video-heading"><span className="section-overline">FROM THE PEOPLE WHO WENT</span><h2>Stories you can<br/><em>hear and feel.</em></h2><p>A place for traveller films, voices and the moments behind the photos. The previews here are illustrative placeholders.</p></div><div className="video-feature"><img src={photos.traveller} alt="Traveller story preview" loading="lazy"/><Link to="/testimonials" aria-label="Explore traveller stories" className="video-play"><Play fill="currentColor"/></Link><span>TRAVELLER STORY · DEMO PREVIEW</span><div><small>NOTES FROM THE ROAD</small><h3>A different view of the journey</h3></div></div><div className="video-list">{[[photos.couple,'A few days made for two','COUPLES · DEMO PREVIEW'],[photos.family,'Out there together','FAMILY · DEMO PREVIEW']].map(([image,title,label])=><Link to="/testimonials" key={title}><img src={image} alt="" loading="lazy"/><span><small>{label}</small><b>{title}</b></span><Play size={15}/></Link>)}</div></section>

    <section className="why-editorial section-pad"><div className="why-statement"><span className="section-overline">THE MY TRIPON APPROACH</span><h2>Your holiday<br/>deserves more<br/><em>than a template.</em></h2><img src={photos.local} alt="A glimpse of local life on the road" loading="lazy"/><p>Good planning starts with listening. Then it brings the details together around your people, your pace and what you’d like to discover.</p><Link to="/about" className="line-link">A little about our approach <ArrowRight size={15}/></Link></div><div className="why-list">{[['01','Trips shaped around you'],['02','Thoughtful itinerary planning'],['03','Support through your journey'],['04','Domestic & international experiences']].map(([num,title])=><div key={num}><span>{num}</span><h3>{title}</h3><ArrowUpRight size={17}/></div>)}</div></section>

    <section className="recognition-band"><div className="recognition-seal">MT</div><div><span className="section-overline">RECOGNITION & MILESTONES</span><h2>A space for the work<br/><em>worth recognising.</em></h2><p>Verified awards and milestones will be shared here as they are provided.</p></div><Link to="/awards" className="line-link">Our honours <ArrowRight size={15}/></Link><span className="recognition-index">01 / VERIFIED CONTENT</span></section>

    <section className="journal-editorial section-pad"><div className="world-heading"><div><span className="section-overline">THE TRIPON JOURNAL</span><h2>For the curious<br/><em>and the almost-ready.</em></h2></div><div><p>Small notes about places, seasons and the details that help a trip take shape.</p><Link to="/destinations" className="line-link">Explore the places <ArrowRight size={15}/></Link></div></div><div className="journal-featured"><Link to={journal[0].to} className="journal-lead"><img src={journal[0].image} alt="Traditional boat in Kerala" loading="lazy"/><span>{journal[0].category}</span><h3>{journal[0].title}</h3><b>Read the field note <ArrowUpRight size={15}/></b></Link><div className="journal-secondary">{journal.slice(1).map(story=><Link to={story.to} key={story.title}><img src={story.image} alt="" loading="lazy"/><span><small>{story.category}</small><b>{story.title}</b><i>Read the note <ArrowUpRight size={14}/></i></span></Link>)}</div></div></section>

    <section className="enquiry-editorial" id="plan"><div className="enquiry-image"><img src={photos.boat} alt="A quiet journey on the water" loading="lazy"/><div><span className="section-overline">A GOOD PLACE TO START</span><h2>Let’s plan<br/><em>something amazing.</em></h2><p>Tell us a little about the trip you have in mind. We’ll help you take it from there.</p><a href="tel:+917034991100">+91 70349 91100 <ArrowUpRight size={15}/></a></div></div><div className="enquiry-panel"><span className="section-overline">YOUR TRIP, IN YOUR WORDS</span><h3>Where are you dreaming of?</h3><EnquiryForm/></div></section>
  </>;
}
