# My Tripon Travel

A responsive React, TypeScript and Vite travel website demo for My Tripon Travel. The experience uses the supplied logo and brand colours, editorial destination photography, working route navigation, a responsive menu, gallery lightbox, tour itinerary pages and enquiry forms.

## Run locally

1. Install Node.js 20 or later.
2. Run `npm install`.
3. Copy `.env.example` to `.env.local` and add a Supabase project URL and browser-safe anon key if available.
4. Run `npm run dev`.
5. Run `npm run build` to create the production build in `dist/`.

Without Supabase credentials the site uses local demo content, and the enquiry form displays a clear demo success state. With credentials configured, enquiries are inserted into the `enquiries` table. Never put a Supabase service-role key in browser environment variables.

## Supabase setup

Apply [`supabase/schema.sql`](supabase/schema.sql) in the Supabase SQL editor. The schema includes content tables, published-content read policies, and an insert-only public enquiry policy. Before launch, add CAPTCHA and rate limiting through a Supabase Edge Function or equivalent trusted endpoint, then point `submitEnquiry` at it. Admin writes should use an authenticated admin flow or server-side service role.

## Deployment and content

The included `vercel.json` rewrites app routes to the Vite entry point. Update canonical URLs, page metadata, sitemap entries and social metadata for the production domain before launch. Demo destination copy and remote Unsplash photography are in `src/data.ts`; replace them with approved company copy and optimized/licensed media. Supplied logo artwork is in the project root and copied to `public/` for the site.

All displayed testimonial and awards content is labelled as illustrative or placeholder content. No business metrics, awards, ratings or credentials have been fabricated.
