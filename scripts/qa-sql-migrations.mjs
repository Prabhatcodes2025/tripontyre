import { readFile, readdir } from 'node:fs/promises';

const files = {
  enumValues: 'supabase/migrations/202610150000_package_category_values.sql',
  catalogue: 'supabase/migrations/202610150001_client_changes_1_6.sql',
  content: 'supabase/migrations/202610150002_full_tour_content.sql',
  booking: 'supabase/migrations/202610180001_booking_enabled_enforcement.sql',
  cr7: 'supabase/migrations/202610180002_cr7_catalogue_corrections.sql',
  cr8to12: 'supabase/migrations/202610180003_cr8_12_full_tour_content.sql',
  schema: 'supabase/schema.sql',
  fresh: 'supabase/FRESH_SUPABASE_SETUP.sql',
  publicContent: 'src/services/content.tsx',
  admin: 'src/pages/ProductionPages.tsx',
};

const entries = await Promise.all(Object.entries(files).map(async ([key, path]) => [key, await readFile(path, 'utf8')]));
const sql = Object.fromEntries(entries);
const failures = [];
const requireText = (source, text, message) => { if (!source.includes(text)) failures.push(message); };

const migrations = (await readdir('supabase/migrations')).filter(name => name.endsWith('.sql')).sort();
for (const filename of [
  '202610150000_package_category_values.sql',
  '202610150001_client_changes_1_6.sql',
  '202610150002_full_tour_content.sql',
  '202610180001_booking_enabled_enforcement.sql',
  '202610180002_cr7_catalogue_corrections.sql',
  '202610180003_cr8_12_full_tour_content.sql',
]) {
  if (!migrations.includes(filename)) failures.push(`migration missing: ${filename}`);
}

requireText(sql.enumValues, "add value if not exists 'strangers_meetup'", 'strangers_meetup enum addition missing');
requireText(sql.enumValues, "add value if not exists 'custom'", 'custom enum addition missing');
if (/alter type public\.package_category add value/i.test(sql.catalogue)) failures.push('enum additions must commit in the preceding migration');

const conflictBlock = sql.catalogue.slice(sql.catalogue.indexOf('on conflict (slug)'));
for (const marker of ['booking_enabled=false', 'published=false', 'published_at=null']) {
  requireText(conflictBlock, marker, `catalogue conflict branch missing ${marker}`);
}
for (const value of ['Mahipalpur, Delhi - 110037', '7582999111', 'mytripontravel@gmail.com', '7th Floor, Sky Towers, Mavoor Road Junction, Kozhikode', '7592883311']) {
  requireText(sql.catalogue, value, `official contact missing: ${value}`);
}
requireText(sql.catalogue, "media_url ilike '%tulip%'", 'Tulip correction is not URL-scoped');
requireText(sql.catalogue, "title ilike '%agumbe%' or alt_text ilike '%agumbe%'", 'Tulip correction is not limited to the mislabelled Agumbe row');

const dayRows = [...sql.content.matchAll(/\('([^']+)',(\d+),'[^']+'/g)].filter(match => [
  'kashmir-kargil',
  'delhi-agra-jaipur-golden-triangle-tour',
  'delhi-agra-mathura-jaipur-tour',
  'delhi-agra-tour',
  'delhi-agra-jaipur-amritsar-wagah-border',
].includes(match[1]));
if (dayRows.length !== 27) failures.push(`expected 27 itinerary rows, found ${dayRows.length}`);
for (const marker of ['is distinct from source.title', 'is distinct from source.description', 'is distinct from source.location', 'i.indisunique', 'on conflict(package_id,day_number)']) {
  requireText(sql.content, marker, `content migration guard missing: ${marker}`);
}
if (/hero_image\s*=/.test(sql.content.slice(sql.content.indexOf('update public.tour_packages'), sql.content.indexOf('-- Exact organized')))) failures.push('content migration overwrites package hero images');

for (const [price, label] of [[2100000,'₹21,000'],[2200000,'₹22,000'],[2600000,'₹26,000'],[1200000,'₹12,000'],[3400000,'₹34,000'],[1000000,'₹10,000 advance']]) {
  requireText(sql.content + sql.catalogue, String(price), `minor-unit value missing for ${label}`);
}
requireText(sql.booking, 'published=true and booking_enabled=true', 'server booking function does not enforce both safety flags');
requireText(sql.cr7, "primary_category='international'", 'CR7 Bali destination category correction missing');
requireText(sql.cr7, "d.slug in ('agumbe','ajanta-ellora','andaman')", 'CR7 stable destination media targeting missing');
requireText(sql.cr7, "title='Tulip Garden'", 'CR7 Tulip Garden label correction missing');
for (const slug of ['delhi-agra-amritsar-tour','rajasthan','kashmir-kargil-dhooth-pathri-tour','delhi-kullu-manali-tour','kullu-manali-kasol']) {
  requireText(sql.cr8to12, `'${slug}'`, `CR8-CR12 package missing: ${slug}`);
}
for (const marker of ['booking_enabled=false','published=false','published_at=null','on conflict(package_id,day_number)','rajasthan-heritage']) {
  requireText(sql.cr8to12, marker, `CR8-CR12 safety marker missing: ${marker}`);
}
requireText(sql.fresh, 'published=true and booking_enabled=true', 'fresh setup booking function does not enforce booking_enabled');
requireText(sql.schema, 'unique(package_id, day_number)', 'canonical itinerary uniqueness constraint missing');
requireText(sql.publicContent, "from('tour_packages')", 'public package query missing');
requireText(sql.publicContent, 'tour_itinerary_days(day_number,title,description,location)', 'public itinerary relation query missing');
requireText(sql.publicContent, 'Boolean(row.booking_enabled', 'public booking switch missing');
for (const field of ['age_pricing','inclusions','exclusions','important_information','hero_image','published','booking_enabled']) {
  requireText(sql.admin, `key:'${field}'`, `Admin package editor field missing: ${field}`);
}
requireText(sql.admin, "table: 'tour_itinerary_days'", 'Admin itinerary editor missing');

for (const [key, source] of Object.entries({ catalogue:sql.catalogue, content:sql.content, booking:sql.booking, cr7:sql.cr7, cr8to12:sql.cr8to12 })) {
  const delimiters = [...source.matchAll(/\$[A-Za-z_]*\$/g)].map(match => match[0]);
  const open = [];
  for (const delimiter of delimiters) {
    if (open.at(-1) === delimiter) open.pop(); else open.push(delimiter);
  }
  if (open.length) failures.push(`${key} migration has unbalanced dollar-quote delimiters: ${open.join(', ')}`);
  if (!source.trimEnd().endsWith(';')) failures.push(`${key} migration does not end with a semicolon`);
}

if (failures.length) {
  console.error(failures.join('\n'));
  process.exitCode = 1;
} else {
  console.log('SQL migration ordering, safety markers, content counts and schema/query compatibility checks passed.');
}
