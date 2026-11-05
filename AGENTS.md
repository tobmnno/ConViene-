# ConViene: guide and work log

## Architecture
- Flutter UI: lib/screens and lib/widgets. AppState owns session/cart/payment state.
- Repository contracts: lib/repositories. ProductEquivalenceRepository calls /products/equivalents.
- Calculation: DiscountEngine and PriceComparisonService in lib/services.
- Python FastAPI: backend/scraper_api; scrapers/stores.py connects store catalogs.
- Firebase authentication and Supabase community prices are configured locally. Never record keys here.

## Rules
- Implement one improvement at a time. Test it and update this log before starting the next.
- Preserve existing local edits. Do not commit or push unless requested.
- Never invent prices, stock, equivalences or promotions. Errors are not confirmed absence.
- Compare confirmed identity, size, pack and variant; keep alternatives separate.
- Preserve the user's chosen store and quantity. Viewing a product must not change the cart.
- Reuse DiscountEngine with branch, quantity, existing offers and payment context.
- La Gallega has no verified quantity-offer source. Do not infer 2x1/3x2 from names or crossed-out prices.
- Carrefour quantity offers require official cart simulation; Coto uses its structured EAN/branch rules.
- Respect dark mode, reduced motion, keyboard access and stable cart scroll position.

## Commands (PowerShell from project root)
- Backend tests: & backend/scraper_api/.venv/Scripts/python.exe -m pytest backend/scraper_api/tests -q
- Flutter SDK path without spaces: C:\PROGRA~1\Sdk\FLUTTE~1.5-S\flutter\bin\flutter.bat
- Flutter tests: & 'C:\PROGRA~1\Sdk\FLUTTE~1.5-S\flutter\bin\flutter.bat' test
- Static analysis: same executable followed by analyze --no-pub.
- Start: INICIAR_APP_WEB.bat (web-server release mode) and backend/scraper_api/INICIAR_BACKEND.bat.
- Defaults: app http://127.0.0.1:53246, API http://127.0.0.1:8000.
- Local config: supabase.local.json (ignored). Never copy its contents into logs or documentation.

## Work log - 2026-10-22
1. AGENTS.md: complete. Paths and commands checked against repository and previous successful tests.
2. Quick product comparison: implemented; 30 focused Flutter tests passed (comparison/search/engine).
   Tested tap, hover, Escape, unchanged cart/filter, request coalescing, expiry, context and source failure.
   Fixed a self-await in in-flight cleanup found by tests. Browser validation remains in step 6.
3. Full product detail: implemented. 25 focused tests passed (detail/comparison/engine).
   Quantity preview, protected add action, HTTPS/direct official-domain URL validation tested.
   Reuses comparison cache, shows conditions/refund estimates; browser review remains in step 6.
4. Cart 2x1 suggestions: implemented. 29 focused Flutter tests passed (notice/presentation/engine).
   Tested fresh/expired evidence, wrong EAN/branch, pending comparison, repeated acceptance,
   session dismissal and existing cart scroll regression. No automatic quantity changes.
5. Branded loading: implemented, 2026-10-23. 17 focused Flutter tests passed.
   Normal/compact logo animation, delayed display, stable space, dark mode, reduced motion,
   hidden ticker shutdown tested; same-query/same-date refresh retains useful results.
6. Final walkthrough and regressions: complete, 2026-10-26. The paused Supabase
   project was restored; authenticated home, account menu and cart loaded again.
   Tested release web app at 390x844 and 1280x800, light and dark. A real EAN
   returned all three stores; mobile quick comparison, detail quantity, selected
   store add, cart increment and removal worked. Cart was restored to empty.
   With Carrefour excluded from search, quick comparison still showed its price;
   the original three-store filter was restored. Fixed Best Price ordering to use
   personalized final price and checked the corrected order in the live UI.
   The debug web-server served blank Dart assets in this browser; release mode
   started correctly and INICIAR_APP_WEB.bat now uses the verified mode.

2026-10-26 validation: Flutter analyze clean; 124 Flutter tests passed; backend
108 passed, 8 opt-in live tests skipped, 43 subtests passed. Release web build
passed. A prior opt-in live Carrefour cart contract passed; the full live source
suite was not rerun. Desktop mouse hover was covered by widget tests but not
reproduced with a physical mouse in the in-app browser. No live eligible 2x1
product was confirmed during the walkthrough; the cart notice is covered by
focused EAN/branch/date/quantity tests and must not be claimed as live-verified.
Bank refund caps already consumed remain unknown; totals are estimates, not
guaranteed checkout prices. La Gallega still has no verified quantity-offer source.

Existing uncommitted promotion work is preserved. No commit or push was made.
Next step: verify the 2x1 notice against a currently confirmed live eligible SKU
when available; keep all unverified offers out of the calculable total.

2026-10-26 UI follow-up:
- Hover comparison now expands in the search list below its product card instead
  of being positioned over it, with reduced-motion-aware expansion. Five focused
  Flutter comparison tests passed, including a panel-below-card assertion.
  A physical desktop mouse hover was not available in the in-app browser;
  mouse-pointer widget tests cover the interaction and Escape behavior.
- Product detail now uses a larger product image and separate Prices/Benefits
  tabs. Prices show store, price and direct official link; Benefits retain full
  conditions, source and verification date. Ten focused Flutter tests passed
  across 320/390/1280 widths and light/dark modes, including quantity preview,
  tab isolation, source visibility and protected add. Browser review used a
  real EAN present at three stores on mobile and desktop, light and dark.
- Final validation: 126 Flutter tests passed, backend 108 passed (8 opt-in live
  skipped), analyzer clean, release web build passed. No commit or push.

2026-10-26 product detail follow-up:
- Moved published price, checkout/refund breakdown, applied benefit, caveats
  and price-update date out of Prices and into Benefits. Kept the selected-store
  add-to-cart action as a compact icon in the price row.
