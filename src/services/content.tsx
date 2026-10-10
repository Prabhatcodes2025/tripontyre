import { createContext, useContext, useEffect, useState, type ReactNode } from 'react';
import { categoryLabels, destinations as fallbackDestinations, gallery as fallbackGallery, packages as fallbackPackages, photos, type Destination, type GalleryPhoto, type PackageCategory, type TourPackage } from '../data';
import { supabase } from '../lib/supabase';

export type PublicDestination = Destination;
export type PublicPackage = TourPackage;
export type PublicHeroSlide = {
  name: string;
  region: string;
  title: string;
  note: string;
  image: string;
  coords: string;
};
export type PublicService = { title: string; copy: string };
export type PublicContentItem = { title: string; copy: string; slug?: string; image?: string };
export type PublicTestimonial = { name: string; copy: string; location?: string; image?: string };
export type PublicAward = { title: string; copy: string; issuer?: string; image?: string };

const fallbackHeroSlides: PublicHeroSlide[] = [
  { name:'Kashmir', region:'NORTH INDIA · THE HIMALAYAS', title:'Find your kind of beautiful.', note:'Lake mornings. Mountain air. A little more time to take it all in.', image:photos.kashmir, coords:'34.0837° N · 74.7973° E' },
  { name:'Kerala', region:'SOUTH INDIA · BACKWATERS', title:'Journeys that stay with you.', note:'Tea-scented hills, old harbour lanes and a quieter kind of holiday.', image:photos.kerala, coords:'10.1632° N · 76.6413° E' },
  { name:'Bali', region:'INDONESIA · ISLAND LIFE', title:'Slow down. You’re somewhere special.', note:'Temple courtyards, green hills and the freedom to follow the day.', image:photos.bali, coords:'08.3405° S · 115.0920° E' },
  { name:'Dubai', region:'UNITED ARAB EMIRATES · CITY & DESERT', title:'Follow the light. Stay for the contrast.', note:'A skyline at one turn, open desert at the next, and room to make both your own.', image:photos.dubai, coords:'25.2048° N · 55.2708° E' },
  { name:'Maldives', region:'INDIAN OCEAN · ISLAND ESCAPE', title:'Leave space for nothing at all.', note:'Warm water, long horizons and days designed to move at a gentler pace.', image:photos.maldives, coords:'03.2028° N · 73.2207° E' },
];

const fallbackServices: PublicService[] = [
  { title:'Car Rental & Transportation', copy:'Private transfers, intercity travel and local transport planning.' },
  { title:'Corporate Travel', copy:'Enquiry-led business travel coordination.' },
  { title:'MICE', copy:'Meetings, incentives, conferences and event travel planning.' },
  { title:'Hotels & Accommodation', copy:'Stay sourcing within a confirmed itinerary or as a standalone enquiry.' },
  { title:'Visa Assistance', copy:'Process guidance based on destination and traveller profile.' },
  { title:'Travel Insurance', copy:'Provider options can be presented when configured.' },
];

const fallbackBlogs: PublicContentItem[] = [
  { title:'A slower way through Kerala', copy:'Field notes', slug:'a-slower-way-through-kerala', image:photos.boat },
  { title:'What to leave room for in Kashmir', copy:'Destination guide', slug:'what-to-leave-room-for-in-kashmir', image:photos.kashmir },
  { title:'Bali beyond the first picture', copy:'Travel inspiration', slug:'bali-beyond-the-first-picture', image:photos.bali },
];
const fallbackEvents: PublicContentItem[] = [{ title:'Travel events calendar', copy:'No public events have been supplied yet.' }];
const fallbackFaqs: PublicContentItem[] = [
  { title:'Can an itinerary be customized?', copy:'Yes. Published packages are starting points and the final proposal can be tailored.' },
  { title:'Is online payment active?', copy:'Only when a payment provider has been configured. The site never simulates a successful charge.' },
  { title:'Where are my documents?', copy:'Issued invoices and vouchers appear in the secure customer portal.' },
];

