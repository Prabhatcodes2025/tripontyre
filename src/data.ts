export const photos = {
  hero: 'https://images.unsplash.com/photo-1512343879784-a960bf40e7f2?auto=format&fit=crop&w=2200&q=88',
  kerala: 'https://images.unsplash.com/photo-1602216056096-3b40cc0c9944?auto=format&fit=crop&w=1300&q=85',
  kashmir: 'https://images.unsplash.com/photo-1595815771614-ade9d652a65d?auto=format&fit=crop&w=1200&q=85',
  rajasthan: 'https://images.unsplash.com/photo-1477587458883-47145ed94245?auto=format&fit=crop&w=1200&q=85',
  bali: 'https://images.unsplash.com/photo-1537996194471-e657df975ab4?auto=format&fit=crop&w=1400&q=85',
  dubai: 'https://images.unsplash.com/photo-1512453979798-5ea266f8880c?auto=format&fit=crop&w=1200&q=85',
  beach: 'https://images.unsplash.com/photo-1500375592092-40eb2168fd21?auto=format&fit=crop&w=1200&q=85',
  taj: 'https://images.unsplash.com/photo-1564507592333-c60657eea523?auto=format&fit=crop&w=1200&q=85',
  family: 'https://images.unsplash.com/photo-1500530855697-b586d89ba3ee?auto=format&fit=crop&w=1200&q=85',
  mountains: 'https://images.unsplash.com/photo-1464822759023-fed622ff2c3b?auto=format&fit=crop&w=1200&q=85',
  coast: 'https://images.unsplash.com/photo-1519046904884-53103b34b206?auto=format&fit=crop&w=1200&q=85',
  europe: 'https://images.unsplash.com/photo-1499856871958-5b9627545d1a?auto=format&fit=crop&w=1200&q=85'
};
export const destinations = [
  {name:'Kerala', label:'Backwaters · South India', slug:'kerala', image:photos.kerala},
  {name:'Kashmir', label:'Mountains · North India', slug:'kashmir', image:photos.kashmir},
  {name:'Rajasthan', label:'Heritage · India', slug:'rajasthan', image:photos.rajasthan},
  {name:'Bali', label:'Island life · Indonesia', slug:'bali', image:photos.bali},
  {name:'Dubai', label:'City & desert · UAE', slug:'dubai', image:photos.dubai},
  {name:'Europe', label:'Culture · Across Europe', slug:'europe', image:photos.europe}
];
export const packages = [
  {title:'The quiet side of Kerala', place:'Kerala, India', duration:'7 days · 6 nights', style:'Backwaters & hills', image:photos.kerala, slug:'kerala-backwaters', desc:'From old Kochi lanes to Munnar tea country and a slow backwater morning.'},
  {title:'Kashmir, at your own pace', place:'Kashmir, India', duration:'6 days · 5 nights', style:'Mountains & lakes', image:photos.kashmir, slug:'kashmir-at-your-pace', desc:'A measured route through Srinagar, Gulmarg and the valley beyond.'},
  {title:'Palaces, pink streets & desert skies', place:'Rajasthan, India', duration:'8 days · 7 nights', style:'Heritage & culture', image:photos.rajasthan, slug:'rajasthan-heritage', desc:'Jaipur colour, Jodhpur blue and an evening beneath the desert sky.'},
  {title:'A little more Bali', place:'Bali, Indonesia', duration:'6 days · 5 nights', style:'Island escape', image:photos.bali, slug:'bali-island-escape', desc:'Temple mornings, green highlands and time set aside for the sea.'}
];
export const gallery = [photos.kerala,photos.taj,photos.beach,photos.family,photos.mountains,photos.bali,photos.coast,photos.rajasthan,photos.europe];
