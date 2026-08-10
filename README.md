# Sales Report Prototype

Next.js prototype with Supabase (Auth + Postgres) and SendGrid for scheduled report emails.

Setup (local):

1. Install dependencies:

```bash
npm install
```

2. Create `.env.local` with:

```
NEXT_PUBLIC_SUPABASE_URL=...
NEXT_PUBLIC_SUPABASE_ANON_KEY=...
SUPABASE_SERVICE_ROLE_KEY=...
SENDGRID_API_KEY=...
REPORT_SECRET=some-secret-token
ADMIN_EMAILS=you@example.com
```

3. Run locally:

```bash
npm run dev
```

Deploy: push to GitHub and connect to Vercel. Add environment variables in Vercel settings.
