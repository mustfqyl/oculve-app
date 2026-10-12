# Account screen visual QA

Source visual truth: /Users/mustfq/.codex/generated_images/01a1288e-408b-7821-b298-390c785b4f7c/exec-52bc3ec7-9eb4-46ad-8091-894d19f9fe94.png
Implementation screenshot: /tmp/oculve-account-design/account-dark.png
Full-view comparison: /tmp/oculve-account-design/comparison-final.png

Viewport: native Flutter content 320 × 568 logical pixels, screenshot 640 × 1136 at 2x. Source 941 × 1672; outer desktop shadow cropped to panel (54,47)-(889,1601), normalized to content dimensions for composition comparison. Source window outline is OS/window presentation, not app content. Source panel aspect differs slightly from the actual fixed native viewport; spacing is adapted to the actual viewport.
State: dark theme, English, active account, 11.10.2026 expiry, 0 GB/unlimited, one registered device, two-factor off, masked code. Data is a widget-test fixture, not production account data. Light and Turkish finite-quota states also rendered/tested.

## Comparison history
- Initial implementation: P2 footer extended below the 568px viewport. Reduced subscription divider/row spacing and section gaps; kept scroll fallback for extra billing data and enlarged text. Post-fix screenshot shows Log out and Delete account fully visible.
- P2 styling/copy drift: cards were too bright and security subtitle used abbreviated 2FA wording. Reduced account-only surface opacity and used the full two-factor label; normalized fixture date/time to the source local date. The final comparison verifies these fixes.

## Fidelity checks
- Typography: existing Outfit font and shared native header retained. Clear section labels, prominent status/data, muted metadata; reference hierarchy reproduced. Native header weight differs slightly from the generated concept and is retained for cross-page consistency (P3).
- Spacing: unified subscription card, compact access-code row, full-width grouped settings and quiet footer; all normal-state actions visible at 320 × 568. Scrolling preserves access with longer real billing content.
- Color/tokens: existing charcoal/navy background, blue-gray metadata, green status, red destructive text; account card opacity reduced without changing other screens. Procedural background texture remains the app's existing implementation.
- Assets: existing Material icons; no illustrations or raster assets required. No placeholder images.
- Copy: matches selected concept; real account status/expiry/usage/devices/security remain dynamic. Finite quota progress and optional billing summary are retained functional states outside the mock's unlimited scenario.

The combined 1280 × 1136 comparison is readable for both overall composition and individual labels/icons, so a separate focused crop was not required.

## Verification
36 widget tests passed, including access-code reveal/hide/copy, account refresh lifecycle, device/security dialogs, destructive-account confirmation, light/dark feedback stability and compact-page layouts. No real account deletion, logout or external billing action was executed. Native computer-use capture timed out; visual evidence is the actual Flutter widget renderer, not a live native window. Compilation/startup are verified separately.

## Findings
No remaining actionable P0/P1/P2 differences. P3: native header is slightly heavier and the app's procedural background differs from the illustrative mock. Both preserve the existing product style.

final result: passed

## User-requested account polish
The user superseded the mock's expiry label, unlimited annotation and hover presentation. Account creation date now comes from createdAt, status uses 13px text, the unlimited annotation is absent, the manage row has symmetric vertical padding, and both access-code buttons retain accessibility labels without visible tooltips or hover/pressed ink. Access-code text uses Outfit at weight 700. Keyboard focus remains visible.
Current implementation evidence: /tmp/oculve-account-polish/account-dark.png (640 × 1136, 320 × 568 viewport). Compared against the user-provided screenshot /var/folders/kp/bvlh2mm92w35p7jv2hmn8gmr0000gn/T/codex-clipboard-036d658f-62d3-44e2-906c-22dd0775f393.png and explicit numbered corrections. No clipping in normal unlimited account state. 36 widget tests passed, including distinct creation/expiry dates and transparent mouse hover/button-tooltip regression checks. Source concept differences listed above are now intentional user instructions.
final result: passed


# Tray & window visual QA — 2026-10-11

