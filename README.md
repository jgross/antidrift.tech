# antidrift.tech: teaser site

A single static page to test interest in Antidrift before a public release. It needs no build step and has no dependencies. It is kept apart from the Electron app: electron-builder only packages `out/**`, and the tsconfig files don't include `website/`.

```
website/
  index.html   page and copy
  styles.css   tokens copied from src/renderer/styles/globals.css
  main.js      waitlist form (set ENDPOINT)
  logo.svg     the app icon (build/icon.svg), cropped to its tile
  og-icon.png  link-preview image (build/icon.png)
```

Preview locally with `npx serve website` or `python3 -m http.server -d website`.

## Design

- **Loud, opinionated, first person.** Sun orange from the app icon, ink black and a yolk yellow. Archivo throughout (black, slightly condensed for headlines) and IBM Plex Mono for code. Hard offset shadows, nothing pale.
- **Sections:**
  1. **Hero (orange):** "Your agents are fast. They are not focused." An email-only form and a terminal window where a session has wandered off, with Antidrift's drift card popping over it.
  2. **Five things we believe (black):** one session, one goal · agents don't get tired, you do · "done" means done · your Mac, your code (no account, no cloud, no telemetry) · quit the app, keep the work (tmux).
  3. **Why I built this (yellow):** a founder note beside an example board of 2 repos, 3 projects and 14 goals. The names are fictional.
  4. **Want in? (orange):** email plus three questions: which agents, how many at once, and whether they'd pay (free only / pay once / monthly).
- **Honest claims.** Everything stated is built. The drift card offers "Jump to session", not the unbuilt "Steer back". There is still no public download.

## Measuring interest

A signup count means nothing without the number of visits behind it.

| Signal | How |
|---|---|
| Visits, and where they came from | Cloudflare Web Analytics or Plausible: one script tag, cookie-free, so no banner is needed |
| Conversion | signups ÷ unique visitors. As a rough guide, over 10% from targeted posts is strong interest and under 3% is weak |
| Which channel works | every link you post carries `?utm_source=hn` / `x` / `reddit` / `discord`. `main.js` sends it with each signup |
| What to build next | "Which agents" (how much Codex demand there is) and "How many sessions at once" (people running 4 or more feel the pain) |
| Willingness to pay | "Would you pay for it?" Anyone answering pay-once or monthly is the number that matters |

## Signups (Supabase)

- **Project:** `antidrift` (ref `ykwjaeglfayegiziuvkg`) in jgross's Org, us-east-1. The database password is in the macOS Keychain under `supabase-antidrift-db`.
- **Schema:** `supabase/migrations/`. The `signups` table has RLS on and no policies, so the public key can't read or write it. The page calls `join_waitlist()`, a security-definer function that validates input and merges repeat signups by email. Apply changes with `supabase db push` from `website/`.
- **Reading signups:** open the Table Editor in the Supabase dashboard, or run SQL:
  ```sql
  select pay, count(*) from signups group by pay;
  select source, count(*) from signups group by source order by 2 desc;
  ```
- **Referrals (word of mouth):** every signup gets a 5-character `ref_code` and sees their invite link (`antidrift.tech/?r=<code>`) after signing up. A visitor who arrives through a link is stored with `referred_by`. Only the first signup counts, and unknown codes are ignored. The site is `noindex`, so it spreads by people, not search. For hand-seeded links, use `?ref=<name>`, which lands in `source`.
  ```sql
  -- Who brings people in, and whether it spreads (signups per signup).
  select r.email, count(*) as invited
  from signups s join signups r on r.ref_code = s.referred_by
  group by r.email order by invited desc;
  select round(count(referred_by)::numeric / nullif(count(*) - count(referred_by), 0), 2) as invites_per_direct_signup
  from signups;
  ```
- **Note:** projects on the free plan pause after about a week without activity, and signups fail while paused.

## Still to do before going live

1. **Hosting on GitHub Pages:** a workflow that publishes `website/`, a `CNAME` file containing `antidrift.tech`, and DNS records.
2. **Analytics:** add the Cloudflare Web Analytics snippet so there are visits to divide by.
