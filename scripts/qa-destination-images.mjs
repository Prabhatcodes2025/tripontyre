import { createHash } from 'node:crypto';
import { readdir, readFile } from 'node:fs/promises';
import path from 'node:path';

const [registry, data, content, app, migration, verification] = await Promise.all([
  readFile('src/destinationImages.ts', 'utf8'),
  readFile('src/data.ts', 'utf8'),
  readFile('src/services/content.tsx', 'utf8'),
  readFile('src/App.tsx', 'utf8'),
  readFile('supabase/migrations/202610200001_destination_image_integrity.sql', 'utf8'),
  readFile('supabase/VERIFY_DESTINATION_IMAGE_INTEGRITY.sql', 'utf8'),
]);

const affected = [
  'ayodhya-kashi-prayagraj-gaya-bodh-gaya','azerbaijan','bangalore-mysore-kodagu',
  'bhutan','bijapur-hampi-badami-aihole-pattadakkal-chitradurga','chikmagalur',
  'delhi-agra-jaipur-amritsar-wagah-border','gujarat','hampi','hyderabad','jog-falls',
  'kerala-full','kolkata','malaysia-singapore','matheran','meghalaya','mumbai',
  'munnar-thekkady-kochi-alappuzha-kumarakom-varkala-kovalam',
  'munnar-thekkady-vagamon-kochi-athirappalli','nepal','odisha','ooty-mysore',
  'rameswaram-dhanushkodi-madurai-kodaikanal','sikkim-darjeeling','sri-lanka',
  'vagamon','valparai-athirappalli','wayanad',
  'kashmir-kargil','kasol','kullu-manali-kasol','ladakh',
  'bali-nusa-penida','indonesia','gokarna','lakshadweep',
];
const defensiveCr7 = ['agumbe','ajanta-ellora','andaman'];
const allMapped = [...defensiveCr7, ...affected];
const failures = [];

for (const slug of allMapped) {
  if (!registry.includes(`'${slug}':`)) failures.push(`${slug}: frontend credit mapping is missing`);
  if (!migration.includes(`('${slug}',`)) failures.push(`${slug}: guarded SQL replacement is missing`);
  if (!verification.includes(`'${slug}'`)) failures.push(`${slug}: verification coverage is missing`);
}

const registryImages = [...registry.matchAll(/(?:commons|unsplash)\('([^']+)'/g)].map(match => match[1]);
if (registryImages.length !== allMapped.length) failures.push(`expected ${allMapped.length} registry images, found ${registryImages.length}`);
if (new Set(registryImages).size !== registryImages.length) failures.push('frontend registry contains a duplicate replacement image');
const migrationRows = [...migration.matchAll(/^\s*\('([^']+)','([^']+)','([^']+)'\),?$/gm)];
if (migrationRows.length !== allMapped.length) failures.push(`expected ${allMapped.length} migration rows, found ${migrationRows.length}`);
if (new Set(migrationRows.map(row => row[2])).size !== migrationRows.length) failures.push('migration contains a duplicate replacement URL');

if (/create\s+(?:temporary|temp)\s+table/i.test(migration)) failures.push('migration must not depend on temporary tables');
if (!migration.includes('d.hero_image=r.legacy_image')) failures.push('destination Admin-upload preservation predicate is missing');
if (!migration.includes('p.hero_image=r.legacy_image')) failures.push('package Admin-upload preservation predicate is missing');
if (!migration.startsWith('-- Destination image integrity') || !migration.includes('\nbegin;') || !migration.trimEnd().endsWith('commit;')) failures.push('transaction boundary is missing');
if (!data.includes('destinationImageFor(slugify(name))')) failures.push('destination fallback mapping is not wired into data.ts');
if (!app.includes('destinationImageCreditForUrl')) failures.push('visible license attribution is not wired into page heroes');
if (!content.includes('normalizedImageKey') || !content.includes('uniqueImages')) failures.push('normalized runtime image de-duplication is missing');

const travelDir = path.resolve('public/travel');
const files = (await readdir(travelDir)).sort();
const hashes = new Map();
for (const file of files) {
  const digest = createHash('sha256').update(await readFile(path.join(travelDir, file))).digest('hex');
  const group = hashes.get(digest) || [];
  group.push(file);
  hashes.set(digest, group);
}
const duplicateAssets = [...hashes.values()].filter(group => group.length > 1);
if (duplicateAssets.length) failures.push(`byte-identical local assets: ${JSON.stringify(duplicateAssets)}`);

if (failures.length) {
  console.error(failures.join('\n'));
  process.exitCode = 1;
} else {
  console.log(`Destination image integrity checks passed (${affected.length} affected mappings, ${allMapped.length} guarded mappings, ${files.length} unique local travel assets).`);
}