Source visual truth: design/tray/approved-reference.png.
Actual Flutter widget renders: design/tray/tray-dark-page.png and tray-light-page.png.
Open dropdown evidence: design/tray/tray-dark-menu.png and tray-light-menu.png.
Combined source/render comparison: design/tray/comparison-final.png.

Viewport: 360 × 648 logical pixels, rendered at 2x (720 × 1296). Source panel cropped from (39,32) to (927,1595), normalized to 720px width. Native outer frame/shadow excluded. Source content aspect and actual viewport differ slightly; the existing product background and Outfit typography are retained. Fixture state: English, Linux layout note, connected Netherlands. This fixture is visual evidence, not a live VPN connection. Production preview uses real connection/location state.

## Comparison history
Initial comparison found excessive header/section spacing, a wrapped Linux note, oversized switch, overly prominent restore action and heavy popup shadow (P2). Tray-only compact spacing, 52px header, smaller switch, muted restore text and reduced popup elevation fixed these differences. The final combined comparison was inspected after these changes. Dropdown crops were inspected separately in dark and light themes.

## Fidelity and behavior
Grouped click/window/appearance settings and menu preview follow the approved reference. Existing Outfit font, charcoal/navy palette and Material icons maintain consistency with the app. Dropdown surfaces explicitly follow dark/light palettes, transparent tint, rounded clipped corners, muted border, green selection mark and no rectangular hover ink. Labels and values align consistently; the preview and restore row remain visible at this viewport. Narrow 320 × 568 layouts scroll safely.

Preferences persist, safe defaults preserve existing behavior, and reset touches only tray preferences. Focus loss and closing-window choices drive the desktop controller. Indicator choice drives the actual tray icon. Native menu order matches the preview and includes real status/location. Linux keeps host-specific click restrictions.

## Verification and limits
212 tests passed; 17 existing external-Xray tests skipped. New tests cover restoration, early edits, reset isolation, native channel bindings, selectors and layout across Windows/Linux/macOS platform themes and English/Turkish/Spanish. macOS unsigned Debug build succeeded. Analyzer reports only the pre-existing unused _refreshAfterRegistration warning in auth_repository.dart. Windows/Linux native runtimes were not executed on this Mac. Native computer-use capture timed out: the visual evidence above comes from the real Flutter widget renderer. The user will provide a live screenshot for a second comparison.

No remaining actionable P0/P1/P2 visual differences in the inspected renders. P3: shared Outfit text weight and existing procedural background differ slightly from the illustrative reference; these preserve the app's established design.

final result: passed


## User-requested tray polish — 2026-10-11
The user's live screenshot and instructions supersede the approved concept's gray dropdown and menu preview. Removed the entire noninteractive preview from the settings page; actual native tray functionality is retained. Popup surfaces now use dark navy #101A29 (light theme #F2F5FA), 36px minimum rows instead of 48px, Outfit 11.5px instead of 13px, tighter padding and 12px rounded corners. Width is capped at 250px instead of 278px; wrapping accommodates translated options.
Evidence: design/tray/polish-tray-dark-menu.png and polish-tray-dark-page.png, with equivalent light captures. The actual Flutter renders were inspected for themed surfaces, compact options and preview removal. Fifteen tray tests passed, including three platform themes and three languages at a narrow viewport, selection/persistence and an assertion that the removed preview is absent. Analyzer retains only the pre-existing auth warning. These changes intentionally supersede prior visual QA for this page.
final result: passed


## User-requested dropdown glass and footer — 2026-10-11
The latest live screenshot and explicit instructions supersede the previous solid popup surface. Replaced the left-aligned popup with an app-owned dialog anchored to the row's right-hand chevron. The clipped surface combines a low-opacity charcoal/navy diagonal gradient with a 14px backdrop blur, a subtle rounded border and compact option rows. Light theme has an equivalent pale gradient. Menus dismiss outside, retain button keyboard navigation and scroll when space is limited; near-bottom anchors open upward.
Restore defaults is pinned below the settings scroll region, with 20px bottom padding. Successful persistence triggers a green check for 1400ms, then a 160ms transition restores the chevron. Failed persistence shows the existing error feedback without success indication. Timer is cancelled on disposal.
Evidence inspected: design/tray/glass-tray-dark-menu.png and glass-tray-light-menu.png (actual Flutter renders at 360 × 648 logical pixels). Alignment follows the right arrow; footer is at the bottom, no preview section returns. The former source concept and solid-surface QA are intentionally superseded by these instructions.
Full suite: 212 passed, 17 existing external-Xray skips. Final tray suite after compact tap-target and constrained positioning refinement: 15 passed, including right-edge alignment, blur/gradient presence, three platforms/languages and success-check appearance/return. No new analyzer issues; only the existing auth unused-method warning. Native screenshot evidence still depends on the user's next capture.
final result: passed