- Accepted the specific HTTPS Coto product route returned by its official API
  (`/productos_/R-...`), while rejecting generic and off-domain URLs. A live
  EAN showed direct links for Coto, Carrefour and La Gallega in the release web UI.
- Flutter: 126 tests passed; 10 focused detail tests passed after URL validation;
  analyzer clean; release web build passed. Browser checked both tabs at mobile
  width with a real three-store EAN. No commit or push.

2026-10-26 benefits readability follow-up:
- Product Benefits now defaults to the applied promotion name and estimated
  savings only. Price breakdown, conditions, caps, validity and source remain
  available by expanding that promotion. Other eligible but unapplied benefits
  are grouped behind a collapsed count per store; no calculated totals changed.
- An untitled promotion falls back to payment entity plus benefit so its compact
  label remains meaningful. Empty state distinguishes no applied benefit from
  no verified benefit. Eleven focused detail tests passed, including collapsed
  conditions/source, expanding details and an incompatible payment method.
- Final validation on 2026-10-27: 127 Flutter tests passed; analyzer clean;
  release web build passed. Browser review used a real EAN from all three stores
  and confirmed the compact Benefits layout plus the collapsed unapplied-offer
  group. That product had no applied offer on the review date, so live applied-
  offer appearance was not confirmed; widget tests covered its collapsed and
  expanded states. The local web and development API servers were restarted for
  the review. No commit or push.

2026-10-27 performance work (in progress):
- Baseline local API: search `galletitas oreo 118g` 1.82 s; uncached no-EAN
  equivalence queries took about 3.8-4.1 s; an EAN comparison took 0.83 s.
  These timings depend on live upstream availability, not a fixed benchmark.
- Step 1 complete: direct per-store search cache shared by search and
  equivalents, with in-flight coalescing, branch/context separation, shorter
  lifetime for empty results, no caching of failures and independent response
  copies. Seven focused cache tests passed. No changes to match criteria.
- Next: inspect repeated equivalence probes and test a bounded reduction of
  upstream requests. Then run full regression tests and a live UI walkthrough.
  No commit or push requested.
- Step 2 complete: Carrefour quantity-offer validation still requires the same
  official one/two/three-unit cart evidence, but it checks the single-unit
  price first and runs the two remaining independent checks concurrently.
  It avoids the latter calls when the first fails or differs from the catalog.
  Fourteen focused cache/Carrefour tests passed, including a concurrency test.
  No offer is inferred from a teaser alone. Next: examine catalog pagination
  and measure live behavior before another change.
- La Gallega catalog pagination measured at about 0.6 s for three pages / 50
  products; left sequential to avoid unnecessary load on the upstream site.
- Step 3 complete: official and community equivalence lookups now start
  together; independent community name/EAN requests also overlap. The same
  results, deduplication and failure statuses are preserved. Six focused
  Flutter repository tests passed, including concurrent-start verification.
- Final verification: backend 112 passed / 8 optional live skipped, Flutter
  128 passed, analyzer clean, release web build passed. The opt-in live
  Carrefour cart-schema test also passed. On the new local API, a cold
  no-EAN comparison took 4.9 s and a repeat 8 ms; a separate cold probe
  took 3.4 s, and a product search took 1.37 s. Upstream network variability
  remains the dominant cold-start cost; these are observations, not a speed
  guarantee. Browser at 127.0.0.1:53246 displayed a real EAN at all three
  stores and loaded its three-price comparison panel. The prior backend
  process on port 8000 could not be replaced in this session, so the current
  web build points to the new development API on port 8001. Both local
  processes remain running for manual review. No commit or push.

2026-10-27 integral optimization and adversarial QA (in progress):
- Baseline: backend 112 passed / 8 opt-in live skipped; Flutter 128 passed.
  Live API on port 8001: search Oreo 118 g 1.91 s (14 results), exact EAN
  0.73 s (3), Tulipan super fino 6 1.42 s (3); La Paulina 400 g no-EAN
  equivalence 5.58 s cold / 2 ms warm (1 confirmed store). These are
  single observations affected by upstream latency, not performance SLAs.
- Operations reported no source failures in that sample, but individual
  Carrefour requests reached 2.3 s and category fallback added requests.
  Current direct search cache and result matching stay intact during tuning.
- Android Studio is installed, but Android SDK is not configured; no AVD or
  Android device is presently available. A separate verified test account
  was requested for live community/auth journeys. Preserve main-user data.
- Next: reproduce and fix one cache/recovery defect with a regression test,
  then address cart recalculation and stale asynchronous state. Re-run all
  tests and a browser/Android walkthrough before claiming completion.
- Step 1 complete: Carrefour cart-simulation failures were cached for the
  entire 15-minute bucket. A red test reproduced fail-then-recover; valid
  simulations remain cached but exceptions and malformed responses now retry.
  Eight focused Carrefour tests pass. No offer-calculation rule changed.
  Next: audit and reproduce stale cart comparison after a rapid clear/change.
- Step 2 complete: an in-flight cart comparison could repopulate three store
  totals after Clear Cart. A red delayed-response test reproduced it; clearCart
  now invalidates that generation and resets the loading flag. Four focused
  AppState tests pass. Next: profile quantity-update requests and reduce only
  verified redundant work; preserve branch, promotion and stock freshness.
- Step 3 complete: the production equivalence path requested the same product
  again on every quantity tap (three calls for three quantities in a red test).
  PriceComparisonService now reuses a complete, error-free quote for one minute
  by product/store/context, coalesces concurrent work, and supports forced
  refresh. Changing branch/channel, expiry or source error triggers a new call;
  the cart refresh button bypasses the cache. Community contribution edits
  invalidate cart and quick/detail quote caches, including in-flight results.
  Twenty focused service/AppState/widget tests passed. Totals are still
  recomputed for each quantity and payment context; no pricing rule changed.
  Next: static analysis/full regressions, UI adversarial walk-through, Android.