type PublicContent = {
  destinations: PublicDestination[];
  packages: PublicPackage[];
  gallery: GalleryPhoto[];
  heroSlides: PublicHeroSlide[];
  services: PublicService[];
  blogs: PublicContentItem[];
  events: PublicContentItem[];
  faqs: PublicContentItem[];
  testimonials: PublicTestimonial[];
  awards: PublicAward[];
};

const fallbackContent: PublicContent = {
  destinations: fallbackDestinations,
  packages: fallbackPackages,
  gallery: fallbackGallery,
  heroSlides: fallbackHeroSlides,
  services: fallbackServices,
  blogs: fallbackBlogs,
  events: fallbackEvents,
  faqs: fallbackFaqs,
  testimonials: [],
  awards: [],
};

const ContentContext = createContext<PublicContent>(fallbackContent);
const text = (value: unknown) => typeof value === 'string' ? value : '';

export function PublicContentProvider({ children }: { children: ReactNode }) {
  const [content, setContent] = useState(fallbackContent);

  useEffect(() => {
    if (!supabase) return;
    const api = supabase;
    let active = true;
    void (async () => {
      const [destinationResult, packageResult, galleryResult, heroResult, serviceResult, blogResult, eventResult, faqResult, testimonialResult, awardResult] = await Promise.all([
        supabase.from('destinations').select('slug,name,region,country,state,summary,hero_image,primary_category').eq('published', true).order('featured', { ascending:false }).order('name'),
        supabase.from('tour_packages').select('slug,title,category,is_upcoming,duration_days,duration_nights,summary,description,hero_image,trip_style,base_price,destinations(name,country,state),tour_itinerary_days(day_number,location),package_images(storage_path,display_order,is_cover)').eq('published', true).order('featured', { ascending:false }).order('created_at'),
        supabase.from('gallery_items').select('media_url,title,alt_text').eq('published', true).eq('media_type', 'image').order('display_order'),
        supabase.from('hero_slides').select('title,subtitle,image_url,alt_text,destinations(name,region,country,state)').eq('published', true).order('display_order'),
        supabase.from('travel_services').select('name,description').eq('published', true).order('name'),
        supabase.from('blogs').select('slug,title,excerpt,cover_image').eq('published', true).order('published_at', { ascending:false }),
        supabase.from('events').select('slug,title,description,cover_image').eq('published', true).order('starts_at', { ascending:true }),
        supabase.from('faqs').select('question,answer').eq('published', true).order('display_order'),
        supabase.from('testimonials').select('name,location,quote,media_url').eq('published', true).order('created_at', { ascending:false }),
        supabase.from('awards').select('title,issuer,description,image_url').eq('published', true).order('awarded_on', { ascending:false }),
      ]);
      if (!active) return;

      const liveDestinations = (destinationResult.data || []).map(row => ({
        name: text(row.name),
        slug: text(row.slug),
        category: (['domestic','international','strangers_meetup'].includes(text(row.primary_category)) ? text(row.primary_category) : 'domestic') as PackageCategory,
        label: categoryLabels[(['domestic','international','strangers_meetup'].includes(text(row.primary_category)) ? text(row.primary_category) : 'domestic') as PackageCategory],
        image: text(row.hero_image) || photos.hero,
      })).filter(item => item.name && item.slug);

      const livePackages = (packageResult.data || []).map(row => {
        const destination = Array.isArray(row.destinations) ? row.destinations[0] : row.destinations;
        const itinerary = [...(row.tour_itinerary_days || [])].sort((a, b) => Number(a.day_number) - Number(b.day_number));
        const route = itinerary.map(day => text(day.location)).filter((value, index, all) => value && value !== all[index - 1]).join(' → ');
        const days = Number(row.duration_days) || 0;
        const nights = Number(row.duration_nights);
        const category = (['domestic','international','strangers_meetup'].includes(text(row.category)) ? text(row.category) : 'domestic') as PackageCategory;
        const detailsAvailable = Boolean(days || itinerary.length || row.base_price || text(row.description));
        const packageImages = [...(row.package_images || [])]
          .sort((a, b) => Number(Boolean(b.is_cover)) - Number(Boolean(a.is_cover)) || Number(a.display_order) - Number(b.display_order))
          .map(item => text(item.storage_path))
          .filter(Boolean)
          .map(path => api.storage.from('site-media').getPublicUrl(path).data.publicUrl);
        const primaryImage = text(row.hero_image) || packageImages[0] || photos.hero;
        return {
          title: text(row.title),
          place: [text(destination?.name), text(destination?.country)].filter(Boolean).join(', ') || 'Custom destination',
          duration: days ? `${days} day${days === 1 ? '' : 's'}${Number.isFinite(nights) && nights > 0 ? ` · ${nights} night${nights === 1 ? '' : 's'}` : ''}` : 'Details coming soon',
          style: text(row.trip_style) || categoryLabels[category],
          image: primaryImage,
          gallery: [primaryImage, ...packageImages].filter((value, index, all) => all.indexOf(value) === index),
          slug: text(row.slug),
          route: route || text(destination?.name) || 'Route confirmed with your trip planner',
          desc: text(row.summary) || text(row.description) || 'Details coming soon. Ask our travel team to register your interest.',
          category,
          upcoming: Boolean(row.is_upcoming),
          detailsAvailable,
        };
      }).filter(item => item.title && item.slug);

      const liveGallery = (galleryResult.data || []).map(row => ({
        src: text(row.media_url),
        title: text(row.title) || 'My Tripon travel moment',
        alt: text(row.alt_text) || text(row.title) || 'My Tripon travel photograph',
      })).filter(item => Boolean(item.src));
      const liveHeroes = (heroResult.data || []).map(row => {
        const destination = Array.isArray(row.destinations) ? row.destinations[0] : row.destinations;
        return {
          name: text(destination?.name) || text(row.alt_text) || text(row.title),
          region: [text(destination?.region), text(destination?.state), text(destination?.country)].filter(Boolean).join(' · ').toUpperCase() || 'MY TRIPON TRAVEL',
          title: text(row.title),
          note: text(row.subtitle),
          image: text(row.image_url) || photos.hero,
          coords: 'EXPLORE · EXPERIENCE · ENJOY',
        };
      }).filter(item => item.title && item.image);

      setContent({
        destinations: liveDestinations.length ? liveDestinations : fallbackContent.destinations,
        packages: livePackages.length ? livePackages : fallbackContent.packages,
        gallery: liveGallery.length ? liveGallery : fallbackContent.gallery,
        heroSlides: liveHeroes.length ? liveHeroes : fallbackContent.heroSlides,
        services: serviceResult.data?.length ? serviceResult.data.map(row => ({ title:text(row.name), copy:text(row.description) })) : fallbackContent.services,
        blogs: blogResult.data?.length ? blogResult.data.map(row => ({ title:text(row.title), copy:text(row.excerpt), slug:text(row.slug), image:text(row.cover_image) || undefined })) : fallbackContent.blogs,
        events: eventResult.data?.length ? eventResult.data.map(row => ({ title:text(row.title), copy:text(row.description), slug:text(row.slug), image:text(row.cover_image) || undefined })) : fallbackContent.events,
        faqs: faqResult.data?.length ? faqResult.data.map(row => ({ title:text(row.question), copy:text(row.answer) })) : fallbackContent.faqs,
        testimonials: (testimonialResult.data || []).map(row => ({ name:text(row.name)||'Traveller', location:text(row.location)||undefined, copy:text(row.quote), image:text(row.media_url)||undefined })).filter(item=>item.copy),
        awards: (awardResult.data || []).map(row => ({ title:text(row.title), issuer:text(row.issuer)||undefined, copy:text(row.description), image:text(row.image_url)||undefined })).filter(item=>item.title),
      });
    })();
    return () => { active = false; };
  }, []);

  return <ContentContext.Provider value={content}>{children}</ContentContext.Provider>;
}

export const usePublicContent = () => useContext(ContentContext);
