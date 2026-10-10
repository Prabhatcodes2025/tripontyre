export const photos = {
  hero: '/dal-lake-kashmir.jpg',
  kerala: 'https://images.unsplash.com/photo-1602216056096-3b40cc0c9944?auto=format&fit=crop&w=1300&q=85',
  kashmir: '/dal-lake-kashmir.jpg',
  rajasthan: 'https://images.unsplash.com/photo-1477587458883-47145ed94245?auto=format&fit=crop&w=1200&q=85',
  bali: '/travel/nusa-penida.webp',
  dubai: '/travel/desert-convoy.webp',
  goa: '/travel/beach-reflections.webp',
  thailand: 'https://images.unsplash.com/photo-1508009603885-50cf7c579365?auto=format&fit=crop&w=1200&q=85',
  maldives: 'https://images.unsplash.com/photo-1514282401047-d79a71a590e8?auto=format&fit=crop&w=1200&q=85',
  beach: '/travel/beach-reflections.webp',
  taj: 'https://images.unsplash.com/photo-1564507592333-c60657eea523?auto=format&fit=crop&w=1200&q=85',
  family: 'https://images.unsplash.com/photo-1500530855697-b586d89ba3ee?auto=format&fit=crop&w=1200&q=85',
  mountains: '/travel/mountain-river-bridge.webp',
  coast: '/travel/nusa-penida.webp',
  traveller: '/travel/street-traveller.jpg',
  couple: 'https://images.unsplash.com/photo-1522673607200-164d1b6ce486?auto=format&fit=crop&w=1000&q=85',
  local: '/travel/street-traveller.jpg',
  tree: '/travel/beautiful-tree.jpg',
  boat: 'https://images.unsplash.com/photo-1544551763-46a013bb70d5?auto=format&fit=crop&w=1200&q=85',
  clientDesert: '/travel/desert-convoy.webp',
  clientNusa: '/travel/nusa-penida.webp',
  clientBeach: '/travel/beach-reflections.webp',
  clientBridge: '/travel/mountain-river-bridge.webp',
  clientTulips: '/travel/tulip-garden.webp',
};

export type PackageCategory = 'domestic' | 'international' | 'strangers_meetup';

const catalogue: Record<PackageCategory, string[]> = {
  domestic: [
    'Delhi - Agra - Jaipur - Amritsar - Wagah Border', 'Kashmir', 'Kashmir - Kargil', 'Ladakh', 'Rajasthan',
    'Sikkim - Darjeeling', 'Meghalaya', 'Kolkata', 'Gujarat', 'Hyderabad', 'Mumbai', 'Ajanta - Ellora',
    'Odisha', 'Lakshadweep', 'Andaman', 'Goa', 'Kullu - Manali - Kasol', 'Kerala - Full',
    'Munnar - Thekkady - Vagamon - Kochi - Athirappalli',
    'Munnar - Thekkady - Kochi - Alappuzha - Kumarakom - Varkala - Kovalam',
    'Bijapur - Hampi - Badami - Aihole - Pattadakkal - Chitradurga',
    'Ayodhya - Kashi - Prayagraj - Gaya - Bodh Gaya',
    'Rameswaram - Dhanushkodi - Madurai - Kodaikanal', 'Valparai - Athirappalli',
    'Bangalore - Mysore - Kodagu', 'Ooty - Mysore',
  ],
  international: ['Dubai', 'Thailand', 'Indonesia', 'Bali - Nusa Penida', 'Malaysia - Singapore', 'Sri Lanka', 'Maldives', 'Nepal', 'Bhutan', 'Azerbaijan'],
  strangers_meetup: ['Matheran', 'Vagamon', 'Hampi', 'Gokarna', 'Agumbe', 'Jog Falls', 'Wayanad', 'Kasol', 'Chikmagalur'],
};

export const categoryLabels: Record<PackageCategory, string> = {
  domestic: 'Domestic Tour Packages',
  international: 'International Tours',
  strangers_meetup: 'Strangers Meetup Tours',
};