- Step 4 complete: failed/empty/warning discount responses no longer remain
  in the same five-minute cache as complete responses. They retry after two
  minutes; complete responses retain five minutes, and entries are bounded.
  Two focused tests verify recovery and healthy-cache retention. Next: full
  regressions plus adversarial browser/Android review.
- 2026-10-28 regression: backend 115 passed / 8 optional live skipped,
  Flutter 132 passed, analyzer clean and release web build passed. A live
  browser review exposed a Carrefour Visa + Banco Patagonia benefit applied
  with only Visa visible. The official API row lacked required entity groups;
  the normalizer now requires both bank and card. A red regression test
  reproduced the issue and all 31 contract tests pass after the fix.
  Next: check conditional eligibility and channel, rebuild/retest, then finish
  browser and Android review. No commit or push.
- 2026-10-28 adversarial follow-up: a Carrefour offer restricted to Banco
  Patagonia Singular/plan sueldo was still calculable despite that eligibility
  not being modeled. It now remains visible but not calculable; all 32
  contract tests pass. Mobile browser navigation to Home > Ver todos produced
  a blank grey page and a null AppScope error. A red route widget test
  reproduced the failure; Home now passes AppScope into PaymentMethodsScreen,
  and the focused test passes. Next: rebuild and verify both fixes in browser,
  inspect other routes, full regressions and Android setup.
- 2026-10-28 browser review: the rebuilt app opened payment methods from Home
  and Discounts without the prior blank page. A verified test account was
  confirmed by the user; invalid EAN and scanner manual input showed validation,
  valid Ilolay EAN resolved by name at La Gallega and Carrefour, Favorites,
  cart quantity + twice, selected La Gallega store, store options and share
  preview worked. The test cart and favorite were cleared. Dark mode at mobile
  and desktop loaded. Physical camera scanning remains unverified. A 320 px
  store comparison card squeezed its name and status; a red widget test
  reproduced the layout issue, and a compact wrapping header passed seven
  focused cart/share tests. Next: final build/browser check and Android.
- Repeat live timings on 2026-10-28: Oreo 118g search 5.61 s cold / 0.120 s
  warm (14); Ilolay EAN 2.50 s / 0.006 s (3); Tulipan 6 search 2.36 s /
  0.006 s (5); La Paulina 400g no-EAN equivalence 15.48 s / 0.006 s (one
  confirmed store). The cold run is slower than baseline due to upstream
  response times (Coto 5.65 s, Carrefour 3.93 s observed) and does not show
  a cold-start improvement. The cart quote regression showed three quantity
  updates now reuse one complete equivalence request instead of three.
  No commit or push.

2026-11-02 guest access (local implementation, remote verification pending):
- AppShell now opens with a guest AppState and separate local cart/favorites/
  payment data. Sign-in is reachable from Home and from the contribution
  action; writes require a verified session. A one-time import prompt merges
  guest cart/favorites without changing existing account lines or payment data.
- Added limited public Supabase read RPC migration; no author IDs are returned
  and existing verified-only write RLS remains unchanged. Migration has not yet
  been applied to the remote project, so guest community reads are not claimed
  live-working. Official catalog lookup remains available if they fail.
- Focused repository/AppState/search tests: 19 passed; analyzer clean. Next:
  promotion classification and hover consistency, then apply and verify the
  remote migration with anon and authenticated sessions.
- 2026-10-28 narrow-layout follow-up: browser at 320 px showed the best-per-
  product card squeezing text and total. A widget test also found an 8 px
  RenderFlex overflow. The amount now sits below the summary on narrow cards;
  eight focused cart/share tests pass. Final web rebuild and browser visual
  verification passed at 320 px. Full validation: backend 117 passed / 8
  optional live skipped, Flutter 135 passed, analyzer clean, web release build
  passed. No commit or push.
- 2026-10-29 Android follow-up: installed official command-line tools, SDK
  platform and emulator image; Flutter doctor reports an accepted Android
  toolchain with Java 21. Regenerated stale Gradle dependency locks and set
  NDK 28.2.13676358 required by the jni plugin. Debug APK compiled and
  installed on Medium_Phone_API_37.0; native registration opened without a
  crash. The user signed in with the separate test account. Android search
  returned live results; scanner requested and received camera permission,
  displayed the virtual camera, and a manually entered Ilolay EAN resolved
  its name and prices in three stores. Quick comparison and product detail
  opened; adding Coto, incrementing quantity and removing the line worked,
  leaving the test cart empty. No Flutter exception or fatal Android error
  appeared in the sampled logcat. A physical barcode decode cannot be
  established from the emulator camera and remains unverified. Web/API
  servers restarted on ports 53246/8001. No commit or push.
- 2026-10-29 final regression: backend 117 passed, 8 opt-in live skipped and
  43 subtests passed; Flutter 135 passed; `flutter analyze --no-pub` clean.
  `flutter build apk --debug` succeeded after Gradle lock regeneration; the
  release web build and 320 px visual check passed earlier. Both local
  services answered HTTP 200 after restart. Remaining limits: no physical
  barcode scan, no verified live eligible 2x1 product, no guarantee of
  checkout price or consumed bank caps, and cold upstream timings did not
  improve in the measured sample. No commit or push.

2026-10-29 image and progressive-search work:
- Image step complete: replaced the raster-on-background ConViene header/share
  art with a transparent vector mark and rendered wordmark. Switched 44 payment
  method references to existing SVG assets where genuinely vector or sharper;
  kept the few raster assets whose SVG wrappers are lower resolution. Replaced
  La Gallega's white-background copy with its official 1000x354 transparent
  PNG. Coto now prefers its official large image URL when available. Product
  photos remain authentic source photos, not fabricated SVGs. A brand/payment
  rendering test and cart/share widget tests passed; Coto image precedence test
  passed. Release web build passed and the logo was visually checked in browser.
