import { readFile } from 'node:fs/promises';

const [data, app, home, brand, migration] = await Promise.all([
  readFile('src/data.ts', 'utf8'),
  readFile('src/App.tsx', 'utf8'),
  readFile('src/HomeExperience.tsx', 'utf8'),
  readFile('src/brand.css', 'utf8'),
  readFile('supabase/migrations/202610180002_cr7_catalogue_corrections.sql', 'utf8'),
]);

const failures = [];
const requireText = (source, text, message) => {
  if (!source.includes(text)) failures.push(message);
};

for (const [name, photoId] of [
  ['Agumbe', 'photo-1578378377576-2ed7065bdb87'],
  ['Ajanta–Ellora', 'photo-1620558601903-9f2441730121'],
  ['Andaman', 'photo-1767782843278-1cfc4acff2ff'],
]) {
  requireText(data, photoId, `${name} verified fallback image missing`);
  requireText(migration, photoId, `${name} CMS image correction missing`);
}

const ids = [...data.matchAll(/photo-\d+-[a-z0-9]+/gi)].map(match => match[0]);
if (new Set(ids).size !== ids.length) failures.push('CR7 destination image URLs are duplicated in fallback data');

requireText(data, "international: ['Dubai', 'Thailand', 'Indonesia', 'Bali - Nusa Penida'", 'Bali fallback category is not international');
requireText(migration, "primary_category='international'", 'Bali CMS destination category correction missing');
requireText(migration, "category='international'", 'Bali CMS package category correction missing');
requireText(migration, "title='Tulip Garden'", 'Tulip Garden CMS label correction missing');
requireText(migration, "d.slug in ('agumbe','ajanta-ellora','andaman')", 'stable destination slug targeting missing');
requireText(app, 'formatPackagePrice(p.basePrice)', 'catalogue card price is not rendered');
requireText(app, '{p.duration}', 'catalogue card duration is not rendered');
requireText(home, 'formatPackagePrice(item.basePrice)', 'home journey card price is not rendered');
requireText(home, '{item.duration.toUpperCase()}', 'home journey card duration is not rendered');
requireText(brand, '.header.scrolled .official-brand', 'scrolled-header logo sizing rule missing');

if (failures.length) {
  console.error(failures.join('\n'));
  process.exitCode = 1;
} else {
  console.log('CR7 category, destination media, package metadata and scrolled-logo checks passed.');
}