const upcomingNames = new Set(['Thailand', 'Rajasthan', 'Delhi - Agra - Jaipur - Amritsar - Wagah Border']);
const slugify = (value: string) => value.toLowerCase().replace(/&/g, 'and').replace(/[^a-z0-9]+/g, '-').replace(/^-|-$/g, '');
const imageFor = (name: string, category: PackageCategory) => {
  const lower = name.toLowerCase();
  if (lower === 'kashmir') return photos.clientTulips;
  if (lower.includes('kashmir') || lower.includes('ladakh') || lower.includes('manali') || lower.includes('kasol')) return photos.clientBridge;
  if (lower.includes('bali') || lower.includes('indonesia')) return photos.clientNusa;
  if (lower.includes('goa') || lower.includes('gokarna') || lower.includes('andaman') || lower.includes('lakshadweep') || lower.includes('maldives')) return photos.clientBeach;
  if (lower.includes('dubai')) return photos.clientDesert;
  if (lower.includes('rajasthan')) return photos.rajasthan;
  if (lower.includes('kerala') || lower.includes('munnar') || lower.includes('vagamon') || lower.includes('wayanad') || lower.includes('athirappalli')) return photos.kerala;
  if (lower.includes('thailand')) return photos.thailand;
  return category === 'international' ? photos.traveller : photos.tree;
};

export type Destination = { name: string; label: string; slug: string; image: string; category: PackageCategory };
export type TourPackage = {
  title: string; place: string; duration: string; style: string; image: string; slug: string;
  route: string; desc: string; category: PackageCategory; upcoming: boolean; detailsAvailable: boolean; gallery?: string[];
};

export const destinations: Destination[] = (Object.entries(catalogue) as [PackageCategory, string[]][]).flatMap(([category, names]) =>
  names.map(name => ({ name, label: categoryLabels[category], slug: slugify(name), image: imageFor(name, category), category })),
);

export const packages: TourPackage[] = destinations.map(destination => ({
  title: destination.name,
  place: destination.name,
  duration: 'Details coming soon',
  style: categoryLabels[destination.category],
  image: destination.image,
  slug: destination.slug,
  route: destination.name,
  desc: 'Details coming soon. Ask our travel team to register your interest.',
  category: destination.category,
  upcoming: upcomingNames.has(destination.name),
  detailsAvailable: false,
}));

export const catalogueCounts = Object.fromEntries(Object.entries(catalogue).map(([key, values]) => [key, values.length])) as Record<PackageCategory, number>;
export type GalleryPhoto = { src:string; title:string; alt:string };
export const gallery:GalleryPhoto[] = [
  {src:photos.clientDesert,title:'Dubai desert adventure',alt:'My Tripon travellers beside their desert convoy in Dubai'},
  {src:photos.clientNusa,title:'Nusa Penida coast',alt:'Natural rock arch and blue water at Nusa Penida, Bali'},
  {src:photos.clientBeach,title:'Coastal reflections',alt:'Travellers walking across a reflective beach at low tide'},
  {src:photos.clientBridge,title:'Mountain river crossing',alt:'Bridge over a rocky mountain river in North India'},
  {src:photos.clientTulips,title:'Tulip Gardens, Kashmir',alt:'Rows of red, white and pink tulips at Tulip Gardens in Kashmir'},
  {src:photos.couple,title:'Plan for Two',alt:'Two flower-decorated chairs prepared for a romantic experience'},
  {src:photos.traveller,title:'A street of your own',alt:'A woman with a backpack walking through a historic street'},
  {src:photos.tree,title:'Wild horizons',alt:'A beautiful spreading tree silhouetted against a warm sunset'},
  {src:photos.taj,title:'Agra at first light',alt:'The Taj Mahal in Agra'},
  {src:photos.family,title:'The open road',alt:'A road winding through a red-rock landscape'},
  {src:photos.kerala,title:'Kerala backwaters',alt:'A traditional houseboat on Kerala’s backwaters'},
  {src:photos.boat,title:'Time on the water',alt:'A quiet travel experience on the water'},
];
