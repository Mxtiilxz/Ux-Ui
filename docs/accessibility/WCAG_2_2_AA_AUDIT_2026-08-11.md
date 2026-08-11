# Kairos WCAG 2.2 Level AA accessibility audit

Date: 2026-08-11
Branch: `accessibility`
Audited baseline: `origin/main` at `076956ad90e864ca36c7e377164183c3684f09c4`
Target: Flutter Web and shared Flutter mobile UI
Status: baseline audit completed before remediation

## Executive summary

The main-based Kairos baseline is not ready for a WCAG 2.2 Level AA
conformance claim. The audit found four critical, five major, and two minor
implementation gaps. The release build does not expose the application
semantics tree by default, and the document disables browser zoom. Those two
issues alone block equitable access before individual screens are considered.

This audit was performed independently against the current `main` source and a
fresh release build. The previous 2026-08-11 audit was preserved temporarily
and used only as a comparison checklist; each finding below was rechecked
against this newer baseline.

## Method and evidence

- Reviewed Flutter application structure, theme tokens, authentication,
  application shell, feeds, jobs, network, chat, profile, and staff screens.
- Scanned for custom pointer controls, unlabeled inputs and icon actions,
  meaningful images, focus handling, status messages, fixed layouts, and raw
  colors.
- Calculated WCAG contrast ratios from the source color tokens.
- Ran `flutter analyze --no-fatal-infos`; it completed with informational
  diagnostics only.
- Built a clean JavaScript release with `DEMO_MODE=true`.
- Inspected the release accessibility tree and document metadata in Chromium.

Release evidence before remediation:

| Signal | Baseline result |
| --- | --- |
| Accessibility tree | Only `Enable accessibility` was exposed. |
| Document language | Runtime reported `en-US` although the interface is Spanish. |
| Page title | Static `Kairos`; no route or task context. |
| Viewport | `maximum-scale=1.0, user-scalable=no`. |
| White on accent `#00B5AD` | 2.56:1; fails normal and large text. |
| Muted foreground `#81B29A` on `#F8FAFC` | 2.29:1; fails normal and large text. |
| Border `#E2E8F0` on white | 1.23:1; fails meaningful UI-boundary contrast. |

## Ranked findings

### Critical

1. **The Flutter Web semantics tree is unavailable by default**
   WCAG 1.3.1, 4.1.2. The release initially exposes only the Flutter
   accessibility activation control. `main.dart` does not retain an
   `ensureSemantics()` handle. Screen-reader users cannot reach the actual
   application reliably.

2. **Custom controls are pointer-oriented and do not consistently expose
   native role, value, state, or keyboard behavior**
   WCAG 2.1.1, 2.4.7, 4.1.2. Examples include desktop navigation, login and
   registration role choices, staff role choices, post actions, image removal,
   and profile actions implemented with `InkWell` or `GestureDetector`.

3. **Text and meaningful component colors fail minimum contrast**
   WCAG 1.4.3, 1.4.11. The accent, muted foreground, and border tokens fail
   their intended foreground or component uses. Raw success, warning, and
   error colors also bypass a testable semantic palette.

4. **Authentication and staff-management layouts can lose content under
   resize or text magnification**
   WCAG 1.4.4, 1.4.10. Fixed rows, tightly constrained controls, and rigid
   action areas are not covered by a 320 px and 200% text-scale matrix.

### Major

5. **Persistent labels and contextual icon-action names are incomplete**
   WCAG 1.3.1, 2.4.6, 3.3.2, 4.1.2. Search, message, post, comment, and some
   authentication fields rely on placeholders. Several send, clear, upload,
   remove, edit, and visibility actions lack state-aware contextual names.

6. **Language, zoom, and task-specific document metadata are incorrect**
   WCAG 1.4.4, 1.4.10, 2.4.2, 3.1.1. The HTML lacks a Spanish language
   declaration, Flutter reports `en-US`, the title is static, and runtime
   bootstrap disables user scaling.

7. **Landmarks and a reliable bypass mechanism are missing**
   WCAG 1.3.1, 2.4.1, 2.4.3, 2.4.6. Header, primary navigation, and main
   content are not exposed as named semantic regions. There is no keyboard
   action that moves focus past repeated navigation into the current screen.

8. **Meaningful media does not have contextual alternatives**
   WCAG 1.1.1. Post, job, and portfolio images are rendered without a data
   model for alternative text. Decorative avatars and ornaments are not
   consistently excluded from the semantics tree.

9. **Loading, error, notification, and content-update states are not announced
   consistently**
   WCAG 4.1.3. Progress indicators, SignalR banners, comment updates, chat
   changes, and several asynchronous error/success states lack deliberate live
   semantics.

### Minor

10. **Some interactive targets depend on padding or shrink-wrapped Material
    behavior**
    WCAG 2.5.8 and platform guidance. Compact post actions, role tiles, and
    icon-only actions are not protected by automated target-size checks.

11. **There is no accessibility regression suite or CI gate**
    Quality risk across WCAG 1.1.1, 1.3.1, 1.4.3, 1.4.10, 2.1.1, 2.4.1,
    2.5.8, 3.1.1, and 4.1.2. The baseline has no Flutter semantics, keyboard,
    contrast-token, web-contract, or responsive accessibility tests.

## Required remediation outcomes

- Expose and retain Flutter semantics for the full application lifetime.
- Declare Spanish locale/language, enable browser zoom, and update page titles
  by application state.
- Expose named header, navigation, and main regions with a tested bypass
  control integrated into the Kairos brand.
- Replace pointer-only controls with native Material controls or complete
  semantic/keyboard equivalents.
- Add persistent field labels, contextual tooltips, image alternatives, live
  status semantics, and predictable focus management.
- Replace failing visual tokens and test contrast deterministically.
- Reflow audited screens at 320/375/414/768 px and 200% text scale.
- Add automated Flutter accessibility tests and a release-build CI gate.

## Conformance boundary

Automated remediation and browser inspection can produce a strong WCAG 2.2 AA
candidate, but they cannot certify conformance. Final evidence still requires
manual physical-keyboard testing, NVDA with Firefox, VoiceOver with Safari on
macOS and iOS, TalkBack with Chrome on Android, and an independent conformance
review. Findings involving those environments remain pending manual
verification even after source remediation passes.