- Next: add search skeleton cards and progressive verified results by store;
  preserve EAN/name fallback, selected filters, source-error state and stale
  request protection. No commit or push.
- Progressive-search step complete: the API client requests selected stores
  concurrently and updates search results as each source finishes. Search
  cards show responsive skeletons while stores are pending; a real result
  replaces the placeholder without waiting for the slowest store. EAN search
  retains the aggregate name fallback, and incomplete fallback data cannot
  erase a healthy store. A failed source remains a warning, not a confirmed
  absence. AppState exposes early products to cart/favorites, ignores stale
  searches and preserves useful partial results when final loading fails.
  Network image loading shows a neutral placeholder, and missing photos no
  longer imitate a product package. Skeleton pulse stops for reduced motion.
- Verification: 7 focused progressive tests passed, including partial source
  recovery, EAN fallback, stale response, skeleton replacement and narrow
  dark/reduced-motion layout. All active logos rendered in a widget test.
  Backend: 118 passed / 8 opt-in live skipped; Flutter: 143 passed before the
  final logo-inventory test, which passed separately; analyzer clean. Release
  web and Android debug APK builds passed. In the live web app at 320 px,
  `arroz largo fino` visibly showed skeleton cards before a real Coto card
  with its catalog photo. Image clarity still depends on source image quality;
  no product photo was upscaled or falsely converted to vector. The Android
  emulator was not rerun after this asset/UI change; APK compilation passed.
  No commit or push.
- Live integration uncovered a wrapper boundary: CommunityPriceRepository
  masked ApiRepository's progressive interface. It now forwards per-store
  updates while independently loading community entries. A focused wrapper
  test passed. The live source contract passed twice against the new API;
  the regular suite keeps those network tests opt-in.
- The new API on port 8002 initially ran with the production CORS policy,
  causing browser errors despite HTTP 200 from the terminal. Restarted it
  with CONVIENE_ENV=development, as INICIAR_BACKEND.bat already does for the
  normal port 8000. The web build at 127.0.0.1:53246 now targets port 8002.
  Live browser review showed two skeleton cards, then a Carrefour product
  with its real photo while another store was still pending. Server logs
  confirmed separate Coto, Carrefour and La Gallega requests and proxied
  official images. Coto's sampled large image was 500x500; La Gallega's
  sampled source was 160x300, so its quality cannot be improved honestly by
  client-side upscaling.
- Final 2026-10-29 validation: backend 118 passed / 8 opt-in live skipped;
  Flutter 146 passed / 2 opt-in live skipped; analyzer clean; release web
  and Android debug APK builds passed. The Android emulator was not rerun
  after these changes. Local backend 8002 and web 53246 remain running for
  review; normal launch scripts still use API 8000. No commit or push.
- Follow-up: the EAN aggregate fallback now fills only unresolved stores; it
  cannot replace a store's already confirmed exact EAN with a weaker name
  match. If a per-store request failed but the aggregate recovers that store,
  its failure is no longer reported as unresolved. A focused regression test
  covers both exact preservation and recovery. Final run: Flutter 147 passed,
  2 optional live skipped; 2 separate opt-in tests passed against API 8002;
  analyzer clean and release web rebuilt. Backend remains at 8002 and web at
  53246. The Work browser control became disabled in this later session, so
  no new visual interaction was possible; the earlier live browser review
  remains the visual evidence. No commit or push.

2026-10-29 original-logo and scanner-nav correction (in progress):
- Logo step complete: restored all 49 payment-method logo paths exactly to
  their tracked originals; every referenced asset exists. Replaced the
  newly drawn brand SVG with the user's existing light/dark ConViene images
  in the app, loader and share header; removed the generated SVG. Focused
  logo, loader and cart-share tests: 10 passed.
- Scanner navigation step complete: replaced the raised 68 px FAB and notch
  with a centered 40 px action inside the bottom bar, labeled "Escanear".
  Focused navigation/logo tests: 10 passed, including 320/390 px geometry
  and no overflow. Full regression: backend 118 passed / 8 optional live
  skipped; Flutter 148 passed / 2 optional live skipped; analyzer clean;
  release web and Android debug APK builds passed. All 49 original payment
  logo paths match their tracked versions; referenced files exist. Browser
  control was disabled during this session, so visual click-through could not
  be repeated; widget tests cover the layout and asset rendering. Next:
  review staged files for secrets and generated artifacts, commit and push
  the intended local work as explicitly requested.

2026-10-29 scanner follow-up:
- Restored the original center-docked floating scanner and BottomAppBar notch.
  Reduced the circle from 68 to 52 px, lowered it 5 px and placed the visible
  "Escanear" label beneath it. The 390 px and 320 px focused navigation tests
  pass, including icon/label separation and no narrow-screen overflow.
- Next: replace selected low-resolution or white-background payment images
  with transparent high-resolution PNG exports from existing original vector
  assets; verify every changed logo and run full regression before commit.
- Logo step complete: Visa (1024 px), Uala (640 px), Banco Provincia (512 px)
  and Banco Supervielle (512 px) now use transparent PNGs exported from their
  existing vector artwork; no logo was drawn or invented. The bank symbols
  were cropped from their original art or stripped of its white backdrop.
  All four files were visually inspected and decoded; corner alpha is zero.
  Focused logo and navigation suites: 11 passed. Next: full regression,
  analyzer, release build, review working diff, then commit as requested.
- Final checks: Flutter 149 passed / 2 optional live skipped; backend 118
  passed / 8 optional live skipped and 43 subtests; analyzer clean; release
  web and Android debug APK builds passed. App and API returned HTTP 200 on
  ports 53246 and 8002. Browser interaction remained disabled in Work settings,
  so the new layout was verified through 320/390 px widget geometry tests,
  not a live click-through. User requested a new commit after review.

