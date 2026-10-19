import { readFile } from 'node:fs/promises';

const migrationPath = 'supabase/migrations/202610190001_production_reconciliation_cr1_12.sql';
const verificationPath = 'supabase/VERIFY_PRODUCTION_RECONCILIATION_CR1_12.sql';
const [migration,verification] = await Promise.all([
  readFile(migrationPath,'utf8'),readFile(verificationPath,'utf8'),
]);
const failures = [];

if ((migration.match(/^begin;\s*$/gmi) || []).length !== 1) failures.push('reconciliation must contain exactly one BEGIN');
if ((migration.match(/^commit;\s*$/gmi) || []).length !== 1) failures.push('reconciliation must contain exactly one COMMIT');
for (const marker of [
  'expected 49 packages before first reconciliation',
  "add column if not exists age_pricing",
  "add column if not exists booking_enabled",
  'published=true and booking_enabled=true',
  'revoke all on function public.create_booking_secure(text,date,jsonb,text,uuid) from anon',
  "'_migration_reconciliation_cr1_12_20261019'",
  'Managed content has later Admin edits',
  'site_media_admin_delete',
  "v_booking_function_hash<>'7362c9a33778656c6d2a572cf3760e82'",
  "v_booking_function_hash<>'b5a8d95dab62ae238149a45cbf7545d1'",
  'Audited RLS/storage policy definition drift detected',
  '8B011F2FAC97CBE48A2078516694F446CD6321F8274D3D7E38C25A19AB1DAEE0',
]) if (!migration.includes(marker)) failures.push(`reconciliation marker missing: ${marker}`);
for (const destructive of [/\bdelete\s+from\b/i,/\btruncate\b/i,/\bdrop\s+table\b/i,/\bdrop\s+policy\b/i]) {
  if (destructive.test(migration)) failures.push(`unexpected destructive statement: ${destructive}`);
}
for (const forbidden of [/create\s+(?:temporary|temp)\s+table/i,/on\s+commit\s+(?:drop|preserve\s+rows|delete\s+rows)/i,/pg_temp\.client_/i]) {
  if (forbidden.test(migration)) failures.push(`session-scoped staging dependency remains: ${forbidden}`);
}
for (const block of ['client_tour_itinerary','client_cr8_12_packages','client_cr8_12_itinerary']) {
  const delimiters = migration.match(new RegExp(`\\$${block}\\$`,'g')) || [];
  if (delimiters.length !== 2) failures.push(`${block}: expected one statement-local source block`);
}
for (const slug of [
  'delhi-agra-jaipur-golden-triangle-tour','delhi-agra-mathura-jaipur-tour',
  'delhi-agra-tour','delhi-agra-amritsar-tour',
  'kashmir-kargil-dhooth-pathri-tour','delhi-kullu-manali-tour',
]) {
  if (!migration.includes(`'${slug}'`)) failures.push(`expected new package slug missing: ${slug}`);
}
const sourceBlock = name => {
  const delimiter = `$${name}$`;
  const start = migration.indexOf(delimiter);
  const end = migration.indexOf(delimiter,start + delimiter.length);
  return start >= 0 && end > start ? migration.slice(start + delimiter.length,end) : '';
};
for (const [block,specs] of [
  ['client_tour_itinerary',[
    ['kashmir-kargil',[1,2,3,4,5]],
    ['delhi-agra-jaipur-golden-triangle-tour',[1,2,3,4,5]],
    ['delhi-agra-mathura-jaipur-tour',[1,2,3,4,5,6]],
    ['delhi-agra-tour',[1,2,3]],
    ['delhi-agra-jaipur-amritsar-wagah-border',[1,2,3,4,5,6,7,8]],
  ]],
  ['client_cr8_12_itinerary',[
    ['delhi-agra-amritsar-tour',[1,2,3,4,5]],
    ['rajasthan',[1,2,3,4,5,6,7]],
    ['kashmir-kargil-dhooth-pathri-tour',[1,2,3,5,6,7]],
    ['delhi-kullu-manali-tour',[1,2,3,4]],
    ['kullu-manali-kasol',[1,2,3,4,5]],
  ]],
]) {
  const body = sourceBlock(block);
  for (const [slug,expectedDays] of specs) {
    const escaped = slug.replace(/[.*+?^${}()|[\]\\]/g,'\\$&');
    const actualDays = [...body.matchAll(new RegExp(`\\('${escaped}',(\\d+),`,'g'))].map(match => Number(match[1]));
    if (JSON.stringify(actualDays) !== JSON.stringify(expectedDays)) {
      failures.push(`${block}: ${slug} day labels differ: ${actualDays.join(',')}`);
    }
  }
}
for (const marker of ['all_checks_passed','all_49_original_package_ids_preserved','six_new_package_slugs_present','booking_function_requires_both_flags','booking_function_preserves_audited_semantics','rls_preserved','storage_policies_preserved','rls_and_storage_policy_definitions_preserved']) {
  if (!verification.includes(marker)) failures.push(`verification marker missing: ${marker}`);
}
for (const semantic of [
  'balance_amount,price_snapshot,idempotency_key',
  'v_subtotal,v_tax,v_total,v_advance,v_total',
  "when p_payment_mode='full' then v_total",
  'on conflict(customer_id,idempotency_key) do update',
  'where package_id=v_package.id and travel_date=p_travel_date for update',
  'set reserved=reserved+v_people',
  "where slug=p_package_slug and published=true and booking_enabled=true for share",
]) if (!migration.includes(semantic)) failures.push(`booking semantic missing: ${semantic}`);
for (const write of [/^\s*insert\b/gmi,/^\s*update\b/gmi,/^\s*delete\b/gmi,/^\s*alter\b/gmi,/^\s*create\b/gmi,/^\s*drop\b/gmi]) {
  if (write.test(verification)) failures.push(`verification is not read-only: ${write}`);
}

const delimiters = [...migration.matchAll(/\$[A-Za-z_]*\$/g)].map(match => match[0]);
const open = [];
for (const delimiter of delimiters) {
  if (open.at(-1) === delimiter) open.pop(); else open.push(delimiter);
}
if (open.length) failures.push(`unbalanced dollar quotes: ${open.join(', ')}`);

if (failures.length) {
  console.error(failures.join('\n'));
  process.exitCode=1;
} else {
  console.log('Production reconciliation composition, guards, booking enforcement and read-only verification checks passed.');
}
