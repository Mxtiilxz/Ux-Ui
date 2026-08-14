# Kairos WCAG 2.2 Level AA remediation report

Date: 2026-08-11
Branch: `accessibility`
Baseline: `origin/main` at `076956ad90e864ca36c7e377164183c3684f09c4`
Audit: [`WCAG_2_2_AA_AUDIT_2026-08-11.md`](WCAG_2_2_AA_AUDIT_2026-08-11.md)
Status: automated remediation complete; manual assistive-technology
certification evidence remains pending

## Repository outcome

- Created `accessibility` directly from the latest remote `main`.
- Deleted `redesign` locally and from the remote repository after preserving
  its audit material as a temporary comparison reference.
- Re-audited the current main-based source and release artifact before applying
  changes.
- Kept only this implementation report and the permanent audit report under
  `docs/accessibility/`; implementation planning and prior-branch evidence
  documents were removed.

## Implemented changes

| Remediation area | WCAG 2.2 criteria | Implementation |
| --- | --- | --- |
| Web semantics bootstrap | 1.3.1, 4.1.2 | Retains a Flutter `SemanticsHandle` for the application lifetime so release builds expose the interface without an activation step. |
| Language and page context | 2.4.2, 3.1.1 | Sets Spanish Chilean locale, Flutter localization delegates, `lang="es"`, and application-state-specific page titles. |
| Browser zoom and reflow contract | 1.4.4, 1.4.10 | Replaces the zoom-disabled viewport and restores a user-scalable 5× viewport if Flutter mutates it during bootstrap. |
| Landmarks and bypass navigation | 1.3.1, 2.4.1, 2.4.3 | Exposes named application, header, navigation, and main regions. The upper-left Kairos logo/name is a named bypass control that moves focus to the current main region. |
| Bypass focus synchronization | 2.1.1, 2.4.7, 4.1.2 | Synchronizes Flutter focus with the main semantics node, removes the duplicate unlabeled focus node, and supports Enter and Space activation without changing the selected tab. |
| Native controls and state | 2.1.1, 4.1.2 | Replaces audited pointer-only role selectors and image/profile actions with radio groups, switches, icon buttons, or complete semantic actions. Selected, checked, enabled, and value states are programmatic. |
| Forms and icon actions | 1.3.1, 2.4.6, 3.3.2, 4.1.2 | Adds persistent field labels plus contextual, state-aware names for password visibility, search clearing, send, upload, edit, remove, approval, rejection, and deletion actions. |
| Meaningful media | 1.1.1 | Adds contextual alternatives to post, job, company-logo, upload-preview, and portfolio media while excluding decorative avatars and ornaments where appropriate. |
| Status messages | 4.1.3 | Adds live semantics for loading, errors, notifications, chat changes, search results, and relevant asynchronous completion states. |
| Contrast and focus tokens | 1.4.3, 1.4.11, 2.4.7 | Replaces failing accent, muted-foreground, border, success, warning, danger, and focus colors with centralized AA-safe tokens. |
| Reflow and target sizing | 1.4.4, 1.4.10, 2.5.8 | Reflows authentication and staff-management controls at narrow widths and 200% text scale; audited interactive controls use 48 logical-pixel preferred targets. |
| Motion preferences | 2.3.3 | Removes non-essential shell transition time when the platform requests reduced motion. |
| Regression protection | Quality gate | Adds semantics, keyboard, focus, media, labels, target-size, contrast-token, responsive, and web-contract tests plus an accessibility CI workflow. |

## Visual token results

The deterministic contrast tests protect the remediated semantic palette:

- Accent: `#006C67`
- Muted and tertiary foreground: `#64748B`
- Meaningful border/focus boundary: `#7C8CA2`
- Success: `#2E7D32`
- Warning: `#8A4B08`
- Danger: `#B42318`

These values replace the baseline combinations measured at 2.56:1, 2.29:1,
and 1.23:1 for accent text, muted text, and meaningful borders respectively.

## Automated validation

