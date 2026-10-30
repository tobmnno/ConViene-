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