2026-10-30 three-stage reliability plan, stage 1 complete:
- Captured public catalog responses for six queries across Coto, Carrefour
  and La Gallega. Froze 60 reviewed cross-store identity cases (30 same,
  30 distinct) with EAN, catalog names, official product URLs and capture
  date in test/fixtures/product_identity_verified_cases.json. The optional
  collector writes candidates under ignored .pytest_cache; its proposals
  are not automatically treated as verified labels.
- Baseline on those 60 cases: 0 false positives, 2 false negatives, both
  Coto/La Gallega Oreo Mini listings abbreviated as `gall.`. A red backend
  test reproduced them. Normalizing that abbreviation now yields 0 false
  positives and 0 false negatives. A conflicting same-EAN condom count is
  separately covered by an existing test and remains rejected.
- Backend full suite: 118 passed, 8 optional live skipped, 103 subtests
  passed. Flutter full suite: 149 passed, 2 optional live skipped. No cart
  or barcode behavior was intentionally changed. Official catalog evidence
  is a dated snapshot, not a guarantee of current stock or live prices.
- Next: stage 2 baseline first-result/full-result timings, request counts
  and errors on the same six product families, then targeted optimization.
  No commit or push requested for this plan.

2026-10-30 three-stage reliability plan, stage 2 complete:
- Added an opt-in live benchmark for the same six product families; its
  machine-readable samples stay under ignored .pytest_cache. With 30 rows
  per chain, one cold run made 6 upstream calls per chain, with no source
  failures: first useful result p50 0.52 s / p95 0.84 s, all chains p50
  1.30 s / p95 1.72 s. Warm cache made zero upstream calls and completed
  in about 1 ms. This is a small sample of direct catalog lookups, not an
  end-to-end latency promise; the upstream sites can be much slower.
- A red progressive-search test showed a redundant aggregate EAN request
  after Coto returned an exact EAN and Carrefour returned a verified
  name-based match. That case now uses 2 instead of 3 HTTP requests;
  unresolved sources and missing EAN identification retain the fallback.
  No search threshold, candidate rule or source concurrency was relaxed.
- Backend regression: 118 passed / 8 optional live skipped / 103 subtests.
  Flutter regression: 150 passed / 2 optional live skipped. Next: stage 3
  promotion scope and price-provenance audit, tests and UI integration.
  No commit or push requested.

2026-10-30 three-stage reliability plan, stage 3 complete:
- API promotions now distinguish `general_confirmed`, `restricted` and
  `unknown` applicability. Explicit branch/channel limits are restricted;
  unknown scope is never promoted to general merely because a catalog was
  queried with a technical branch identifier. The La Gallega third-party
  feed remains visible but unverified and non-calculable, even when recent.
- Flutter applies only fresh, official, explicitly general-confirmed
  benefits without branch/channel restrictions. Conditioned and unverified
  offers remain visible in Discounts and product Benefits without changing
  the total or triggering a cart 2x1 notice. Search, detail and cart show
  catalog provenance and consultation date without a branch selector.
- The opt-in live official-source contract suite passed (4 tests). A live
  2026-10-30 API sample returned 36 promotions: 23 restricted Coto, 7
  restricted Carrefour, 3 restricted and 3 unknown La Gallega. None had
  explicit evidence of general applicability, so none is currently
  calculated as a discount. This is conservative by design, not proof that
  the offers are unavailable at a specific participating branch or channel.
- Full regression after the final copy update: backend 122 passed / 8
  optional live skipped / 103 subtests; Flutter 153 passed / 2 optional
  live skipped. Analyzer clean; release web and Android debug APK built.
  An initially missing generated Dart hook was rebuilt without deleting
  existing work. `git diff --check` found no whitespace errors.
- Browser walkthrough at mobile and desktop sizes, light and dark: live
  Oreo Mini search rendered progressive results; detail sorted three store
  prices and showed their catalog origin/date. Benefits showed conditioned
  offers separately without an applied saving. A live La Gallega Coinag
  offer listed participating branches and was marked restricted; moving
  from Friday to Saturday updated the discount list. A test item added
  from Carrefour retained that store in the cart while all three totals
  were compared; it was removed and the test cart is empty again. One Coto
  request failed during an earlier run and was shown as a source error,
  not a confirmed absence. The user theme and browser viewport were restored.
- Limits: no currently confirmed general promotion or live eligible 2x1
  was available for end-to-end savings verification. Bank caps already
  consumed, current stock and checkout totals remain unknown. The original
  brand mark has weak contrast on the dark background; revisit its approved
  dark asset separately without inventing a replacement logo. Local API and
  web server remain available on ports 8000 and 53246. No commit or push.

2026-11-02 Copilot handoff (changes committed on 2026-10-30):
- Commit `3326f74` (`Save uncommitted changes`) is on local and remote main;
  the worktree was clean before this log update. It changed seven files:
  the web launcher, two auth screens, PriceComparisonService and three tests.
- Copilot reported that partial equivalence responses had removed confirmed
  cached prices from other stores. The service now merges healthy results
  while replacing a store price when that store explicitly returns an error,
  unavailable or not_found state. A regression test covers this behavior.
- Copilot also reported narrow auth tabs rendering `Registrarme` vertically;
  both auth screens now use single-line fitted labels, with widget tests.
  The web launcher resolves the local Supabase define file by absolute path,
  prefers the installed Flutter SDK and retains the API URL on port 8000.
  Never log or commit the local define file or its values.
- Copilot reported a browser walkthrough of auth, search, comparison, detail,
  cart, favorites, scanner input, discounts, payment methods, sharing and
  light/dark layouts; a release web build and local HTTP 200 checks. This
  agent has not independently repeated those UI/build checks. Copilot said
  the test cart was restored to empty.
- Independently rerun on 2026-11-02: backend 122 passed, 8 optional live
  skipped and 103 subtests passed; Flutter 156 passed, 2 optional live
  skipped; `flutter analyze --no-pub` found no issues. No Android build or
  physical barcode scan was performed in this verification.
