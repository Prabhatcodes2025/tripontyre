export type DestinationImageCredit = {
  image: string;
  title: string;
  creator: string;
  license: string;
  source: string;
  licenseUrl: string;
};

const licenseUrls: Record<string, string> = {
  'CC0': 'https://creativecommons.org/publicdomain/zero/1.0/',
  'Public domain': 'https://creativecommons.org/publicdomain/mark/1.0/',
  'CC BY 2.0': 'https://creativecommons.org/licenses/by/2.0/',
  'CC BY 3.0': 'https://creativecommons.org/licenses/by/3.0/',
  'CC BY 4.0': 'https://creativecommons.org/licenses/by/4.0/',
  'CC BY-SA 2.0': 'https://creativecommons.org/licenses/by-sa/2.0/',
  'CC BY-SA 3.0': 'https://creativecommons.org/licenses/by-sa/3.0/',
  'CC BY-SA 4.0': 'https://creativecommons.org/licenses/by-sa/4.0/',
  'Unsplash License': 'https://unsplash.com/license',
};

const commons = (file: string, creator: string, license: string): DestinationImageCredit => ({
  image: `https://commons.wikimedia.org/wiki/Special:FilePath/${encodeURIComponent(file)}?width=1600`,
  title: file.replace(/\.[^.]+$/, ''),
  creator,
  license,
  source: `https://commons.wikimedia.org/wiki/File:${encodeURIComponent(file.replaceAll(' ', '_'))}`,
  licenseUrl: licenseUrls[license],
});

const unsplash = (image: string, title: string, creator: string, source: string): DestinationImageCredit => ({
  image,
  title,
  creator,
  license: 'Unsplash License',
  source,
  licenseUrl: licenseUrls['Unsplash License'],
});