## Dropdown contrast and language-stable layout — 2026-10-11
Latest user feedback supersedes the previous subtle glass palette. Popup gradient now has visibly distinct muted plum/charcoal, blue slate and navy stops, with an 8px backdrop blur. The diagonal gradient remains visible independently of the background behind it.
Selector rows use a small caption above the selected value, rather than a narrow side-by-side layout. All selectors reserve 60px at normal text scale, including two value lines. Popup options reserve 44px with two-line text; selected checks and right edges align across languages. Focus-loss row has a consistent minimum height and Linux note reserves two lines. Sizes scale with accessibility text scaling; small windows retain scrolling and the pinned reset footer.
Actual renders compared side by side: design/tray/language-comparison.png (English, Turkish, Spanish, same 360 × 648 viewport). Section/card positions and menu dimensions match across languages. Dark and light renders are captured for all three languages. No overflow in the 320 × 568 platform/language matrix. Nineteen tray tests passed, including invariant selector height, menu anchoring, three-language rendering and reset success feedback. Analyzer reports only the pre-existing unused auth method warning.
final result: passed


## Plain gradient with option dividers — 2026-10-11
User requested a plain, lightly blurred gradient with thin horizontal separators. Removed popup outline and replaced the three-stop diagonal palette with a two-stop vertical charcoal/navy gradient. Kept 8px blur. Added inset 0.5px dividers between options only. Positioning, language-stable rows and reset feedback remain intact.
Inspected actual Turkish dark render: design/tray/simple-tray-dark-menu-tr.png; light/dark captures for English, Turkish and Spanish are retained alongside it. Nineteen tray tests passed. No actionable clipping or alignment issues observed in the rendered menu.
final result: passed


# Startup integrated into connection settings — 2026-10-12
Removed the standalone Startup route and moved the setting to the top of Connection settings. Three mutually exclusive modes: Off (no login launch), Open (launch without VPN), Connect (launch and connect after saved session restoration). Existing enabled login items without a mode migrate to Open. Changing the setting does not connect immediately; manual launches do not trigger startup connection. Resetting connection options continues to preserve login startup.
Actual Flutter captures: design/startup/startup-en-dark.png, startup-tr-dark.png, startup-es-dark.png and matching light captures. Side-by-side: design/startup/comparison.png, 320 × 568 logical content rendered at 2x. Compact segmented choices follow the existing app theme; explanation reserves two lines across modes/languages. No new font assets or illustrative mockups.
Native integration: macOS SMAppService and cached login Apple Event context; Windows current-user Run entry; Linux user XDG autostart desktop entry. Windows/Linux launch commands carry a dedicated login argument. Startup service connects once after restoration, skips missing sessions and pending OS approval, and preserves saved mode on native-registration failure. Saving preference failure rolls back the native enabled state.
Reference platform documentation: https://developer.apple.com/documentation/servicemanagement/smappservice/mainapp ; https://developer.apple.com/documentation/coreservices/1556410-launch_apple_event_constants/keyaelaunchedasloginitem ; https://learn.microsoft.com/en-us/windows/win32/setupapi/run-and-runonce-registry-keys ; https://specifications.freedesktop.org/desktop-entry/latest-single/ .
Validation covers mode persistence, legacy migration, failed OS update, external disabling, once-only login behavior, missing session/approval, escaped Linux command, startup controls in all three languages/light and dark, and macOS approval UI. Live logout/login and live VPN at OS login were not performed; Windows/Linux native registration is not executed on this Mac. Analyzer has only the pre-existing unused auth method warning. Final test/build results are recorded below.
final result: passed