- Existing limits still apply: no live eligible 2x1 was confirmed, stock and
  consumed bank caps are unknown, checkout prices are estimates, and the
  original logo has weak dark-mode contrast. This log-only update has not
  been committed or pushed.

2026-11-02 supplied logo update:
- Added the user's four original PNG attachments as separate assets for
  American Express, Banco Patagonia, Mercado Pago and La Gallega; existing
  assets remain untouched. PaymentMethodService and MockRepository reference
  the new paths. These are the supplied pixels, not redrawn SVGs or upscales.
- The new PNGs have white or blue opaque backgrounds and lower pixel counts
  than some previous transparent assets. PaymentMethodLogo and StoreLogo crop
  their blank vertical margins only at render time so the marks stay legible
  on compact cards. Do not claim an increase in source resolution.
- A focused asset test checks all four paths and decodes each PNG. Four logo
  tests passed; `flutter analyze --no-pub` was clean and the release web build
  passed. The local API health endpoint returned HTTP 200 after restart.
  Browser review confirmed the logos render on Home and Payment Methods;
  no account selection was changed. No Android build or commit/push.

2026-11-02 logo clarity follow-up:
- The supplied 148 px American Express and Mercado Pago PNGs looked soft and
  too small in Home. Restored the existing 1000 px American Express PNG and
  784 px transparent Mercado Pago PNG, which depict the same original marks.
  The existing Mercado Pago SVG was tried but Flutter ignored its CSS classes
  and rendered a black mark, so it is not used. The PNG is cropped and scaled
  only at render time; it remains within the logo slot.
- Replaced the 404 px La Gallega copy with the user's earlier 725 px full
  wordmark (`Downloads/images.png`) under the same asset path. Preserved the
  newer supplied Banco Patagonia PNG and all untouched original assets.
  No brand artwork was redrawn or artificially upscaled.
- The changed PNG kept an old filesystem timestamp, causing Flutter's
  incremental test bundle to retain the previous 404 px copy. Updated that
  timestamp and confirmed the bundle decodes the 725 px source. Four focused
  logo tests passed; release web build passed. Browser screenshots of Home
  confirmed legible Mercado Pago and La Gallega marks after the final change.
  No Android build, commit or push was made.

2026-11-02 promotion audit and calculation:
- Live local API `/discounts?date=2026-11-02` returned 23 rows: 16 Coto
  and 7 Carrefour, all `restricted` official-API records; no product EAN
  bindings. La Gallega returned no confirmed current bank discount and its
  official benefits page showed payment methods without full promo terms.
  No general bank saving or La Gallega quantity offer was asserted.
- DiscountEngine now requires a known personal cap balance before a capped
  benefit reduces compared price. Unknown caps remain visible as conditional.
  Product detail and quick comparison share the same assessment of EAN,
  source freshness, channel/branch, payment and quantity conditions.
- Focused discount/assessment/detail/comparison tests pass. Next: verify
  hover rendering and remote guest RPC; full regression/build/browser review.

2026-11-02 guest/promotions/comparison closure:
- Applied the limited public read functions to the existing Supabase project
  through SQL Editor. Anonymous HTTP RPC returned 200. The table currently
  contains zero community prices, so a real returned row could not be checked;
  mock contracts cover both search and saved-price lookup. Existing insert
  policies still require a signed-in Supabase user or verified Firebase user.
  No production contribution row was inserted for testing.
- In a release web build on port 53247, verified guest Home, login/return,
  official search, quick comparison, dark/light mode, local cart persistence
  across tabs and cart cleanup. A Carrefour product kept its published price;
  seven restricted store-wide benefits were labeled as conditioned, not
  deducted. Desktop appearance was inspected; physical hover/mobile browser
  viewport remains covered by widget tests rather than a mouse/device check.
- A red regression found that payment benefits with an EAN list ignored the
  list; now product identity is enforced regardless of promotion kind. Another
  red regression found a disposed guest bootstrap could notify after sign-in;
  disposal now invalidates in-flight work. Guest edit controls cannot appear
  for anonymous rows where both author and current-user IDs are null.
- Final regression before the last tiny auth/dialog and edit-visibility fixes:
  166 Flutter passed / 2 optional live skipped, backend 122 passed / 8 optional
  live skipped / 103 subtests; analyzer clean; release web and Android debug
  APK built. Re-run the focused final tests before shipping. Live import
  acceptance/rejection and a verified-user write are pending a test-account
  sign-in; do not claim them as live-verified. No commit or push.

2026-11-03 store expansion, Jumbo stage:
- Jumbo's public VTEX catalog returned live EAN 7790742358608 with a positive
  price, product image and direct HTTPS product page; both asset and page
  responded 200. Name and EAN searches returned products. The online catalog
  is not evidence of a user's branch or final checkout price.
- Added a direct Jumbo adapter, source-error handling, backend store alias,
  image host, Flutter store/filter/comparison/link mapping and an unmodified
  official logo export. A nonsensical ListPrice was not shown as savings.
- No Jumbo campaign was assumed calculable. Its discount endpoint currently
  returns an explicit no-verified-benefits warning, never La Gallega data.
- Four focused backend tests and 34 focused Flutter tests passed; full backend
  suite: 126 passed / 8 optional live skipped. A live EAN equivalence query
  returned Jumbo as found. Supabase store constraint/RPC rollout and final
  browser walk-through remain pending; do not claim them verified yet.
- Next: verify and integrate La Reina one store at a time, then shared
  Supabase migration, full regression and UI review. DAR/La Anonima stay out.

2026-11-03 store expansion, La Reina stage:
- Its public catalog returned price, official product URL, photo and EAN for
  7790742358608. Searching by EAN found the same item; a nonsense query
  returned an explicit empty catalog. Both direct page and image responded 200.
