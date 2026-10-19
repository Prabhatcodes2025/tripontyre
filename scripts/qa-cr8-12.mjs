import { readFile } from 'node:fs/promises';

const path = 'supabase/migrations/202610180003_cr8_12_full_tour_content.sql';
const sql = await readFile(path, 'utf8');
const packageSection = sql.slice(sql.indexOf('insert into pg_temp.client_cr8_12_packages values'), sql.indexOf('-- Abort rather'));
const itinerarySection = sql.slice(sql.indexOf('insert into pg_temp.client_cr8_12_itinerary values'), sql.indexOf('-- Existing differing itinerary'));

const specs = [
  { slug:'delhi-agra-amritsar-tour', days:[1,2,3,4,5], stops:3, inclusions:10, exclusions:6, bands:4, price:2450000, advance:50, required:['3:15 PM — Vande Bharat train','5:30 PM — Flag-lowering ceremony','10:30 PM — AC Volvo semi-sleeper bus'] },
  { slug:'rajasthan', days:[1,2,3,4,5,6,7], stops:6, inclusions:8, exclusions:5, bands:0, price:null, advance:0, required:['City Palace, Lake Pichola','Camel ride on Sam Sand Dunes','4:30 PM — Drop at Jaipur Airport'] },
  { slug:'kashmir-kargil-dhooth-pathri-tour', days:[1,2,3,5,6,7], stops:9, inclusions:10, exclusions:6, bands:4, price:2600000, advance:0, required:['Day 4 is absent','6:00 PM — Zero Point','2:00 PM — Gondola Cable Car','2:40 PM — Flight to Delhi'] },
  { slug:'delhi-kullu-manali-tour', days:[1,2,3,4], stops:5, inclusions:8, exclusions:5, bands:4, price:2200000, advance:0, required:['10:30 AM onward — Atal Tunnel','Expected arrival in Delhi at 5:00 AM'] },
  { slug:'kullu-manali-kasol', days:[1,2,3,4,5], stops:6, inclusions:8, exclusions:5, bands:4, price:2900000, advance:0, required:['seat in bus. Without bus','Manikaran Sahib Gurudwara','Expected arrival in Delhi at 5:00 AM'] },
];

const failures = [];
const report = [];
const escape = value => value.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');

for (const spec of specs) {
  const slug = escape(spec.slug);
  const next = specs[specs.indexOf(spec) + 1];
  const start = packageSection.indexOf(`  '${spec.slug}',`);
  const end = next ? packageSection.indexOf(`  '${next.slug}',`, start + 1) : packageSection.length;
  const row = packageSection.slice(start, end);
  if (start < 0) {
    failures.push(`${spec.slug}: package row missing`);
    continue;
  }
  const arrays = [...row.matchAll(/\$json\$(\[[\s\S]*?\])\$json\$::jsonb/g)].map(match => JSON.parse(match[1]));
  const [stops, inclusions, exclusions, bands] = arrays;
  const days = [...itinerarySection.matchAll(new RegExp(`\\('${slug}',(\\d+),`, 'g'))].map(match => Number(match[1]));
  const checks = {
    dayLabels: JSON.stringify(days) === JSON.stringify(spec.days),
    stops: stops?.length === spec.stops,
    inclusions: inclusions?.length === spec.inclusions,
    exclusions: exclusions?.length === spec.exclusions,
    bands: bands?.length === spec.bands,
    price: spec.price === null ? row.includes("\n  null,$json$[]") : row.includes(String(spec.price)),
    advance: row.includes(`'percentage',${spec.advance}`),
    requiredContent: spec.required.every(value => sql.includes(value)),
  };
  for (const [check, passed] of Object.entries(checks)) if (!passed) failures.push(`${spec.slug}: ${check} check failed`);
  report.push({ package:spec.slug, days:days.length, stops:stops?.length, inclusions:inclusions?.length, exclusions:exclusions?.length, priceBands:bands?.length, passed:Object.values(checks).every(Boolean) });
}

const itineraryRows = [...itinerarySection.matchAll(/^\('([^']+)',(\d+),/gm)];
if (itineraryRows.length !== 27) failures.push(`expected 27 itinerary rows, found ${itineraryRows.length}`);
for (const required of ['begin;','commit;','booking_enabled=false','published=false','published_at=null','Age exactly 3','Keep unpublished and booking-disabled','raise exception']) {
  if (!sql.includes(required)) failures.push(`safety/content marker missing: ${required}`);
}
if (!sql.includes("where slug='rajasthan-heritage'")) failures.push('legacy Rajasthan duplicate is not safely unpublished');
if (!sql.includes('content rights and attribution must be confirmed')) failures.push('Kashmir source-attribution issue is not flagged');
if (/delete\s+from/i.test(sql)) failures.push('migration contains a destructive DELETE');

console.table(report);
if (failures.length) {
  console.error(failures.join('\n'));
  process.exitCode = 1;
} else {
  console.log('CR8-CR12 completeness, ambiguity and publication-safety checks passed.');
}
