export const photos = {
  hero: 'https://images.unsplash.com/photo-1595815771614-ade9d652a65d?auto=format&fit=crop&w=2200&q=88',
  kerala: 'https://images.unsplash.com/photo-1602216056096-3b40cc0c9944?auto=format&fit=crop&w=1300&q=85',
  kashmir: 'https://images.unsplash.com/photo-1595815771614-ade9d652a65d?auto=format&fit=crop&w=1200&q=85',
  rajasthan: 'https://images.unsplash.com/photo-1477587458883-47145ed94245?auto=format&fit=crop&w=1200&q=85',
  bali: 'https://images.unsplash.com/photo-1537996194471-e657df975ab4?auto=format&fit=crop&w=1400&q=85',
  dubai: 'https://images.unsplash.com/photo-1512453979798-5ea266f8880c?auto=format&fit=crop&w=1200&q=85',
  goa: 'https://images.unsplash.com/photo-1519046904884-53103b34b206?auto=format&fit=crop&w=1200&q=85',
  thailand: 'https://images.unsplash.com/photo-1508009603885-50cf7c579365?auto=format&fit=crop&w=1200&q=85',
  maldives: 'https://images.unsplash.com/photo-1514282401047-d79a71a590e8?auto=format&fit=crop&w=1200&q=85',
  beach: 'https://images.unsplash.com/photo-1500375592092-40eb2168fd21?auto=format&fit=crop&w=1200&q=85',
  taj: 'https://images.unsplash.com/photo-1564507592333-c60657eea523?auto=format&fit=crop&w=1200&q=85',
  family: 'https://images.unsplash.com/photo-1500530855697-b586d89ba3ee?auto=format&fit=crop&w=1200&q=85',
  mountains: 'https://images.unsplash.com/photo-1464822759023-fed622ff2c3b?auto=format&fit=crop&w=1200&q=85',
  coast: 'https://images.unsplash.com/photo-1519046904884-53103b34b206?auto=format&fit=crop&w=1200&q=85',
  europe: 'https://images.unsplash.com/photo-1499856871958-5b9627545d1a?auto=format&fit=crop&w=1200&q=85',
  traveller: 'https://images.unsplash.com/photo-1527631746610-bca00a040d60?auto=format&fit=crop&w=1200&q=85',
  couple: 'https://images.unsplash.com/photo-1522673607200-164d1b6ce486?auto=format&fit=crop&w=1000&q=85',
  local: 'https://images.unsplash.com/photo-1516026672322-bc52d61a55d5?auto=format&fit=crop&w=1200&q=85',
  boat: 'https://images.unsplash.com/photo-1544551763-46a013bb70d5?auto=format&fit=crop&w=1200&q=85'
};
export const destinations = [
  {name:'Kerala', label:'Backwaters · South India', slug:'kerala', image:photos.kerala},
  {name:'Kashmir', label:'Mountains · North India', slug:'kashmir', image:photos.kashmir},
  {name:'Rajasthan', label:'Heritage · India', slug:'rajasthan', image:photos.rajasthan},
  {name:'Goa', label:'Coast · West India', slug:'goa', image:photos.goa},
  {name:'Bali', label:'Island life · Indonesia', slug:'bali', image:photos.bali},
  {name:'Dubai', label:'City & desert · UAE', slug:'dubai', image:photos.dubai},
  {name:'Thailand', label:'Culture · Southeast Asia', slug:'thailand', image:photos.thailand},
  {name:'Maldives', label:'Island escape · Indian Ocean', slug:'maldives', image:photos.maldives},
  {name:'Europe', label:'Culture · Across Europe', slug:'europe', image:photos.europe}
];
export const packages = [
  {title:'Backwaters & beyond', place:'Kerala, India', duration:'6 days · 5 nights', style:'Backwaters & hills', image:photos.kerala, slug:'kerala-backwaters', route:'Kochi → Munnar → Thekkady → Alleppey', desc:'Harbour lanes, tea country and a gentle final night on the water.'},
  {title:'Kashmir, at your own pace', place:'Kashmir, India', duration:'6 days · 5 nights', style:'Mountains & lakes', image:photos.kashmir, slug:'kashmir-at-your-pace', route:'Srinagar → Gulmarg → Pahalgam', desc:'Lake mornings and open mountain views, with time to take the longer way.'},
  {title:'Palaces, pink streets & desert skies', place:'Rajasthan, India', duration:'8 days · 7 nights', style:'Heritage & culture', image:photos.rajasthan, slug:'rajasthan-heritage', route:'Jaipur → Jodhpur → Jaisalmer', desc:'Jaipur colour, Jodhpur blue and an evening beneath the desert sky.'},
  {title:'A little more Bali', place:'Bali, Indonesia', duration:'6 days · 5 nights', style:'Island escape', image:photos.bali, slug:'bali-island-escape', route:'Ubud → Sidemen → Uluwatu', desc:'Temple mornings, green highlands and time set aside for the sea.'}
];
export const gallery = [photos.traveller,photos.kerala,photos.couple,photos.taj,photos.family,photos.local,photos.beach,photos.bali,photos.coast,photos.rajasthan,photos.boat,photos.europe];