- The existing ASP catalog parser now accepts an official base URL and validates
  GTINs in product links, without treating arbitrary internal IDs as barcodes.
  La Reina is wired into backend/Flutter store IDs, filters, comparison,
  cart, official-link validation, logo and image proxy. Live backend
  equivalence found the same EAN at Jumbo and La Reina.
- No bank or quantity discount was inferred from an offer label. An empty
  verified-discounts response is reported explicitly for both new stores.
- Focused backend tests (8) and Flutter tests (47) passed; backend full suite
  130 passed / 8 optional live skipped. Next: shared Supabase migration,
  full regressions, build and visual browser review. No commit or push.

2026-11-03 store expansion, final verification:
- Applied the five-store community-price constraint and limited guest-read RPC
  in the existing Supabase project. SQL Editor confirmed success; a read-only
  check showed all five IDs and anonymous EXECUTE permission. Anonymous REST
  returned HTTP 200 but no contributed row exists for the new stores, so a
  real community-price display remains unverified. Verified-only writes were
  not broadened. The local migration is repeatable if later run by CLI.
- Backend on port 8003 returned both new stores as found for EAN 7790742358608.
  The release web app on 53248 displayed five prices in quick comparison and
  product detail, with La Reina first by published price. Adding from its
  detail kept La Reina selected in the cart; the cart compared all five totals.
  The test item was removed. On a 390 px viewport, original Jumbo and La Reina
  logos rendered in the horizontal store selector. Deselecting the original
  three stores yielded only Jumbo and La Reina search results; all five filters
  were restored afterward. Discounts showed both new store filters without
  inventing offers. Desktop and mobile layouts were visually inspected.
- Final checks: backend 130 passed / 8 opt-in live skipped / 103 subtests;
  Flutter 169 passed / 2 opt-in live skipped; analyzer clean; release web and
  Android debug APK builds passed; git diff --check passed. The debug Android
  build emitted an SDK XML version compatibility warning but completed.
- Limits: neither new chain has a verified product-specific quantity offer or
  bank-benefit rule, so neither receives a calculated discount. Prices are
  public catalog observations, not a branch, stock or checkout guarantee.
  DAR and La Anonima were not added. No physical barcode scan, live community
  contribution for the new stores or real checkout was tested. No commit/push.

2026-11-03 release-readiness work, stage 1 complete:
- Extended the opt-in official-catalog candidate collector to Jumbo and La
  Reina. Reviewed and froze 60 additional pairs with source URLs, EANs and
  capture time: 30 same-SKU and 30 distinct size/flavor/model pairs. The
  shared fixture now has 120 dated cases across all five supermarkets.
- Red regressions exposed Oreo Original/vanilla wording for the same EAN in
  Python and an omitted Classic condom model at Coto for the same EAN in
  Flutter. Narrow fixes preserve rejection of conflicting EAN, quantity,
  size and explicit model. Backend shared identity: 134 subtests passed;
  Flutter local parity passed. Full backend: 130 passed, 8 optional live
  skipped, 163 subtests; full Flutter: 169 passed, 2 optional live skipped.
- These are dated public-catalog observations, not a fresh availability or
  live-price guarantee. Next: official promotion-source review and adapters;
  do not present old or incomplete conditions as calculable savings.

2026-11-03 release-readiness work, stage 2 complete:
- Rechecked Coto's structured promotion API, Carrefour's promotion records
  and public cart contract, and La Gallega's official benefits page through
  the opt-in live contracts. Added live structure checks for Jumbo legal text
  and La Reina's official benefit cards; all 6 live contracts passed today.
- Jumbo's official legal page describes a 02-04 Nov 2026 online campaign with
  "hasta 2x1" for selected products but no participating EANs. The reader
  exposes it only as an informational, restricted, noncalculable campaign.
  It cannot lower a product price or trigger a cart quantity suggestion.
- La Reina's official page exposed 12 expired cards and one card without
  sufficient validity/eligibility. The reader reports these conditions and
  produces no calculable promotion. La Gallega likewise remains noncalculable
  without complete official terms. Existing Coto/Carrefour adapters remain.
- Added parser, API error/recovery and UI tests; updated an older Jumbo test
  to assert the new noncalculable semantics without live-network dependence.
  Focused backend contracts: 13 passed. Full backend: 137 passed / 10 optional
  skipped / 163 subtests. Flutter: 170 passed / 2 optional skipped; analyzer
  clean. No savings were inferred from a campaign title. No commit or push.
- Next: benchmark first-useful/full-result latency and request counts on five
  chains, then change only duplicated work demonstrated by the measurements.

2026-11-03 release-readiness work, stage 3 complete:
- Extended the opt-in benchmark to all five chains and six product families.
  One cold sample: first useful p50 0.501 s / p95 0.682 s; complete p50
  1.597 s / p95 4.181 s; six upstream calls per chain, zero errors. Warm:
  zero upstream calls and about 1 ms completion. The six-query sample is not
  an end-to-end latency guarantee; upstream load can vary substantially.
- Direct catalog search already used one request per chain/query in this
  sample. No search or matching rule was relaxed merely to claim speed.
- Date switching redownloaded the same large Jumbo/La Reina legal page.
  Added a five-minute per-URL HTML cache with in-flight coalescing; two dates
  now use one fetch instead of two. Failures are not cached, expired entries
  refetch, and explicit discount-cache clearing also clears these pages.
  Eleven focused reader/cache tests pass, including failure recovery and
  concurrent dates. Full backend: 141 passed / 10 optional skipped / 163
  subtests. No commit or push.
- Next: inspect operations alerts, image proxy, CORS/admin/community access
  and environment setup; run builds and live UI/Android review.