Final validation: 234 tests passed; 17 existing external-Xray tests skipped. macOS unsigned Debug build succeeded.


# Unified settings controls — 2026-10-12
Latest user screenshots supersede the separate Startup card and plain black selection dialogs. Startup is now a single standard SettingRow in CONNECTION, directly above Kill switch. It opens the Off/Open/Connect chooser; registration/session-startup behavior is unchanged. Pending OS approval and failures retain their required feedback.
Connection choosers and tray menus share SettingsMenuSurface, SettingsChoiceRow and SettingsOptionDivider: identical two-stop vertical themed gradient, 8px backdrop blur, 12px rounded clipping, compact Outfit options, green selection check and inset 0.5px separators. DNS, address family, diagnostic level, LAN interface and startup use the same chooser. Connection protection and reset confirmation also use the common themed modal surface. Anchoring remains appropriate to each flow (tray at its right arrow; settings selection dialogs centered).
Connection and tray Restore defaults controls now use the exact same SettingsRestoreButton component, including muted card row and 1400ms green success check followed by the original chevron. Confirmation cancellation and persistence failure do not show success. Startup remains excluded from resetting connection preferences as before.
Actual render evidence: design/settings-unified/connection-tr-dark.png and dns-menu-tr-dark.png; English/Spanish and light variants are retained alongside them. Inspected the compact startup row above protection, card-style reset footer and complete gradient/divider DNS menu. At 320 × 568 the long settings page scrolls; modal options remain visible with no overflow.
Validation: full suite 234 passed, 17 existing external-Xray skips; six additional three-language/light-dark chooser render checks passed after capture assertions were added. macOS unsigned Debug build succeeded. Dart analyzer reports only the pre-existing unused auth method warning. Live OS-login verification limits remain unchanged.
final result: passed


## Startup cycles in place — 2026-10-12
User superseded startup selection popup with Off → On → Connect → Off on each tap. On retains the persisted Open mode and its launch-only behavior. The setting now changes in place after successful OS/preference saving, with a clipped 240ms leftward slide and fade. Fixed value width prevents row-height changes between modes; smaller horizontal gap preserves the original single-line English title at the compact viewport. Reduced-motion preference skips the transition. Busy saves reject extra taps; failures retain the last successful value and existing error feedback. No startup-selection dialog opens.
Actual three-language/light-dark renders: design/startup-cycle/connection-en-dark.png and its locale/theme variants. English title/value fit one line in the inspected 320 × 568 render. Tests assert constant row height through the mode change, all three native-registration transitions, return to Off, and absence of a dialog. Twenty-eight targeted startup/connection/localization tests passed. Native startup engine and other settings chooser behavior are unchanged.
final result: passed


# Finite choices cycle and restore confirms inline — 2026-10-12
Expanded in-place cycling to DNS providers (Cloudflare → Google → Quad9 → Custom), supported IP query strategies, diagnostic level, local LAN address, and all tray click/close/indicator preferences. Custom DNS exposes its existing inline URL editor and still requires saving a valid URL. macOS's fixed IPv4 restriction is preserved. Single/missing LAN addresses do not offer an actionable cycle. Screens that collect input or explain protection remain their existing flows.
Shared SettingsSlidingValue supplies the same clipped 240ms leftward transition; SettingsCycleRow reserves a width measured from the full option set, so switching labels does not move surrounding controls. Tray retains its compact caption/value layout and platform click restrictions. Failed persistence leaves the last successful preference visible.
Both restore buttons share the same confirmation state: first press shows an amber question mark without invoking reset, second press within three seconds invokes reset and shows the existing green success tick. Timeout reverts to the original arrow. Cancelled/failed restores never show success; timers are disposed with the widget. Removed the connection reset confirmation popup.
Visual evidence: design/selection-cycle/dns-cycled-tr-dark.png and tray-dark-cycled-tr.png; equivalent English/Spanish and light captures retained. Inspected actual Flutter renders for absence of selection popup, consistent values/chevrons and preserved grouped layout. Full suite: 236 passed, 17 existing external-Xray skips. Added restore tests prove no write on first press, three-second timeout, second-press success and failure without success indication. macOS unsigned Debug build succeeded; analyzer has only the pre-existing unused auth method warning.
final result: passed