export const destinationImageCredits: Record<string, DestinationImageCredit> = {
  'agumbe': unsplash('https://images.unsplash.com/photo-1578378377576-2ed7065bdb87?auto=format&fit=crop&w=1600&q=85','Western Ghats scenery near Agumbe','Unsplash contributor','https://unsplash.com/photos/yOj9j2Ho-kE'),
  'ajanta-ellora': unsplash('https://images.unsplash.com/photo-1620558601903-9f2441730121?auto=format&fit=crop&w=1600&q=85','Ajanta Caves','Unsplash contributor','https://unsplash.com/photos/ZP039_CRf3M'),
  'andaman': unsplash('https://images.unsplash.com/photo-1767782843278-1cfc4acff2ff?auto=format&fit=crop&w=1600&q=85','Andaman and Nicobar Islands','Unsplash contributor','https://unsplash.com/photos/YZh8je9IYfc'),
  'ayodhya-kashi-prayagraj-gaya-bodh-gaya': commons('Ram Mandir, Ayodhya.png','Narendra Modi','CC BY 3.0'),
  'azerbaijan': commons('The skyline of Baku, Azerbaijan.jpg','Bruno Girin','CC BY-SA 2.0'),
  'bangalore-mysore-kodagu': commons('Exterior of the Mysore Palace, Mysore, Karnataka, 2018.jpg','Gana P Nambiar','CC BY-SA 4.0'),
  'bhutan': commons('Paro Taktsang, Bhutan (edited).jpg','Nina R / UnpetitproleX','CC BY 2.0'),
  'bijapur-hampi-badami-aihole-pattadakkal-chitradurga': commons('Hampi, India, Rocky landscape of Hampi, Granite rocks of Matanga Hill.jpg','Vyacheslav Argenberg','CC BY 4.0'),
  'chikmagalur': commons('Shade coffee plantation landscape Chikmagalur.jpg','Anand Osuri','CC BY-SA 4.0'),
  'delhi-agra-jaipur-amritsar-wagah-border': unsplash('https://images.unsplash.com/photo-1564507592333-c60657eea523?auto=format&fit=crop&w=1600&q=85','Taj Mahal, Agra','Sylwia Bartyzel','https://unsplash.com/photos/taj-mahal-india-Thr_TUYPtAk'),
  'gujarat': commons('Pond, Little Rann of Kutch (16494607670).jpg','Nagarjun Kandukuru','CC BY 2.0'),
  'hampi': commons('Krishna Pushkarani - Hampi Ruins.jpg','Dey.sandip','CC BY-SA 3.0'),
  'hyderabad': commons('Charminar Hyderabad 1.jpg','DidierTais','CC BY-SA 3.0'),
  'jog-falls': commons('Jog Falls, Sep, 2016.jpg','Nikhilb239','CC BY-SA 4.0'),
  'kerala-full': commons('A Houseboat In Kerala Backwaters.jpg','RndmCrs','CC0'),
  'kolkata': commons('Victoria Memorial situated in Kolkata.jpg','Subhrajyoti07','CC BY-SA 4.0'),
  'malaysia-singapore': commons('Singapore Skyline.jpg','JeCCo','CC BY-SA 3.0'),
  'matheran': commons('Matheran mountains.jpg','Naveenjain431','CC BY-SA 4.0'),
  'meghalaya': commons('Living root bridge, Maghalaya, India1.jpg','Joydeep Chakraborty','CC BY-SA 4.0'),
  'mumbai': commons('Panoramic view of Taj Palace Hotel and Taj Tower with the iconic Gateway of India in the background.jpg','iMahesh','CC BY-SA 4.0'),
  'munnar-thekkady-kochi-alappuzha-kumarakom-varkala-kovalam': commons('Athirappilly Falls 2024.jpg','Vis M','CC0'),
  'munnar-thekkady-vagamon-kochi-athirappalli': commons('Tea plantation and road ,munnar.jpg','Shino Jacob Koottanad','CC BY-SA 4.0'),
  'nepal': commons('Durbar Square, Kathmandu.jpg','Bernard Gagnon','CC BY-SA 3.0'),
  'odisha': commons('Konark Sun Temple , Konark , Odisha , India.jpg','Bhubaneswar2009','CC BY-SA 4.0'),
  'ooty-mysore': commons('Hills in ooty.jpg','Seetha Lakshmi Narayanan','CC BY-SA 4.0'),
  'rameswaram-dhanushkodi-madurai-kodaikanal': commons('Pamban Bridge.Rameswaram.jpg','Karthic.Ganesh','CC BY-SA 4.0'),
  'sikkim-darjeeling': commons('Kanchenjunga from Darjeeling.jpg','Maitreyee12','CC BY-SA 4.0'),
  'sri-lanka': commons('Sigiriya Rock fortress.jpg','Chamixth','CC BY-SA 4.0'),
  'vagamon': commons('Vagamon hills of Kerala 02.jpg','Rahanashibu','CC BY-SA 4.0'),
  'valparai-athirappalli': commons('Valparai,Tamil Nadu.jpg','Aadithye Noble','CC BY-SA 4.0'),
  'wayanad': commons('Kerala-wayanad.jpg','Abbas.hr','CC BY-SA 4.0'),
  'kashmir-kargil': commons('Ladakh landscape near Leh.jpg','Yann Forget','CC BY-SA 4.0'),
  'kasol': commons('Parvati Valley From Kasol.jpg','Subhapal3187','CC BY-SA 4.0'),
  'kullu-manali-kasol': commons('Solang Valley Manali.JPG','Jishnu2602','CC BY-SA 3.0'),
  'ladakh': commons('Landscape of Ladakh 03.jpg','Bernard Gagnon','CC BY-SA 4.0'),
  'bali-nusa-penida': commons('Nusa Penida Bali.jpg','Tisa0603','CC0'),
  'indonesia': commons('Borobudur-Nothwest-view.jpg','Gunawan Kartapranata','Public domain'),
  'gokarna': commons('Gokarna beach.jpg','Pranet','CC BY-SA 4.0'),
  'lakshadweep': commons('LakshadweepIsland.jpg','Lenish Namath','CC BY-SA 3.0'),
};

export const destinationImageFor = (slug: string) => destinationImageCredits[slug];

const imageKey = (url: string) => {
  try {
    const pathname = decodeURIComponent(new URL(url, 'https://local.invalid').pathname);
    return pathname.replaceAll('_', ' ').toLowerCase();
  } catch {
    return url.split('?')[0].replaceAll('_', ' ').toLowerCase();
  }
};

export const destinationImageCreditForUrl = (url: string) => {
  const key = imageKey(url);
  return Object.values(destinationImageCredits).find(credit => imageKey(credit.image) === key);
};
