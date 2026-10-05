# My Tripon Travel

A production-oriented React, TypeScript, Vite and Supabase travel platform for My Tripon Travel. It includes the premium public website, secure booking flow, customer portal, role-protected operations console, CRM/CMS data model, document access, payment provider boundary and server-side communication architecture.

## Run locally

1. Install Node.js 20 or later.
2. Run `npm install`.
3. Copy `.env.example` to `.env.local` and add a Supabase project URL and browser-safe anon key if available.
4. Run `npm run dev`.
5. Run `npm run build` to create the production build in `dist/`.

Without Supabase credentials the public site uses safe fallback content. Account, enquiry, booking, payment and admin operations display an explicit unconfigured state and never claim a transaction succeeded. Never put a Supabase service-role key or provider secret in browser environment variables.

## Supabase setup

Apply [`supabase/schema.sql`](supabase/schema.sql), then the files in [`supabase/migrations`](supabase/migrations) in order. Deploy the Edge Functions in [`supabase/functions`](supabase/functions) and configure the server-only secrets documented in [`.env.example`](.env.example). Public leads are rate-limited through `submit-lead`; bookings and pricing are calculated atomically by `create_booking_secure`; payments are verified by signed, idempotent webhooks.

## Deployment and content

The included `vercel.json` rewrites app routes to the Vite entry point. Update canonical URLs, page metadata, sitemap entries and social metadata for the production domain before launch. Demo destination copy and remote Unsplash photography are in `src/data.ts`; replace them with approved company copy and optimized/licensed media. Supplied logo artwork is in the project root and copied to `public/` for the site.

All displayed testimonial and awards content is labelled as illustrative or placeholder content. No business metrics, awards, ratings or credentials have been fabricated.