## DNS sizing and automatic custom-address save — 2026-10-12
User screenshot showed Cloudflare wrapping and clipping. Cycle-value measurement now merges the actual inherited text style (including letter spacing) instead of measuring an incomplete font style. Short values explicitly use one line. A real-font RenderParagraph regression verifies Cloudflare stays within one line at 320 × 568.
Removed the custom DNS field's floating label and Save DNS button. The compact field uses 12px input, 11px HTTPS endpoint hint, dense 12/10px padding and the existing rounded border. Valid HTTPS DNS endpoints autosave after 400ms of typing inactivity, and submitting saves immediately. Incomplete/invalid text does not overwrite the last valid setting. Pending valid changes flush on disposal; writes serialize, and switching to a preset cancels pending custom input so an old timer cannot overwrite the preset. Existing user-DNS validation and reconnect-to-apply behavior remain intact.
Regression covers absent button/label, invalid input preservation, valid autosave, last-valid preservation, preset race cancellation and immediate navigation with pending valid input. Full suite: 237 passed, 17 existing external-Xray skips. macOS unsigned Debug build succeeded. Analyzer has only the pre-existing unused auth method warning.
final result: passed


# Statistics redesign — 2026-10-12
Selected target: design/statistics/approved-reference.png, the single generated mock approved by the user. Existing native Flutter implementation was updated in place; the statistics endpoint and live traffic providers are retained. No new raster assets are needed: chart bars, progress indicators and Material icons are live UI/data components.
Comparison artifacts: design/statistics/comparison.png (initial), comparison-v2.png, comparison-final.png. The latest actual Flutter render is statistics-en-dark.png; Turkish/Spanish and light counterparts are retained. Native viewport 320 × 568 logical pixels at 2x. Source panel cropped (40,24)-(932,1598), scaled naturally to 640px width, about 1129px height; renderer is 640 × 1136. Source frame/presentation is excluded from app-content fidelity. Fixtures match 1371.62 GB, 64 active days, zero session traffic and the three exact server ids/amounts. Chart values are illustrative source-like fixture data; production charts use API data only.

## Comparison history and fixes
Initial combined comparison found P2: surfaces too bright, rows too tall, final server/footer clipped. Reduced statistics-only surface opacity, normalized body line height/letter spacing, reduced chart/row spacing and compacted server labels. Second comparison showed the footer still tight and active-days value centered differently from the source. Reduced remaining vertical gaps and aligned active-days value/caption left in the source's column position. The final combined image was inspected after these corrections: all three cards and View all servers are visible in the reference state.

## Fidelity surfaces
Typography: existing Outfit retained, 24px usage total, semibold section headers and restrained metadata; sizes and hierarchy follow the mock. Spacing: three grouped cards, consistent insets/dividers, native shared header, compact period pills and aligned server amounts. Color: existing charcoal/navy background, subdued translucent surfaces, emerald bars and blue-gray secondary copy. Images/icons: no fabricated assets; existing Material back/refresh/transfer icons and native data visualization. Content: selected copy/figures reproduced in fixtures; production metrics remain dynamic. Finite quotas retain a quiet Remaining line; missing usage has a truthful empty state, and zero bars do not fabricate activity.

## Functional verification
30-day/12-month selection switches charts locally without an extra API request. View all servers expands the actual server list inline, then collapses it. Refresh and retry fetch the existing endpoint. A new interaction test exposed the old expression-bodied reload returning a Future through setState; changed reload to a synchronous assignment block and verified retry/refresh. Server rows sort by actual tracked usage and scale against the largest server. Dates and axis range derive from supplied points; localized short labels render in all three languages.
Full suite: 244 passed, 17 existing external-Xray skips. macOS unsigned Debug build succeeded. Analyzer reports only the pre-existing unused auth method warning. Visual evidence is the real Flutter widget renderer, not a claimed native-window capture; live account figures may differ from the comparison fixture.

## Remaining differences
P3: source illustrative glow and glyph shape vary slightly from the existing procedural background/Outfit font; native header remains consistent across pages. Chart grid is solid instead of the mock's dashed lines. Real plotted values naturally differ from illustrative reference bars. No remaining actionable P0/P1/P2 differences in inspected normal-state renders.
final result: passed