2026-11-03 release-readiness work, stage 4 and final walkthrough:
- Reviewed admin-only `/operations`, production CORS, image-host/type validation,
  release API defines and the existing guest-read Supabase migration. Added
  `last_check_at` and `last_count` to per-source diagnostics while preserving
  `last_success_at` after failures. A malformed HTTP 200 benefits page no
  longer enters the shared cache; the next request can recover. Existing
  production admin-key and CORS tests remain green. README files now describe
  the five promotion sources, conservative calculation and release checklist.
- Live browser review at mobile and desktop sizes: EAN 7790742358608 returned
  five published prices; quick comparison, detail Prices/Benefits, selected
  La Reina add and all-store cart totals worked. The test line was removed.
  Jumbo's non-EAN campaign appeared as `Info`/conditioned; removed an erroneous
  `Compatible` payment chip from store-product campaigns. Five store filters
  were restored after inspection. Web app remains on 127.0.0.1:53249 and the
  development API on 127.0.0.1:8004 for manual review.
- Android emulator installed the fresh debug APK. EAN search and quick
  comparison loaded five stores. Rotating to a low-height landscape viewport
  reproduced a 49 px SearchScreen overflow. Added a red widget test, moved
  variable-length notices into the results scroller, and verified no overflow
  on the same emulator screen after rebuilding/reinstalling. No physical
  camera or real Android phone was available in this run.
- Final verification: backend 144 passed / 10 optional skipped / 163
  subtests; six opt-in live promotion contracts passed; Flutter 171 passed /
  two optional skipped; analyzer clean; release web and Android debug APK
  builds passed. `git diff --check` reported no whitespace errors. The web
  bundle targets the local test API and is not a deployable production URL.
- Remaining limits: no current verified EAN-level Jumbo/La Reina quantity
  promotion or fully calculable bank benefit; no live eligible 2x1 checkout,
  consumed bank caps, guaranteed stock, final ticket total, physical barcode
  scan, signed release AAB or public HTTPS deployment. Cold upstream response
  time may vary despite warm-cache savings. No commit or push.

2026-11-04 promotion and operations follow-up (local implementation complete):
- Checked Jumbo official legal text and one public VTEX EAN. The catalog had a
  unit price but official cart simulation returned ORD027/no payable item for
  quantities 1-4; 20 sampled beer/milk items had no product-level teaser.
  No new quantity discount was enabled. La Reina and La Gallega
  still lack complete EAN-level evidence. A low-volume live monitor probe saw
  all five product and five benefit sources respond, but zero product offers
  met the exact official-EAN evidence gate.
- Added an hourly GitHub Actions source-watch workflow plus a stateful Telegram
  notifier. Focused tests cover two-failure threshold, recovery, failed-send
  retry, daily digest deduplication and strict promotion evidence. The bot,
  chat and Actions secrets are not yet configured; the workflow is local only
  until a separately requested commit/push. No live Telegram delivery claimed.
- Added an in-process load probe with simulated stores (no retailer traffic).
  A smoke run passed. The full 15+2-minute run handled 8,870 requests at 10
  users (p95 10.2 ms) plus 2,377 at 20 users (p95 7.5 ms), zero errors;
  traced memory peaked at 16.69 MB. Each simulated source was called nine
  times as caches expired. This is not a live-retailer or hosted-load SLA.
- Read-only Supabase audit: RLS enabled on three public tables; public read
  functions and RLS policies exist. Security Advisor has zero errors and five
  warnings (four intentional definer-function exposures and paid-plan leaked-
  password protection). The community table is empty, so anonymous isolation
  was not proven against a real row. Remote migration history stops at
  20261019113412 despite newer public RPC behavior; reconcile before applying
  more SQL. Firebase integration is enabled in Supabase; Supabase Auth CAPTCHA
  is disabled. Firebase console required teammate login; its settings and
  cross-user permission tests remain pending. Public signup is not cleared by
  this partial audit. No remote permissions changed.
- Final local regression: backend 156 passed / 10 optional skipped / 163
  subtests; six opt-in live promotion contracts passed. Flutter 171 passed /
  two optional skipped; analyzer clean; release web and Android debug APK
  built. Monitor dry-run saw all ten sources healthy and zero complete
  product-level promotions. No live Telegram delivery, physical Android
  session, public deployment or commit/push was performed in this turn.

2026-11-04 beta preparation follow-up:
- Started the local API and release web app without duplicate listeners; both
  health checks returned HTTP 200.
- Added `.github/workflows/ci.yml` for backend tests, Flutter tests, analyzer
  and release web build on pushes, pull requests and manual runs. It uses
  placeholder public defines only and never reads local credentials.
- Local regression after the CI change: backend 156 passed / 10 skipped /
  163 subtests; Flutter 171 passed / 2 skipped; analyzer clean.
- Firebase console review, isolated-account authorization tests, remote
  migration reconciliation, Telegram setup and hosted HTTPS/API validation
  remain external beta gates. No commit or push was made.

2026-11-05 Telegram private-chat preparation:
- Source watch now accepts a positive private chat ID as well as a negative
  group ID. Added a local `--discover-chat-id` command that prompts for the
  bot token with hidden input, reads recent private `/start` updates and prints
  only numeric chat IDs; it does not persist the token or print request errors
  that could contain it. Updated the workflow label and setup documentation.
- Fourteen focused source-watch tests pass, including private delivery,
  invalid ID rejection and token-safe discovery. A real Telegram message has
  not been sent: the bot, destination ID and GitHub Actions secrets are still
  needed. Full backend regression: 158 passed, 10 optional skipped and 163
  subtests passed. `git diff --check` found no whitespace errors. No commit
  or push was made.
- Live source-watch dry run: all five product catalog checks passed; Coto,
  Carrefour, La Gallega and La Reina benefit checks passed, while Jumbo
  returned `no se pudieron leer descuentos (ValueError)`. Zero EAN-level
  offers qualified. This is a source failure to monitor, not evidence that
  Jumbo has no promotions. Telegram secrets were reported configured by the
  owner, but no delivery has yet been independently verified.