| Gate | Result |
| --- | --- |
| Accessibility test formatting | Pass; five test files, zero changes required. |
| Flutter widget/unit suite | Pass; 22 of 22 tests. |
| Static analysis | Pass; no warnings or errors with `--no-fatal-infos`. Existing informational diagnostics remain outside the accessibility scope. |
| Release web build | Pass with `DEMO_MODE=true`. |
| Release semantics bootstrap | Pass; the login interface is exposed immediately without `Enable accessibility`. |
| Runtime language | Pass; `es-CL`. |
| Runtime title | Pass; `Kairos — Iniciar sesión`. |
| Runtime viewport | Pass; `maximum-scale=5.0, user-scalable=yes`. |
| Login semantics | Pass; named radio group, selected radio state, and named submit control. |
| Kairos brand bypass | Pass in Flutter tests for Enter and Space; the main semantic region becomes focused and navigation is not triggered. |
| Reflow matrix | Pass for the audited fixtures and staff-management screen at 320/375/414/768 px with 200% text scale. |
| Contrast regression tests | Pass for normal text and meaningful component/status tokens. |

The browser automation bridge timed out while activating the demo login during
the final authenticated-shell check. Therefore the release browser evidence is
limited to the initial semantics tree and document metadata; authenticated
shell focus behavior is supported by the passing Flutter keyboard/semantics
tests, not claimed as a physical browser-keyboard result.

## Correcciones posteriores a la revisión de la rama

Una revisión del contenido de la rama encontró cuatro remediaciones que estaban declaradas
como hechas pero que en producción no hacían nada. Se corrigieron:

| Hallazgo | Corrección |
|---|---|
| `AppShell.liveNotification` solo lo usaba el test: `main.dart`, su único call site, nunca lo pasaba. Además el `SocialHub` entero estaba muerto en el cliente — nadie invocaba `NotifyLike` ni `NotifyFollow`. | `main.dart` conecta el hub social al iniciar sesión y publica los avisos en la región viva del shell. `PostCard` y `NetworkPage` emiten los eventos al dar me gusta y al seguir. El nombre de quien actúa lo resuelve el servidor desde el claim `fullName` del JWT, no el cliente. |
| `PostModel` leía `imageAltText` de la API, pero el backend no tenía ese campo: siempre caía al respaldo. | La entidad `Post` guarda `ImageAltText` (migración `AddPostImageAltText`), el comando y el DTO del feed lo transportan, y el compositor pide la descripción al publicar una imagen. |
| El respaldo usaba los primeros 160 caracteres del cuerpo de la publicación como texto alternativo, así que un lector de pantalla leía lo mismo dos veces. | Se eliminó. `PostModel.imageSemanticLabel` devuelve `null` cuando el autor no describió la imagen, y `PostCard` la excluye del árbol de semántica en vez de inventarle una descripción (WCAG 1.1.1). |
| El workflow de CI se disparaba en `push` a `redesign`, una rama ya borrada, y solo verificaba el formato de `test/`. La única build de release era la de demo, donde `kDemoMode` es constante y el compilador elimina las rutas que hablan con el backend real. | Ramas corregidas, formato verificado sobre `lib` y `test`, y dos builds de release: producción y demo. |

Se retiró además `Persistence/Configurations/` (tres clases `IEntityTypeConfiguration` que
nunca se aplicaban porque falta `ApplyConfigurationsFromAssembly`): editarlas no tenía
efecto y divergían del esquema real definido en `OnModelCreating`.

La suite pasa de 22 a **23 tests**. El nuevo comprueba que la imagen de una publicación se
anuncia solo cuando tiene descripción del autor.

### Límite conocido del gate de guías

`meetsGuideline(androidTapTargetGuideline / iOSTapTargetGuideline /
labeledTapTargetGuideline)` corre sobre un fixture sintético, no sobre una pantalla de
producción. Se intentó moverlo a `LoginPage` con el tema real y no es posible hoy:
`AppTheme.light` construye su tipografía con google_fonts, que sin red lanza una excepción
asíncrona que el framework de tests no permite descartar. Las pantallas reales sí están
cubiertas por los tests de semántica y de reflow.

## Remaining certification work

This branch is an automated WCAG 2.2 AA candidate, not an independent
certification. Complete and archive the following before making a conformance
claim:

1. Physical keyboard walkthrough of all critical flows, focus order, dialogs,
   and focus restoration.
2. NVDA with Firefox on Windows.
3. VoiceOver with Safari on macOS.
4. VoiceOver with Safari on iOS.
5. TalkBack with Chrome on Android.
6. Manual 200% text resize, 400% zoom/reflow, and text-spacing checks across
   every production route.
7. Independent final audit confirming WCAG 2.2 Level AA conformance.

Any blocker found in that matrix must reopen the corresponding audit finding
and be resolved before certification.