# Account design 1 implementation — 2026-10-12

## Visual truth, state and evidence
Selected design 1: design/account/approved-reference.png (956 × 1646). This is the first displayed candidate, not design 2. Intentional user changes: replace Next billing with actual remaining account duration; shrink the green status dot to 6 logical pixels. Creation date remains independent. Main state: active, 1371.96 GB, 05.04.2026 creation date, four devices, enabled 2FA and one passkey. Remaining days vary with the current date, computed from expiresAt, never nextBillingAt.
Actual Flutter-rendered evidence: design/account/account-en-dark.png, account-tr-dark.png, account-es-dark.png, plus corresponding light renders. Viewport 320 × 568 logical pixels; capture at 2x = 640 × 1136. Reference scaled proportionally to 640 × 1102; no stretching. Same app-owned content/state, except the two requested modifications and dynamic countdown. Native desktop capture was attempted through computer use but timed out (-10005); these are controlled real Flutter widget renders, not claimed native-window screenshots.
Full comparison: design/account/comparison-final.png. Focused overview comparison: design/account/comparison-overview-final.png (both reference and implementation visible together).

## Comparison history
- Initial P2: creation date did not align to the card's right inset, because Flexible used a loose fit. Changed to tight fit; inspected the corrected overview.
- Initial P2: inherited Material text spacing made the top card and access-code area denser/taller than the source. Normalized actual card child text height and letter spacing, reduced card vertical padding and divider gaps, restored common 12px page insets. Inspected subsequent render.
- Initial P2: surfaces appeared flat gray rather than the restrained charcoal/navy treatment. Applied a subtle native gradient within the three account cards, retaining the existing blurred FrostedCard and main app background. Final full and focused comparison inspected.

## Fidelity surfaces
- Fonts: real bundled Outfit, native Material icons; semibold status/title/date, stronger usage number, restrained secondary metadata. English, Turkish and Spanish plus 1.6x accessibility text tested without layout exceptions. Security summary is compact and singular passkey is localized correctly.
- Spacing/layout: two-column usage/duration under status/creation row; aligned card edges and grouped devices/security with divider. Footer remains separated at the bottom, narrow layouts scroll when text is enlarged. Native app header and existing button hit areas remain consistent with other screens.
- Colors: existing charcoal/navy background; subdued gradient card fills and slate secondary copy, small emerald status marker and red destructive action. Light theme uses existing app tokens.
- Asset fidelity: existing Material eye/copy/device/shield/logout/trash icons. No raster content assets were required by this reference. No mock screenshot used as UI.
- Copy/content: live account fields retained. expiresAt drives duration rounded up to remaining days; past expiry shows Expired, missing/invalid expiry shows an em dash. Billing balance and finite quota metadata remain conditional. Access code stays masked until explicitly revealed; copy and account actions remain functional.

## Verification and remaining differences
251 Flutter tests passed; 17 pre-existing external-Xray tests skipped. New checks verify expiry-based countdown, absent/expired expiry, no next-billing text, small status dot, six language/theme renders, footer visibility and enlarged text. Existing widget tests verify code reveal/copy, devices/security and deletion confirmation. macOS unsigned Debug build succeeded. Analyzer has only the pre-existing unused _refreshAfterRegistration warning in auth_repository.dart. Native OS screenshot capture is a stated gap; native build/relaunch verification is separate from renderer comparison.
P3 intentional/native differences: existing background glow and Outfit glyph rendering differ slightly from illustrative mock; app controls keep established hit area sizes, so footer/access-code rows are slightly taller. Source aspect ratio is slightly shorter than the established app viewport. No actionable P0/P1/P2 findings remain in the inspected renders.

## Implementation checklist
- [x] Implement selected first candidate.
- [x] Replace billing date with true remaining duration and retain created date.
- [x] Shrink emerald dot.
- [x] Inspect combined full and focused comparison after fixes.
- [x] Check both themes, three locales, narrow viewport, enlarged text and existing actions.
- [x] Run regression suite and native build.

final result: passed

# Inline deletion flow — 2026-10-12

