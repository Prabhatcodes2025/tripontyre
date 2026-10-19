import { readFile } from 'node:fs/promises';

const path = 'supabase/migrations/202610150002_full_tour_content.sql';
const sql = await readFile(path, 'utf8');
const metadata = sql.slice(sql.indexOf('update public.tour_packages'), sql.indexOf('-- Exact organized day-wise'));
const itinerary = sql.slice(sql.indexOf('insert into pg_temp.client_tour_itinerary'));
const bookingSafetySql = await readFile('supabase/migrations/202610180001_booking_enabled_enforcement.sql', 'utf8');

const specs = [
  { slug:'kashmir-kargil', days:5, stops:8, inclusions:9, exclusions:7, bands:4, price:2100000, required:['10:00 AM — Pickup from Srinagar Airport.','5:00 PM — Zero Point','2:00 PM — Gulmarg Gondola','Optional client-supplied train-return sequence'] },
  { slug:'delhi-agra-jaipur-golden-triangle-tour', days:5, stops:4, inclusions:3, exclusions:5, bands:4, price:2200000, required:['1:00 AM — Welcome at Delhi Airport','3:00 PM — Taj Mahal','6:00 PM — Delhi Airport drop'] },
  { slug:'delhi-agra-mathura-jaipur-tour', days:6, stops:5, inclusions:8, exclusions:5, bands:4, price:2600000, required:['4:30 PM — Swaminarayan Akshardham','11:30 AM — Mathura Temple','6:00 PM — Delhi Airport drop'] },
  { slug:'delhi-agra-tour', days:3, stops:2, inclusions:8, exclusions:5, bands:4, price:1200000, required:['6:00 AM — Start from Delhi.','1:30 PM — Agra Fort','6:00 PM — Delhi Airport drop'] },
  { slug:'delhi-agra-jaipur-amritsar-wagah-border', days:8, stops:7, inclusions:10, exclusions:5, bands:4, price:3400000, required:['3:15 PM — Vande Bharat train','5:30 PM — Flag-lowering / Beating Retreat ceremony','10:30 PM — Overnight AC Volvo semi-sleeper bus','2:00 PM — Delhi Airport drop'] },
];

const failures = [];
const report = [];
for (const spec of specs) {
  const escaped = spec.slug.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
  const metadataMatch = metadata.match(new RegExp(`\\(\\s*'${escaped}',([\\s\\S]*?)\\n\\s*\\)(?:,|\\n)`));
  if (!metadataMatch) {
    failures.push(`${spec.slug}: metadata row missing`);
    continue;
  }
  const jsonValues = [...metadataMatch[1].matchAll(/'(\[[^\n]*\])'::jsonb/g)].map(match => JSON.parse(match[1]));
  const [stops, inclusions, exclusions, bands] = jsonValues;
  const dayNumbers = [...itinerary.matchAll(new RegExp(`\\('${escaped}',(\\d+),`, 'g'))].map(match => Number(match[1]));
  const expectedDays = Array.from({ length:spec.days }, (_, index) => index + 1);
  const checks = {
    days: JSON.stringify(dayNumbers) === JSON.stringify(expectedDays),
    stops: stops?.length === spec.stops,
    inclusions: inclusions?.length === spec.inclusions,
    exclusions: exclusions?.length === spec.exclusions,
    bands: bands?.length === spec.bands,
    price: metadataMatch[1].includes(String(spec.price)),
    requiredContent: spec.required.every(value => itinerary.includes(value)),
  };
  for (const [name, passed] of Object.entries(checks)) if (!passed) failures.push(`${spec.slug}: ${name} check failed`);
  report.push({ package:spec.slug, days:dayNumbers.length, stops:stops?.length, inclusions:inclusions?.length, exclusions:exclusions?.length, priceBands:bands?.length, passed:Object.values(checks).every(Boolean) });
}

for (const required of ['booking_enabled=false','published=false','published_at=null','begin;','commit;']) {
  if (!sql.includes(required)) failures.push(`migration safety marker missing: ${required}`);
}
for (const required of ['Existing itinerary content differs','indisunique','create unique index tour_itinerary_days_package_day_uidx']) {
  if (!sql.includes(required)) failures.push(`migration conflict/constraint guard missing: ${required}`);
}
if (/hero_image\s*=/.test(metadata)) failures.push('migration must preserve existing package hero images');
if (!bookingSafetySql.includes('published=true and booking_enabled=true')) failures.push('server booking path does not enforce booking_enabled');

const publicFiles = await Promise.all(['index.html','src/company.ts','supabase/SEED_PUBLIC_CONTENT.sql'].map(file => readFile(file,'utf8')));
const publicText = publicFiles.join('\n');
for (const obsolete of ['infomytripontravel@gmail.com','7592999111','Sky Tower, Major Road Junction']) {
  if (publicText.includes(obsolete)) failures.push(`obsolete public contact remains: ${obsolete}`);
}

console.table(report);
if (failures.length) {
  console.error(failures.join('\n'));
  process.exitCode = 1;
} else {
  console.log('Tour-content completeness and safety checks passed.');
}
