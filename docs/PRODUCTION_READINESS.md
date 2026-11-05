# Production readiness: promotions and source health

Status: 2026-11-04. This is a pre-beta audit, not an assertion that checkout
prices, inventory or every bank refund are guaranteed.

## Product promotions

ConViene discounts a product only when its EAN, presentation, quantity rule,
validity and shopping context have official evidence. Payment benefits are
separate from product offers. A campaign title, a crossed-out unit price or a
static fallback is not enough to lower the compared total.

| Store | Evidence checked | Current decision |
| --- | --- | --- |
| Coto | Structured product-level EAN and store rules; existing contract tests | Keep verified branch-specific rules; do not generalize them to other branches. |
| Carrefour | Product hints plus official cart simulation; existing contract tests | Calculate only when the official cart confirms the same SKU and totals. |
| Jumbo | Official legal page and public VTEX catalog/cart sample on 2026-11-04 | Legal text says *up to* 2x1 for selected products, without EAN list. Ten beer and ten milk catalog items had no product-level teaser. Sample EAN `7790742358608` returned a unit price, but cart simulation returned `ORD027` and no payable item for quantities 1-4. No new offer is calculable. |
| La Reina | Public store and benefits pages | No complete current product-level EAN/quantity rule verified. Keep benefits conditioned. |
| La Gallega | Official benefits page and catalog | Benefits page lists payment methods, not a confirmed quantity rule per EAN. Keep quantity offers out of the total. |

These are dated observations, not proof that a store has no promotions. A daily
Telegram digest includes only new or changed offers observed by the source
monitor that pass its official EAN, validity, scope and calculation checks. Its
small sample is not an exhaustive catalog. No unverified offer is published
as a saving just to populate the digest. Today no adapter exposed a current
product promotion with all required EAN and validity fields, so the daily
digest has nothing eligible to send. Product-level `QuantityOffer` records
without an explicit end date are not advertised as newly verified campaigns.

## Source monitor and Telegram

`.github/workflows/source-watch.yml` checks five public product sources and
five benefit sources every hour at minute 17. The script uses direct low-volume
catalog queries, never a browser fallback or customer checkout. It records
only source status and verified public offer metadata. Two consecutive failed
runs generate one incident; a successful run generates one recovery. A daily
digest after 20:00 Buenos Aires time reports newly observed verified offers,
if any. Telegram delivery failure does not mark a notification as sent.

Activation requires:

1. Create a bot with [BotFather](https://t.me/BotFather). To receive alerts
   privately, open the new bot and press **Start**. No phone number is needed.
   Obtain the positive numeric private chat ID with the local command below.
   Alternatively, add the bot to a group and use its negative numeric chat ID.
   Keep the bot token private; do not paste it into chat or a repository file.
2. Add `TELEGRAM_BOT_TOKEN` and `TELEGRAM_CHAT_ID` in GitHub repository
   **Settings > Secrets and variables > Actions**. Never put either in chat,
   a commit or a workflow file. Protect changes to the default branch before
   storing the token, because scheduled workflows execute code from that branch.
3. After the workflow is committed to the default branch, use **Actions >
   Source watch > Run workflow** with `test_message` checked. Confirm that the
   chat receives the test message. Then run without it and inspect source
   status. Test a failure/recovery cycle in a controlled test run before
   relying on notifications.

To find the private chat ID, run this from `backend/scraper_api` after pressing
Start. The command asks for the token with hidden input, fetches recent `/start`
messages and prints only private numeric chat IDs; it does not save the token:

```powershell
& .venv/Scripts/python.exe -m tools.source_watch --discover-chat-id
```

If more than one private ID appears, use the one belonging to your own Start
message. The bot must not have a webhook configured for `getUpdates` to work.
If discovery fails, do not paste the token into a URL or a chat; retry after
pressing Start or configure the ID through a trusted local method.

The workflow restores its small state file from GitHub Actions cache. If the
cache expires, the first run seeds offer fingerprints and failure counts again;
it may miss an incident that started before that reset. GitHub's scheduled
workflows are best effort and can be delayed, skipped or disabled after
repository inactivity. With no hosted API, this monitors upstream public
sources, **not** the availability of the user's local backend or web app.

Local dry run from `backend/scraper_api`:

```powershell
& .venv/Scripts/python.exe -m tools.source_watch --dry-run --state .pytest_cache/source-watch-local.json
```

Dry-run prints prospective messages but never sends them or changes the saved
incident state.

## Load and security

`tools/load_probe.py` runs the real FastAPI search route in-process with
simulated store adapters. It does not contact retailers and thus measures
API/cache behavior, not upstream latency. Default: 10 concurrent clients for
15 minutes, then 20 for 2 minutes; failure gate is any bad response or cached
p95 of at least 1 second. To run a short smoke test:

```powershell
& backend/scraper_api/.venv/Scripts/python.exe -m tools.load_probe --seconds 5 --burst-seconds 2
```

Full local run on 2026-11-04: 8,870 requests / 10 users / 15 minutes, zero
errors, p95 10.2 ms; then 2,377 requests / 20 users / 2 minutes, zero errors,
p95 7.5 ms. Each simulated store adapter was called nine times across both
phases as the short cache expired. Traced Python memory ended at 5.94 MB with
a 16.69 MB peak. These numbers do **not** cover live store latency, hosting,
database writes or a distributed production load.

Regression checks on the same date: backend 156 passed and 10 opt-in skipped;
six separate live source contracts passed. Flutter 171 passed and two optional
tests skipped; static analysis was clean. Release web and Android debug APK
built successfully. The APK was not installed on a real phone in this run.

Supabase project audit on 2026-11-04:

- RLS was enabled on `community_prices`, `firebase_profiles` and `profiles`.
  Author columns were not insertable/updateable by the `anon` role. A public
  RPC call with the publishable key returned HTTP 200 and no author-ID field.
- The table had **zero rows**, so the empty anonymous direct query does not
  prove row isolation with real data. Guest/public read and verified-user
  write/edit should be retested with isolated accounts before public signup.
- The remote migration history stops at `20261019113412`, although the public
  read RPC already includes Jumbo. The November migrations appear to have
  been applied outside recorded migration history. Reconcile the remote
  schema and migration tracking before deploying further SQL; do not blindly
  reapply scripts to production.
- Security Advisor showed zero errors and five warnings. Four concern the
  two intentional public `SECURITY DEFINER` read functions. They return only
  whitelisted public fields, use fixed SQL and an empty search path, but their
  elevated execution still deserves review. Do not dismiss the warnings.
- The fifth warning is leaked-password protection disabled for Supabase Auth;
  Supabase documents it as a paid-plan feature. Firebase is the primary auth
  path; the legacy Supabase fallback still requires a launch decision.
- The Firebase third-party integration is enabled in Supabase. Supabase Auth
  CAPTCHA is disabled. Do not enable it without configuring a provider and
  re-testing sign-up; decide whether the legacy Supabase Auth fallback should
  be offered publicly at all.
- Firebase Authentication settings could not be inspected: the available
  browser session requested reauthentication by a teammate who was not
  present. Authorized domains, email verification, enumeration protection
  and quotas remain **unverified**.

**Do not open public registration yet** solely on this audit. Complete the
Firebase settings review, create two disposable verified accounts and test
guest read, unverified write denial, author edit and cross-author denial.
Keep production keys out of the repository. No Supabase security migration or
permission expansion was applied during this audit.

## References

- [Jumbo legal conditions](https://www.jumbo.com.ar/legales),
  [La Reina online](https://www.lareinaonline.com.ar/) and
  [La Gallega benefits](https://www.lagallega.com.ar/Beneficios.asp).
- [Telegram Bot API](https://core.telegram.org/bots/api) and
  [GitHub scheduled-workflow limitations](https://docs.github.com/en/actions/reference/workflows-and-actions/events-that-trigger-workflows#schedule).
- [Supabase production checklist](https://supabase.com/docs/guides/deployment/going-into-prod),
  [security checklist](https://supabase.com/docs/guides/security/production-checklist),
  [password protection availability](https://supabase.com/docs/guides/auth/password-security) and
  [Firebase security checklist](https://firebase.google.com/support/guides/security-checklist).