Source: design/account/inline-source.png, supplied current client screenshot. This supersedes the earlier generated deletion-dialog concepts: user explicitly selected a popup-free transformation of the existing footer.
Evidence: design/account/delete-input.png, delete-fill.png, delete-ready.png; combined comparison design/account/inline-comparison.png and focused four-state strip design/account/inline-states.png. These are the actual Flutter page rendered with bundled Outfit/Material fonts at 320x568 logical, 2x = 640x1136 pixels. Source app-owned panel cropped (36,28)-(680,1159), proportionally scaled to 640px width; window chrome excluded. Source live usage/time differs from fixture usage/time, which is intentional. No native-window screenshot is claimed.

Typography, layout and colors: existing client fonts, all upper account cards and logout action retained. Footer remains 40 logical pixels in every state, no additional popup, warning card or stacked buttons. Red outlined input with centered phrase placeholder replaces the existing red action; subdued horizontal red fill occupies the same area. Final state displays localized Are you sure?. The phrase itself stays the exact user-requested DELETE MY ACCOUNT in all languages. Real standard widgets/icons; no raster UI substitution.

Interaction checks: empty field after first tap; lowercase/incomplete phrase does not start waiting. Exact phrase unfocuses input/hides soft keyboard, starts a ten-second fill. No submit callback before completion. Final explicit click invokes callback once; repeated clicks while in flight do not resubmit. Escape, outside click during typing, and backgrounding cancel the local flow. Timers/animation/focus disposed on removal. Existing deletion API/disconnect/local-session cleanup preserved; all destructive interaction tests use a fake callback, no actual account deleted. Request failure uses existing safe account error handling and returns the control to its initial state.

Full suite: 257 passed, 17 external-Xray skips. Targeted tests cover the new sequence and the existing account page. Analyzer only reports the pre-existing unused auth method. macOS unsigned Debug build succeeded. Earlier two dialog-only tests replaced by the new inline-flow tests because popup behavior was explicitly removed.
Comparison inspected full view and focused footer strip: no remaining actionable P0/P1/P2 finding. Expected P3 differences are source/live vs fixture values, current procedural background particle position and native viewport proportions.
final result: passed

# DPI Bypass settings — 2026-10-12

Scope: two new rows within the existing Connection settings design, not a new generated layout. Uses the existing SettingsCaption, SettingsGroup, SettingsCycleRow and SettingRow components. Source style is the existing connection page; implementation evidence is design/dpi/dpi-en.png, dpi-tr.png and dpi-es.png. Actual Flutter renderer at 320x568 logical pixels, 2x capture (640x1136), normal dark theme scrolled to the new section. Native-window capture not claimed.

Typography/spacing: bundled Outfit and existing row title/subtitle sizes; Strategy value uses shared left-slide cycling and adaptive width. Retry title and helper wrap naturally in Turkish/Spanish without overflow. Color/radii/dividers: existing SettingsGroup tokens and semantic success check, no new menu/popup surface. Asset fidelity: existing Material icons, no new raster assets. Content: Automatic / Profile 1–4, and Retry DPI Bypass describing clearing learned strategies and reconnecting if active. Navigation/behavior follows the existing settings flow; settings persist for next connection, restore defaults resets to automatic and refreshes the child.

Verification: real existing page renders and cyclic persistence checks in three languages pass. Retry while disconnected does not open a tunnel; active retry uses existing disconnect/connect, and is disabled during transitions. Native automatic selection is no longer based on generic readiness probes: engine failure triggers operate per actual destination. Whole Flutter suite 284 passed, 17 existing external-Xray skips; native engine 2 tests passed, Apple runtime helper harness 4 passed, Linux pure configuration 16 passed, real ByeDPI CLI lifecycle/local TLS reset tests 3 passed. macOS unsigned Debug build succeeded. Only pre-existing unused auth method warning remains.

No actionable P0/P1/P2 UI findings remain in inspected renders. Remaining validation gap: full native Windows/Android and signed Apple/live-ISP DPI behavior were not exercised on this Mac. Controlled certificate-checked loopback TLS retry demonstrates fallback, not a guarantee of success against every block.
final result: passed
